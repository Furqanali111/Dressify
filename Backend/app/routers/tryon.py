import asyncio
import base64
import logging
import time
import uuid

import httpx
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db import get_db
from app.deps import get_current_user
from app.models.clothing_item import ClothingItem
from app.models.user import User
from app.services import storage
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tryon", tags=["tryon"])

_FASHN_RUN_URL    = "https://api.fashn.ai/v1/run"
_FASHN_STATUS_URL = "https://api.fashn.ai/v1/status/{id}"
_POLL_INTERVAL    = 2      # seconds between status polls
_POLL_MAX         = 45     # give up after 90 seconds (45 × 2s)


@router.post("")
@limiter.limit("10/minute")
async def create_tryon(
    request: Request,
    person_image: UploadFile = File(...),
    clothing_item_id: str = Form(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Generate a photo-realistic try-on image via fashn.ai (or Replicate fallback).

    Returns: { "result_url": "<signed URL valid for 1 hour>" }
    """
    # ── 1. Validate item ownership ──────────────────────────────────────────
    result = await db.execute(
        select(ClothingItem).where(
            ClothingItem.id == uuid.UUID(clothing_item_id),
            ClothingItem.user_id == current_user.id,
        )
    )
    item: ClothingItem | None = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Clothing item not found")
    if not item.processed_image_path:
        raise HTTPException(status_code=422, detail="Item has no processed image yet")

    # ── 2. Download garment PNG from Supabase ───────────────────────────────
    garment_bytes: bytes | None = await asyncio.to_thread(
        storage.download_file, settings.CLOTHING_BUCKET, item.processed_image_path
    )
    if not garment_bytes:
        raise HTTPException(status_code=502, detail="Could not download garment image")

    # ── 3. Read person photo ────────────────────────────────────────────────
    person_bytes = await person_image.read()
    if not person_bytes:
        raise HTTPException(status_code=400, detail="Person image is empty")

    # ── 4. Call VTON API ────────────────────────────────────────────────────
    try:
        result_bytes = await _call_vton_api(person_bytes, garment_bytes, item.type or "tops")
    except TimeoutError:
        raise HTTPException(status_code=504, detail="Try-on API timed out — try again")
    except RuntimeError as exc:
        logger.error("VTON API error: %s", exc)
        raise HTTPException(status_code=502, detail="Try-on API failed")

    # ── 5. Store result in Supabase ─────────────────────────────────────────
    result_path = f"tryon/{current_user.id}/{clothing_item_id}_{int(time.time())}.jpg"
    ok = await asyncio.to_thread(
        storage.upload_file,
        settings.CLOTHING_BUCKET,
        result_path,
        result_bytes,
        "image/jpeg",
    )
    if not ok:
        raise HTTPException(status_code=502, detail="Failed to store result image")

    # ── 6. Return signed URL (1-hour expiry) ────────────────────────────────
    signed_url = await asyncio.to_thread(
        storage.get_signed_url, settings.CLOTHING_BUCKET, result_path, 3600
    )
    if not signed_url:
        raise HTTPException(status_code=502, detail="Failed to generate result URL")

    return {"result_url": signed_url}


# ---------------------------------------------------------------------------
# VTON API helpers
# ---------------------------------------------------------------------------

async def _call_vton_api(person_bytes: bytes, garment_bytes: bytes, garment_type: str) -> bytes:
    if settings.FASHN_API_KEY:
        return await _fashn_tryon(person_bytes, garment_bytes, garment_type)
    if settings.REPLICATE_API_KEY:
        return await _replicate_tryon(person_bytes, garment_bytes)
    raise HTTPException(status_code=503, detail="No VTON API key configured")


def _clothing_category(garment_type: str) -> str:
    """Map internal garment type to fashn.ai category string."""
    t = garment_type.lower()
    if any(k in t for k in ("pant", "trouser", "jean", "short", "skirt")):
        return "bottoms"
    if any(k in t for k in ("dress", "jumpsuit", "overall")):
        return "one-pieces"
    return "tops"


async def _fashn_tryon(person_bytes: bytes, garment_bytes: bytes, garment_type: str) -> bytes:
    category = _clothing_category(garment_type)
    headers  = {"Authorization": f"Bearer {settings.FASHN_API_KEY}"}

    async with httpx.AsyncClient(timeout=120) as client:
        # Submit job
        resp = await client.post(
            _FASHN_RUN_URL,
            headers=headers,
            json={
                "model_image":   base64.b64encode(person_bytes).decode(),
                "garment_image": base64.b64encode(garment_bytes).decode(),
                "category":      category,
            },
        )
        resp.raise_for_status()
        prediction_id = resp.json()["id"]

        # Poll until done
        for _ in range(_POLL_MAX):
            await asyncio.sleep(_POLL_INTERVAL)
            status_resp = await client.get(
                _FASHN_STATUS_URL.format(id=prediction_id),
                headers=headers,
            )
            status_resp.raise_for_status()
            data = status_resp.json()

            if data["status"] == "completed":
                img_resp = await client.get(data["output"][0])
                img_resp.raise_for_status()
                return img_resp.content
            if data["status"] in ("failed", "cancelled"):
                raise RuntimeError(f"fashn.ai job {prediction_id} {data['status']}")

    raise TimeoutError(f"fashn.ai job {prediction_id} did not complete in time")


async def _replicate_tryon(person_bytes: bytes, garment_bytes: bytes) -> bytes:
    """Fallback: Replicate IDM-VTON model."""
    headers = {
        "Authorization": f"Token {settings.REPLICATE_API_KEY}",
        "Content-Type":  "application/json",
    }
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            "https://api.replicate.com/v1/predictions",
            headers=headers,
            json={
                "version": "c871bb9b046607b680449ecbae55fd8c6d945e0a1948644bf2361b3d021d3ff4",
                "input": {
                    "human_img":    base64.b64encode(person_bytes).decode(),
                    "garm_img":     base64.b64encode(garment_bytes).decode(),
                    "garment_des":  "clothing",
                    "is_checked":   True,
                    "is_checked_crop": False,
                    "denoise_steps": 30,
                    "seed": 42,
                },
            },
        )
        resp.raise_for_status()
        prediction = resp.json()
        poll_url = prediction["urls"]["get"]

        for _ in range(_POLL_MAX):
            await asyncio.sleep(_POLL_INTERVAL)
            poll = await client.get(poll_url, headers=headers)
            poll.raise_for_status()
            data = poll.json()
            if data["status"] == "succeeded":
                img_resp = await client.get(data["output"])
                img_resp.raise_for_status()
                return img_resp.content
            if data["status"] in ("failed", "canceled"):
                raise RuntimeError(f"Replicate job {data['id']} {data['status']}")

    raise TimeoutError("Replicate job did not complete in time")
