import logging
import uuid
import httpx
import base64
import asyncio
from tenacity import retry, stop_after_attempt, wait_exponential

from app.config import settings
from app.db import AsyncSessionLocal
from app.models.clothing_item import ClothingItem
from app.services.storage import download_file, upload_file
from sqlalchemy import select

logger = logging.getLogger(__name__)


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=30))
async def reconstruct_glb(png_bytes: bytes) -> bytes:
    """
    Provider-agnostic function to generate a 3D GLB mesh from a 2D PNG image.
    Routes the request based on the MESH_PROVIDER setting.
    """
    provider = settings.MESH_PROVIDER.lower()

    if provider == "local":
        # Hit the local GPU worker running on the user's machine
        url = settings.LOCAL_GPU_WORKER_URL
        if not url:
            raise ValueError("LOCAL_GPU_WORKER_URL is not set")
        
        async with httpx.AsyncClient(timeout=120.0) as client:
            files = {"file": ("image.png", png_bytes, "image/png")}
            response = await client.post(url, files=files)
            if response.status_code != 200:
                logger.error("Local GPU worker failed: %s", response.text)
                response.raise_for_status()
            return response.content

    elif provider == "replicate":
        # Replicate integration (camenduru/tripo-sr)
        token = settings.REPLICATE_API_KEY
        if not token:
            raise ValueError("REPLICATE_API_KEY is not set")
        
        b64_image = base64.b64encode(png_bytes).decode("utf-8")
        data_uri = f"data:image/png;base64,{b64_image}"

        async with httpx.AsyncClient(timeout=60.0) as client:
            headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
            # 1. Create prediction
            pred_resp = await client.post(
                "https://api.replicate.com/v1/models/camenduru/tripo-sr/predictions",
                headers=headers,
                json={"input": {"image": data_uri}}
            )
            pred_resp.raise_for_status()
            pred_data = pred_resp.json()
            get_url = pred_data["urls"]["get"]

            # 2. Poll for completion
            for _ in range(30): # up to 30 * 5 = 150 seconds
                await asyncio.sleep(5)
                poll_resp = await client.get(get_url, headers=headers)
                poll_resp.raise_for_status()
                poll_data = poll_resp.json()
                if poll_data["status"] == "succeeded":
                    output_url = poll_data["output"]
                    # Download the GLB
                    glb_resp = await client.get(output_url)
                    glb_resp.raise_for_status()
                    return glb_resp.content
                elif poll_data["status"] == "failed":
                    raise RuntimeError(f"Replicate prediction failed: {poll_data.get('error')}")

            raise TimeoutError("Replicate prediction timed out")

    elif provider == "runpod":
        url = settings.RUNPOD_MESH_ENDPOINT
        if not url:
            raise ValueError("RUNPOD_MESH_ENDPOINT is not set")
        # Placeholder for RunPod serverless payload
        raise NotImplementedError("RunPod provider is not yet fully implemented")
    
    else:
        raise ValueError(f"Unknown MESH_PROVIDER: {provider}")


async def trigger_mesh_reconstruction(ctx: dict, item_id_str: str, png_path: str) -> None:
    """
    ARQ background task to generate a 3D mesh.
    1. Downloads PNG from Supabase.
    2. Generates GLB via external GPU worker.
    3. Uploads GLB to clothing-meshes bucket.
    4. Updates ClothingItem in DB.
    """
    item_id = uuid.UUID(item_id_str)
    logger.info("Starting mesh reconstruction for item %s via %s", item_id, settings.MESH_PROVIDER)

    try:
        # 1. Download the processed garment PNG
        png_bytes = download_file(settings.CLOTHING_BUCKET, png_path)
        if not png_bytes:
            raise FileNotFoundError(f"Could not download {png_path} from {settings.CLOTHING_BUCKET}")

        # Update status to processing
        async with AsyncSessionLocal() as db:
            item = await db.scalar(select(ClothingItem).where(ClothingItem.id == item_id))
            if item:
                item.mesh_status = "processing"
                await db.commit()

        # 2. Call the GPU worker
        glb_bytes = await reconstruct_glb(png_bytes)

        # 3. Upload GLB to Supabase
        glb_path = png_path.replace(".png", ".glb").replace(".jpg", ".glb")
        success = upload_file("clothing-meshes", glb_path, glb_bytes, "model/gltf-binary")
        if not success:
            raise RuntimeError("Failed to upload GLB to Supabase clothing-meshes bucket")

        # 4. Update Database
        async with AsyncSessionLocal() as db:
            item = await db.scalar(select(ClothingItem).where(ClothingItem.id == item_id))
            if item:
                item.glb_mesh_path = glb_path
                item.mesh_status = "completed"
                await db.commit()
                logger.info("Successfully generated and stored mesh for item %s at %s", item_id, glb_path)

    except Exception as e:
        logger.exception("Mesh reconstruction failed for item %s", item_id)
        async with AsyncSessionLocal() as db:
            item = await db.scalar(select(ClothingItem).where(ClothingItem.id == item_id))
            if item:
                item.mesh_status = "failed"
                await db.commit()
        raise e
