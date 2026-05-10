import io
import logging
import os
import struct
import sys
from contextlib import asynccontextmanager

# Add the bundled TripoSR repo to sys.path so `from tsr.system import TSR` resolves
# without needing to set PYTHONPATH externally.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "TripoSR"))

import uvicorn
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse, Response

# ---------------------------------------------------------------------------
# GPU + TripoSR imports — only needed when MESH_PROVIDER=local
# ---------------------------------------------------------------------------
import torch
from PIL import Image
from tsr.system import TSR

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Model — loaded once at startup, reused for every request
# ---------------------------------------------------------------------------
model: TSR | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the TripoSR model on startup, release on shutdown."""
    global model
    device = "cuda:0" if torch.cuda.is_available() else "cpu"
    logger.info("Loading TripoSR onto %s …", device)
    model = TSR.from_pretrained(
        "stabilityai/TripoSR",
        config_name="config.yaml",
        weight_name="model.ckpt",
    )
    model.renderer.set_chunk_size(131072)
    model.to(device)
    logger.info("TripoSR loaded successfully!")
    yield
    # Cleanup (optional — frees VRAM when the server shuts down gracefully)
    del model
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
    logger.info("TripoSR unloaded.")


app = FastAPI(title="Local TripoSR Worker", lifespan=lifespan)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_minimal_glb() -> bytes:
    """
    Spec-compliant GLB 2.0 fallback for smoke-testing the data pipeline
    without a GPU.  Returns an empty-scene GLB that three.js / model_viewer_plus
    will accept without throwing a parse error.
    """
    json_str  = b'{"asset":{"version":"2.0"}}'
    pad       = (4 - len(json_str) % 4) % 4
    json_pad  = json_str + b' ' * pad
    chunk_hdr = struct.pack('<II', len(json_pad), 0x4E4F534A)   # JSON chunk
    glb_hdr   = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(json_pad))
    return glb_hdr + chunk_hdr + json_pad


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    """Readiness probe — returns model_loaded=True once TSR is on the GPU."""
    loaded = model is not None
    device = "cuda:0" if (loaded and torch.cuda.is_available()) else "cpu"
    return JSONResponse({"status": "ok", "model_loaded": loaded, "device": device})


@app.post("/generate")
async def generate_mesh(file: UploadFile = File(...)):
    """
    Accepts a garment PNG (background already removed by Dressify backend),
    runs it through TripoSR, and returns a binary GLB file.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Must be an image file")

    image_bytes = await file.read()
    logger.info("Received image: %s bytes (content_type=%s)", len(image_bytes), file.content_type)

    if model is None:
        # Model hasn't loaded yet — return a spec-compliant dummy for pipeline testing
        logger.warning("Model not loaded — returning dummy GLB for pipeline smoke-test.")
        return Response(content=_make_minimal_glb(), media_type="model/gltf-binary")

    try:
        device = next(model.parameters()).device

        # Composite onto white before TripoSR — the model is trained on RGB with solid
        # backgrounds. Feeding a transparent RGBA causes colour bleed (skin/grey artifacts).
        raw = Image.open(io.BytesIO(image_bytes)).convert("RGBA")
        white_bg = Image.new("RGBA", raw.size, (255, 255, 255, 255))
        white_bg.paste(raw, mask=raw.split()[3])
        image = white_bg.convert("RGB")

        with torch.no_grad():
            scene_codes = model([image], device=device)
            meshes = model.extract_mesh(scene_codes, has_vertex_color=True, resolution=256)
            mesh = meshes[0]

        # Keep only the largest connected component to discard floating debris.
        components = mesh.split(only_watertight=False)
        if components:
            mesh = max(components, key=lambda m: len(m.faces))

        # Smooth marching-cubes staircase artifacts.
        import trimesh.smoothing
        trimesh.smoothing.filter_laplacian(mesh, lamb=0.5, iterations=5)

        glb_io = io.BytesIO()
        mesh.export(glb_io, file_type="glb")
        glb_bytes = glb_io.getvalue()
        logger.info("Generated GLB: %s bytes", len(glb_bytes))
        return Response(content=glb_bytes, media_type="model/gltf-binary")

    except Exception as e:
        logger.exception("Mesh generation failed")
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    logger.info("Starting Local GPU Worker on http://0.0.0.0:8080")
    logger.info("Health check : GET  http://localhost:8080/health")
    logger.info("Generate     : POST http://localhost:8080/generate")
    uvicorn.run(app, host="0.0.0.0", port=8080)
