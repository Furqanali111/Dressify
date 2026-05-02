import logging
import uuid
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, BackgroundTasks, Request
from starlette.concurrency import run_in_threadpool
from PIL import UnidentifiedImageError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.upload_retry_queue import UploadRetryQueue
from app.models.user import User
from app.deps import get_current_user
from app.services.storage import upload_file, get_signed_url
from app.services.image_processing import detect_garments_in_image, extract_garment, detect_type_and_anchors
from app.services.ai_vision import extract_clothing_metadata
from app.schemas.clothing import ClothingItemResponse
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/upload", tags=["Upload"])


# ---------------------------------------------------------------------------
# POST /upload
# ---------------------------------------------------------------------------

@router.post("", response_model=list[ClothingItemResponse])
@limiter.limit("5/minute")
async def upload_clothing(
    request: Request,
    background_tasks: BackgroundTasks,
    image: UploadFile = File(...),
    name: str = Form(""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    image_bytes = await image.read()
    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image must be < 10 MB")

    # ── 1. Detect garments ────────────────────────────────────────────────
    try:
        garments = await detect_garments_in_image(image_bytes)
    except Exception as e:
        # Transient failure (Ollama down, timeout, parse error, …).
        # Queue for retry and return a placeholder "processing" item immediately
        # so the user sees something in their wardrobe without an error screen.
        logger.error("Garment detection failed — queuing for retry: %s", e)
        placeholder = await _enqueue_retry(
            db, current_user.id, image_bytes, name.strip()
        )
        await db.commit()
        await db.refresh(placeholder)
        resp = ClothingItemResponse.model_validate(placeholder)
        resp.processed_url = ""
        return [resp]

    # Model ran successfully but found no clothing → fail immediately, no retry.
    if not garments:
        raise HTTPException(
            status_code=422,
            detail=(
                "No garments could be extracted from the uploaded image. "
                "Please upload a clear photo of clothing items."
            ),
        )

    # ── 2. Extract, classify, and persist each garment ───────────────────
    results: list[tuple[ClothingItem, str, bytes]] = []
    garment_count = len(garments)

    for idx, garment in enumerate(garments):
        item_id = uuid.uuid4()
        processed_path = f"{current_user.id}/{item_id}.png"

        label = garment.get("label", "clothing").strip().title()
        if garment_count == 1:
            item_name = name.strip() if name.strip() else label
        else:
            base = name.strip() if name.strip() else label
            item_name = f"{base} ({idx + 1}/{garment_count})"

        # 2a. Extract garment pixels (crop + bg removal)
        try:
            garment_bytes = await run_in_threadpool(extract_garment, image_bytes, garment["bbox"])
        except UnidentifiedImageError:
            logger.warning("Garment %d skipped — unrecognised image format", idx + 1)
            continue
        except MemoryError:
            logger.error("OOM during garment extraction")
            raise HTTPException(status_code=503, detail="Server busy — try again shortly")
        except Exception as e:
            logger.warning("Garment %d extraction failed, skipping: %s", idx + 1, e)
            continue

        # 2b. Store in processed bucket (no raw image saved)
        if not upload_file(settings.CLOTHING_BUCKET, processed_path, garment_bytes, "image/png"):
            logger.warning("Garment %d storage failed, skipping", idx + 1)
            continue

        # 2c. Classify type + anchor points
        try:
            detected_type, anchors, confidence = await detect_type_and_anchors(garment_bytes)
        except Exception as e:
            logger.warning("Type detection failed for garment %d: %s", idx + 1, e)
            detected_type, anchors, confidence = "other", {}, 0.50

        # 2d. DB row
        item = ClothingItem(
            id=item_id,
            user_id=current_user.id,
            name=item_name,
            type=detected_type,
            processed_image_path=processed_path,
            detection_confidence=confidence,
            anchor_points=anchors,
        )
        db.add(item)

        results.append((item, processed_path, garment_bytes))

    if not results:
        raise HTTPException(
            status_code=422,
            detail=(
                "No garments could be extracted from the uploaded image. "
                "Please upload a clear photo of clothing items."
            ),
        )

    # ── 3. Commit + sign URLs ─────────────────────────────────────────────
    await db.commit()

    response_items: list[ClothingItemResponse] = []
    for item, processed_path, garment_bytes in results:
        # Schedule async metadata extraction (color, pattern, style, sub_type)
        background_tasks.add_task(extract_clothing_metadata, item.id, garment_bytes)
        
        await db.refresh(item)
        processed_url = get_signed_url(settings.CLOTHING_BUCKET, processed_path) or ""
        resp = ClothingItemResponse.model_validate(item)
        resp.processed_url = processed_url
        response_items.append(resp)

    return response_items


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

async def _enqueue_retry(
    db: AsyncSession,
    user_id: uuid.UUID,
    image_bytes: bytes,
    original_name: str,
) -> ClothingItem:
    """
    Store the raw image in the clothing-raw-temp bucket, create a placeholder
    ClothingItem (processing_status='processing') and an UploadRetryQueue entry.
    Returns the placeholder so it can be returned to the client immediately.

    NOTE: caller must commit + refresh after this call.
    NOTE: the 'clothing-raw-temp' bucket must be created in the Supabase dashboard.
    """
    from app.services.storage import upload_file as _upload

    retry_id = uuid.uuid4()
    item_id = uuid.uuid4()
    raw_path = f"retries/{user_id}/{retry_id}.jpg"

    # Best-effort: if temp storage is unavailable the retry worker will just
    # fail to download and mark the entry as failed after max_attempts.
    stored = _upload("clothing-raw-temp", raw_path, image_bytes, "image/jpeg")
    if not stored:
        logger.warning("Could not store raw image for retry %s — worker will fail quickly", retry_id)

    # Placeholder visible to the user immediately as a 'processing' card
    placeholder = ClothingItem(
        id=item_id,
        user_id=user_id,
        name=original_name or "Pending Item",
        type="other",
        processing_status="processing",
    )
    db.add(placeholder)
    await db.flush()  # write placeholder so the FK below resolves

    entry = UploadRetryQueue(
        id=retry_id,
        user_id=user_id,
        clothing_item_id=item_id,
        raw_image_path=raw_path,
        original_name=original_name,
        attempt_count=0,
        max_attempts=settings.UPLOAD_MAX_RETRIES,
        next_retry_at=datetime.now(timezone.utc)
            + timedelta(seconds=settings.RETRY_INTERVAL_SECONDS),
        status="pending",
    )
    db.add(entry)
    return placeholder
