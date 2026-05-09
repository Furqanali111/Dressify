import logging
import io
import uvicorn
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import Response

# To use real TripoSR, you need to install it:
# pip install torch transformers diffusers accelerate trimesh
# pip install git+https://github.com/VAST-AI-Research/TripoSR.git
#
# import torch
# from tsr.system import TSR
# from PIL import Image

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Local TripoSR Worker")

# model = None

# @app.on_event("startup")
# def load_model():
#     global model
#     logger.info("Loading TripoSR model onto GPU...")
#     model = TSR.from_pretrained(
#         "stabilityai/TripoSR",
#         config_name="config.yaml",
#         weight_name="model.ckpt",
#     )
#     model.renderer.set_chunk_size(131072)
#     model.to("cuda:0")
#     logger.info("Model loaded successfully!")

@app.post("/generate")
async def generate_mesh(file: UploadFile = File(...)):
    """
    Receives a PNG image, runs it through TripoSR, and returns a GLB file.
    """
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Must be an image")

    image_bytes = await file.read()
    
    # --- REAL INFERENCE CODE (Uncomment when you have TSR installed) ---
    # try:
    #     image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    #     
    #     # TripoSR expects foreground image. We already stripped the background in Dressify!
    #     with torch.no_grad():
    #         scene_codes = model(image, device="cuda:0")
    #         meshes = model.extract_mesh(scene_codes)
    #         mesh = meshes[0]
    #
    #     # Export to GLB
    #     glb_io = io.BytesIO()
    #     mesh.export(glb_io, file_type="glb")
    #     glb_bytes = glb_io.getvalue()
    #     return Response(content=glb_bytes, media_type="model/gltf-binary")
    # except Exception as e:
    #     logger.exception("Failed to generate mesh")
    #     raise HTTPException(status_code=500, detail=str(e))
    # ------------------------------------------------------------------

    # --- DUMMY FALLBACK FOR TESTING THE DATA FLOW ---
    logger.info("Received request! Returning dummy GLB. Uncomment the TSR code to generate real 3D meshes.")
    # A tiny, minimal valid GLB header so the frontend doesn't crash trying to parse it
    dummy_glb = (
        b"glTF" + 
        b"\x02\x00\x00\x00" + 
        b"\x14\x00\x00\x00" + 
        b"\x00\x00\x00\x00" + 
        b"JSON" + 
        b"{}"
    )
    return Response(content=dummy_glb, media_type="model/gltf-binary")

if __name__ == "__main__":
    logger.info("Starting Local GPU Worker on port 8080...")
    uvicorn.run(app, host="0.0.0.0", port=8080)
