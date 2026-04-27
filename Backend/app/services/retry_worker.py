"""
Upload retry worker.

Runs as a long-lived asyncio task (started in the FastAPI lifespan).
Every RETRY_INTERVAL_SECONDS it queries upload_retry_queue for pending entries
whose next_retry_at has passed, then re-runs garment detection on each one.

Failure taxonomy
----------------
transient  → model/network error during detection_garments_in_image()
             → re-schedule with the same interval, up to max_attempts
permanent  → all attempts exhausted
             → ClothingItem.processing_status set to 'failed'
             → raw temp image deleted from Supabase
no-op      → user deleted the placeholder ClothingItem before retry succeeded
             → entry marked succeeded, temp image deleted (nothing to update)
"""

import asyncio
import logging
import uuid
from datetime import datetime, timezone, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db import AsyncSessionLocal
from app.models.clothing_item import ClothingItem
from app.models.upload_retry_queue import UploadRetryQueue
from app.services.image_processing import (
    detect_garments_in_image,
    extract_garment,
    detect_type_and_anchors,
)
from app.services.storage import download_file, upload_file, delete_file

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

async def run_retry_worker() -> None:
    """Long-running task. Wakes every RETRY_INTERVAL_SECONDS and processes the queue."""
    logger.info(
        "Upload retry worker started — interval=%ds, max_retries=%d",
        settings.RETRY_INTERVAL_SECONDS,
        settings.UPLOAD_MAX_RETRIES,
    )
    while True:
        await asyncio.sleep(settings.RETRY_INTERVAL_SECONDS)
        try:
            await _tick()
        except Exception:
            logger.exception("Retry worker tick raised unexpectedly")


# ---------------------------------------------------------------------------
# Per-tick: fetch all due entries and dispatch them
# ---------------------------------------------------------------------------

async def _tick() -> None:
    async with AsyncSessionLocal() as db:
        now = datetime.now(timezone.utc)
        result = await db.execute(
            select(UploadRetryQueue).where(
                UploadRetryQueue.status == "pending",
                UploadRetryQueue.next_retry_at <= now,
            )
        )
        entries = result.scalars().all()

    if not entries:
        return

    logger.info("Retry worker: %d item(s) due for processing", len(entries))
    for entry in entries:
        # Each entry gets its own session so one failure can't roll back others.
        try:
            await _process_entry(entry)
        except Exception:
            logger.exception("Unhandled error processing retry entry %s", entry.id)


# ---------------------------------------------------------------------------
# Per-entry processing
# ---------------------------------------------------------------------------

async def _process_entry(entry: UploadRetryQueue) -> None:
    async with AsyncSessionLocal() as db:
        # Re-attach the entry to this session
        result = await db.execute(
            select(UploadRetryQueue).where(UploadRetryQueue.id == entry.id)
        )
        entry = result.scalar_one_or_none()
        if entry is None or entry.status != "pending":
            return  # picked up by a concurrent tick, skip

        entry.attempt_count += 1
        entry.status = "retrying"
        await db.commit()

    # Work outside the session so we're not holding a connection during I/O
    try:
        await _do_retry(entry)
    except Exception as e:
        logger.warning(
            "Retry %s attempt %d/%d failed: %s",
            entry.id, entry.attempt_count, entry.max_attempts, e,
        )
        await _handle_failure(entry, str(e))


async def _do_retry(entry: UploadRetryQueue) -> None:
    # 1. Download the raw image stored when the upload first failed.
    raw_bytes = download_file("clothing-raw-temp", entry.raw_image_path)
    if not raw_bytes:
        raise RuntimeError("Could not download raw image from temp storage")

    # 2. Re-run garment detection (raises on model/network error).
    garments = await detect_garments_in_image(raw_bytes)
    if not garments:
        # Model ran cleanly but found nothing — permanent failure, no point retrying.
        raise RuntimeError("Detection found no garments in the image")

    # 3. Check whether the placeholder still exists (user may have deleted it).
    async with AsyncSessionLocal() as db:
        placeholder: ClothingItem | None = None
        if entry.clothing_item_id:
            res = await db.execute(
                select(ClothingItem).where(ClothingItem.id == entry.clothing_item_id)
            )
            placeholder = res.scalar_one_or_none()

        if placeholder is None:
            # User deleted the card — clean up and exit gracefully.
            logger.info("Retry %s: placeholder deleted by user, cleaning up", entry.id)
            await _mark_succeeded(entry)
            delete_file("clothing-raw-temp", entry.raw_image_path)
            return

        # 4. Extract, bg-remove, classify, and persist each detected garment.
        garment_count = len(garments)
        processed_any = False

        for idx, garment in enumerate(garments):
            is_placeholder_slot = idx == 0
            item_id = entry.clothing_item_id if is_placeholder_slot else uuid.uuid4()
            processed_path = f"{entry.user_id}/{item_id}.png"

            # 4a. Extract garment pixels
            try:
                garment_bytes = extract_garment(raw_bytes, garment["bbox"])
            except Exception as e:
                logger.warning("Retry %s garment %d extraction failed: %s", entry.id, idx, e)
                continue

            # 4b. Upload to processed bucket
            if not upload_file("clothing-processed", processed_path, garment_bytes, "image/png"):
                logger.warning("Retry %s garment %d storage failed", entry.id, idx)
                continue

            # 4c. Classify type + anchor points
            try:
                detected_type, anchors, confidence = await detect_type_and_anchors(garment_bytes)
            except Exception:
                detected_type, anchors, confidence = "other", {}, 0.5

            label = garment.get("label", "clothing").strip().title()

            if is_placeholder_slot:
                # Update the existing placeholder with real data
                placeholder.name = entry.original_name or label
                placeholder.type = detected_type
                placeholder.processed_image_path = processed_path
                placeholder.detection_confidence = confidence
                placeholder.anchor_points = anchors
                placeholder.processing_status = "processing"  # metadata still pending
            else:
                # Additional garments get brand-new ClothingItem rows
                base = entry.original_name or label
                item_name = f"{base} ({idx + 1}/{garment_count})" if garment_count > 1 else base
                new_item = ClothingItem(
                    id=item_id,
                    user_id=entry.user_id,
                    name=item_name,
                    type=detected_type,
                    processed_image_path=processed_path,
                    detection_confidence=confidence,
                    anchor_points=anchors,
                    processing_status="processing",
                )
                db.add(new_item)

            # 4d. Fire-and-forget metadata extraction (color, pattern, style…)
            asyncio.create_task(_run_metadata(item_id, garment_bytes))
            processed_any = True

        if not processed_any:
            raise RuntimeError("All garments failed during extraction/upload")

        await db.commit()

    await _mark_succeeded(entry)
    delete_file("clothing-raw-temp", entry.raw_image_path)
    logger.info(
        "Retry %s succeeded after %d attempt(s)", entry.id, entry.attempt_count
    )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _mark_succeeded(entry: UploadRetryQueue) -> None:
    async with AsyncSessionLocal() as db:
        res = await db.execute(
            select(UploadRetryQueue).where(UploadRetryQueue.id == entry.id)
        )
        row = res.scalar_one_or_none()
        if row:
            row.status = "succeeded"
            await db.commit()


async def _handle_failure(entry: UploadRetryQueue, reason: str) -> None:
    async with AsyncSessionLocal() as db:
        res = await db.execute(
            select(UploadRetryQueue).where(UploadRetryQueue.id == entry.id)
        )
        row = res.scalar_one_or_none()
        if not row:
            return

        row.error_message = reason[:500]

        if row.attempt_count >= row.max_attempts:
            # Permanently failed — mark the clothing card as failed too
            row.status = "failed"
            if row.clothing_item_id:
                ci_res = await db.execute(
                    select(ClothingItem).where(ClothingItem.id == row.clothing_item_id)
                )
                ci = ci_res.scalar_one_or_none()
                if ci:
                    ci.processing_status = "failed"

            delete_file("clothing-raw-temp", row.raw_image_path)
            logger.warning(
                "Retry %s permanently failed after %d attempt(s): %s",
                row.id, row.attempt_count, reason,
            )
        else:
            # Schedule next attempt
            row.status = "pending"
            row.next_retry_at = datetime.now(timezone.utc) + timedelta(
                seconds=settings.RETRY_INTERVAL_SECONDS
            )

        await db.commit()


async def _run_metadata(item_id: uuid.UUID, image_bytes: bytes) -> None:
    """Fire-and-forget wrapper so metadata extraction doesn't block the retry loop."""
    from app.services.ai_vision import extract_clothing_metadata
    try:
        await extract_clothing_metadata(item_id, image_bytes)
    except Exception:
        logger.exception("Metadata extraction failed for retry item %s", item_id)
