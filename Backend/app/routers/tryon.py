import asyncio
import base64
import hashlib
import io
import logging
import time
import uuid

import httpx
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, status
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


_MIN_PHOTO_SIDE = 400  # px; smaller photos give poor try-on results


def _photo_path(user_id) -> str:
    return f"tryon/{user_id}/person.jpg"


def _prepare_photo(raw: bytes) -> bytes:
    """Validate a user photo and normalise it to the VTON model's 768x1024 JPEG."""
    from PIL import Image, ImageOps, UnidentifiedImageError

    if not raw:
        raise HTTPException(status_code=400, detail="Photo is empty")
    try:
        img = ImageOps.exif_transpose(Image.open(io.BytesIO(raw)))
        img.load()
    except (UnidentifiedImageError, OSError):
        raise HTTPException(status_code=422, detail="That file is not a valid image")
    if min(img.size) < _MIN_PHOTO_SIDE:
        raise HTTPException(
            status_code=422,
            detail="Photo is too small — use a clear, full-body photo taken closer to the camera",
        )
    if img.width > img.height * 1.2:
        raise HTTPException(
            status_code=422,
            detail="Use a portrait (upright) full-body photo",
        )
    buf = io.BytesIO()
    img.convert("RGB").save(buf, format="JPEG", quality=95)
    return _resize_person_image(buf.getvalue())


@router.get("/photo")
async def get_tryon_photo(current_user: User = Depends(get_current_user)):
    """Does the user have a saved try-on photo? Returns a short-lived preview URL."""
    path = _photo_path(current_user.id)
    if not await asyncio.to_thread(storage.file_exists, settings.CLOTHING_BUCKET, path):
        return {"has_photo": False, "url": None}
    url = await asyncio.to_thread(storage.get_signed_url, settings.CLOTHING_BUCKET, path, 3600)
    return {"has_photo": url is not None, "url": url}


@router.put("/photo")
@limiter.limit("20/hour")
async def save_tryon_photo(
    request: Request,
    photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """Save (replace) the user's try-on photo so later try-ons need no camera."""
    prepared = await asyncio.to_thread(_prepare_photo, await photo.read())
    ok = await asyncio.to_thread(
        storage.upload_file, settings.CLOTHING_BUCKET, _photo_path(current_user.id),
        prepared, "image/jpeg", True,
    )
    if not ok:
        raise HTTPException(status_code=502, detail="Could not save your photo — please try again")
    url = await asyncio.to_thread(
        storage.get_signed_url, settings.CLOTHING_BUCKET, _photo_path(current_user.id), 3600
    )
    return {"has_photo": True, "url": url}


@router.delete("/photo", status_code=status.HTTP_204_NO_CONTENT)
async def delete_tryon_photo(current_user: User = Depends(get_current_user)):
    await asyncio.to_thread(storage.delete_file, settings.CLOTHING_BUCKET, _photo_path(current_user.id))


@router.post("")
@limiter.limit("10/day")
async def create_tryon(
    request: Request,
    clothing_item_id: str = Form(...),
    person_image: UploadFile | None = File(None),
    save_photo: bool = Form(False),
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

    # ── 2. Person photo: fresh upload, or the saved one ────────────────────
    if person_image is not None:
        person_bytes = await asyncio.to_thread(_prepare_photo, await person_image.read())
        if save_photo:
            await asyncio.to_thread(
                storage.upload_file, settings.CLOTHING_BUCKET, _photo_path(current_user.id),
                person_bytes, "image/jpeg", True,
            )
    else:
        person_bytes = await asyncio.to_thread(
            storage.download_file, settings.CLOTHING_BUCKET, _photo_path(current_user.id)
        )
        if not person_bytes:
            raise HTTPException(
                status_code=400,
                detail="Add a photo of yourself first to use AI try-on",
            )

    # ── 2b. Check 24-hour result cache (S5.1.5) ────────────────────────────
    # Keyed by photo content too, so a new photo never returns a stale result.
    photo_key = hashlib.sha1(person_bytes).hexdigest()[:10]
    cache_img_path = f"tryon/{current_user.id}/{clothing_item_id}_{photo_key}_cached.jpg"
    cached_url = await asyncio.to_thread(
        _check_tryon_cache, cache_img_path
    )
    if cached_url:
        return {"result_url": cached_url}

    # ── 3. Download garment PNG from Supabase ───────────────────────────────
    garment_bytes: bytes | None = await asyncio.to_thread(
        storage.download_file, settings.CLOTHING_BUCKET, item.processed_image_path
    )
    if not garment_bytes:
        raise HTTPException(status_code=502, detail="Could not download garment image")

    # ── 6. Build garment description from AI metadata (S5.1.3) ────────────
    garment_desc = " ".join(
        part for part in [item.color, item.style, item.type] if part
    ) or "clothing"

    # ── 7. Call VTON API ────────────────────────────────────────────────────
    try:
        result_bytes = await _call_vton_api(
            person_bytes, garment_bytes, item.type or "tops", garment_desc
        )
    except TimeoutError:
        raise HTTPException(
            status_code=504,
            detail="Our AI stylists are busy — try again in a moment",
        )
    except httpx.ConnectError:
        raise HTTPException(
            status_code=503,
            detail="Could not reach the try-on service — check your internet connection and try again",
        )
    except httpx.HTTPStatusError as exc:
        logger.error("VTON API HTTP error: %s", exc)
        raise HTTPException(status_code=502, detail="Try-on API returned an error — please try again")
    except RuntimeError as exc:
        logger.error("VTON API error: %s", exc)
        raise HTTPException(status_code=502, detail="Try-on API failed — please try again")

    # ── 8. Store result in Supabase with deterministic path (S5.1.5) ────────
    ts_path = cache_img_path.replace("_cached.jpg", "_ts.txt")
    await asyncio.to_thread(
        storage.upload_file,
        settings.CLOTHING_BUCKET,
        cache_img_path,
        result_bytes,
        "image/jpeg",
        True,  # upsert
    )
    await asyncio.to_thread(
        storage.upload_file,
        settings.CLOTHING_BUCKET,
        ts_path,
        str(int(time.time())).encode(),
        "text/plain",
        True,  # upsert
    )

    # ── 9. Return signed URL (1-hour expiry) ────────────────────────────────
    signed_url = await asyncio.to_thread(
        storage.get_signed_url, settings.CLOTHING_BUCKET, cache_img_path, 3600
    )
    if not signed_url:
        raise HTTPException(status_code=502, detail="Failed to generate result URL")

    return {"result_url": signed_url}


# ---------------------------------------------------------------------------
# 24-hour result cache (S5.1.5)
# ---------------------------------------------------------------------------

def _check_tryon_cache(cache_img_path: str) -> str | None:
    """Return a signed URL for a cached result if it is less than 24 hours old."""
    ts_path = cache_img_path.replace("_cached.jpg", "_ts.txt")
    ts_bytes = storage.download_file(settings.CLOTHING_BUCKET, ts_path)
    if not ts_bytes:
        return None
    try:
        cached_at = int(ts_bytes.decode().strip())
    except (ValueError, UnicodeDecodeError):
        return None
    now = time.time()
    # Reject timestamps that are in the future or older than 7 days (corrupted).
    if cached_at > now or now - cached_at >= 86400:
        return None
    return storage.get_signed_url(settings.CLOTHING_BUCKET, cache_img_path, 3600)


# ---------------------------------------------------------------------------
# Image pre-processing
# ---------------------------------------------------------------------------

def _resize_person_image(person_bytes: bytes, target_w: int = 768, target_h: int = 1024) -> bytes:
    """Center-crop + resize person photo to the VTON model's preferred resolution."""
    from PIL import Image
    img = Image.open(io.BytesIO(person_bytes)).convert("RGB")
    w, h = img.size
    target_ratio = target_w / target_h
    current_ratio = w / h
    if current_ratio > target_ratio:
        new_w = int(h * target_ratio)
        left = (w - new_w) // 2
        img = img.crop((left, 0, left + new_w, h))
    elif current_ratio < target_ratio:
        new_h = int(w / target_ratio)
        top = (h - new_h) // 2
        img = img.crop((0, top, w, top + new_h))
    img = img.resize((target_w, target_h), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=95)
    return buf.getvalue()


# ---------------------------------------------------------------------------
# VTON API helpers
# ---------------------------------------------------------------------------

async def _call_vton_api(
    person_bytes: bytes, garment_bytes: bytes, garment_type: str, garment_desc: str = "clothing"
) -> bytes:
    if settings.FASHN_API_KEY:
        return await _fashn_tryon(person_bytes, garment_bytes, garment_type, garment_desc)
    if settings.REPLICATE_API_KEY:
        return await _replicate_tryon(person_bytes, garment_bytes, garment_desc)
    raise HTTPException(status_code=503, detail="No VTON API key configured")


def _clothing_category(garment_type: str) -> str:
    """Map internal garment type to fashn.ai category string."""
    t = garment_type.lower()
    if any(k in t for k in ("pant", "trouser", "jean", "short", "skirt")):
        return "bottoms"
    if any(k in t for k in ("dress", "jumpsuit", "overall")):
        return "one-pieces"
    return "tops"


async def _fashn_tryon(
    person_bytes: bytes, garment_bytes: bytes, garment_type: str, garment_desc: str = "clothing"
) -> bytes:
    category = _clothing_category(garment_type)
    headers  = {"Authorization": f"Bearer {settings.FASHN_API_KEY}"}

    async with httpx.AsyncClient(timeout=120) as client:
        # Submit job
        resp = await client.post(
            _FASHN_RUN_URL,
            headers=headers,
            json={
                "model_image":        base64.b64encode(person_bytes).decode(),
                "garment_image":      base64.b64encode(garment_bytes).decode(),
                "category":           category,
                "garment_description": garment_desc,
            },
        )
        resp.raise_for_status()
        run_data = resp.json()
        prediction_id = run_data.get("id")
        if not prediction_id:
            raise RuntimeError(f"fashn.ai did not return a job id: {run_data}")

        # Poll until done
        for _ in range(_POLL_MAX):
            await asyncio.sleep(_POLL_INTERVAL)
            status_resp = await client.get(
                _FASHN_STATUS_URL.format(id=prediction_id),
                headers=headers,
            )
            status_resp.raise_for_status()
            data = status_resp.json()
            job_status = data.get("status")

            if job_status == "completed":
                output = data.get("output") or []
                if not output:
                    raise RuntimeError(f"fashn.ai job {prediction_id} completed but returned no output")
                img_resp = await client.get(output[0])
                img_resp.raise_for_status()
                return img_resp.content
            if job_status in ("failed", "cancelled"):
                raise RuntimeError(f"fashn.ai job {prediction_id} {job_status}")

    raise TimeoutError(f"fashn.ai job {prediction_id} did not complete in time")


async def _replicate_tryon(person_bytes: bytes, garment_bytes: bytes, garment_desc: str = "clothing") -> bytes:
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
                    "garment_des":  garment_desc,
                    "is_checked":   True,
                    "is_checked_crop": False,
                    "denoise_steps": 30,
                    "seed": 42,
                },
            },
        )
        resp.raise_for_status()
        prediction = resp.json()
        poll_url = (prediction.get("urls") or {}).get("get")
        if not poll_url:
            raise RuntimeError(f"Replicate did not return a poll URL: {prediction}")

        for _ in range(_POLL_MAX):
            await asyncio.sleep(_POLL_INTERVAL)
            poll = await client.get(poll_url, headers=headers)
            poll.raise_for_status()
            data = poll.json()
            if data.get("status") == "succeeded":
                output = data.get("output")
                if not output:
                    raise RuntimeError(f"Replicate job succeeded but returned no output")
                img_resp = await client.get(output)
                img_resp.raise_for_status()
                return img_resp.content
            if data.get("status") in ("failed", "canceled"):
                raise RuntimeError(f"Replicate job {data.get('id')} {data.get('status')}")

    raise TimeoutError("Replicate job did not complete in time")
