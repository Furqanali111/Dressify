import logging
import uuid
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.upload_retry_queue import UploadRetryQueue
from app.models.user import User
from app.deps import get_current_user
from app.services.storage import upload_file
from app.schemas.clothing import ClothingItemResponse
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/upload", tags=["Upload"])


@router.post("", response_model=list[ClothingItemResponse])
@limiter.limit("5/minute")
async def upload_clothing(
    request: Request,
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

    # Always background: save raw image, create a visible placeholder, enqueue ARQ job.
    # The client sees a "processing" card immediately; Ollama runs outside the request.
    placeholder, entry_id = await _create_upload_entry(
        db, current_user.id, image_bytes, name.strip()
    )
    await db.commit()
    await db.refresh(placeholder)

    from app.services.retry_worker import _arq_pool
    if _arq_pool is not None:
        await _arq_pool.enqueue_job("process_upload_job", str(entry_id))
    else:
        logger.warning("ARQ pool unavailable — upload %s will be retried by retry worker", entry_id)

    resp = ClothingItemResponse.model_validate(placeholder)
    resp.processed_url = ""
    return [resp]


async def _create_upload_entry(
    db: AsyncSession,
    user_id: uuid.UUID,
    image_bytes: bytes,
    original_name: str,
) -> tuple[ClothingItem, uuid.UUID]:
    """Save raw image, create a 'processing' placeholder, and a retry-queue entry.

    Returns (placeholder, entry_id). Caller must commit + refresh.
    """
    retry_id = uuid.uuid4()
    item_id = uuid.uuid4()
    raw_path = f"retries/{user_id}/{retry_id}.jpg"

    stored = upload_file("clothing-raw-temp", raw_path, image_bytes, "image/jpeg")
    if not stored:
        logger.warning("Could not store raw image for entry %s — worker will fail quickly", retry_id)

    placeholder = ClothingItem(
        id=item_id,
        user_id=user_id,
        name=original_name or "Processing…",
        type="other",
        processing_status="processing",
    )
    db.add(placeholder)
    await db.flush()

    entry = UploadRetryQueue(
        id=retry_id,
        user_id=user_id,
        clothing_item_id=item_id,
        raw_image_path=raw_path,
        original_name=original_name,
        attempt_count=0,
        max_attempts=settings.UPLOAD_MAX_RETRIES,
        next_retry_at=datetime.now(timezone.utc) + timedelta(seconds=settings.RETRY_INTERVAL_SECONDS),
        status="pending",
    )
    db.add(entry)
    return placeholder, retry_id
