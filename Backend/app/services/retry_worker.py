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
from typing import Optional

from arq import ArqRedis, create_pool
from arq.connections import RedisSettings
from sqlalchemy import select, delete

from app.config import settings
from app.db import AsyncSessionLocal
from app.models.clothing_item import ClothingItem
from app.models.upload_retry_queue import UploadRetryQueue
from app.services.image_processing import (
    detect_and_analyze_garments,
    extract_garment,
    _TYPE_ANCHORS,
)
from app.services.storage import download_file, upload_file, delete_file

logger = logging.getLogger(__name__)

_MAX_CONSECUTIVE_FAILURES = 5
_BASE_BACKOFF_SECONDS = 60
_MAX_BACKOFF_SECONDS = 600

_arq_pool: Optional[ArqRedis] = None


async def init_arq_pool() -> None:
    global _arq_pool
    _arq_pool = await create_pool(RedisSettings.from_dsn(settings.REDIS_URL))
    logger.info("ARQ pool connected to %s", settings.REDIS_URL)


async def close_arq_pool() -> None:
    global _arq_pool
    if _arq_pool:
        await _arq_pool.aclose()
        _arq_pool = None
        logger.info("ARQ pool closed")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

async def run_retry_worker() -> None:
    """Long-running task. Wakes every RETRY_INTERVAL_SECONDS and processes the queue.

    Circuit-breaker: after 5 consecutive tick failures, logs CRITICAL and backs off
    exponentially (capped at 10 minutes) so ops staff gets a clear signal.
    """
    logger.info(
        "Upload retry worker started — interval=%ds, max_retries=%d",
        settings.RETRY_INTERVAL_SECONDS,
        settings.UPLOAD_MAX_RETRIES,
    )
    consecutive_failures = 0

    while True:
        await asyncio.sleep(settings.RETRY_INTERVAL_SECONDS)
        try:
            await _tick()
            if consecutive_failures > 0:
                logger.info("Retry worker recovered after %d consecutive failure(s)", consecutive_failures)
            consecutive_failures = 0
        except Exception:
            consecutive_failures += 1
            logger.exception("Retry worker tick raised unexpectedly (failure %d)", consecutive_failures)
            if consecutive_failures >= _MAX_CONSECUTIVE_FAILURES:
                backoff = min(_BASE_BACKOFF_SECONDS * (2 ** (consecutive_failures - _MAX_CONSECUTIVE_FAILURES)), _MAX_BACKOFF_SECONDS)
                logger.critical(
                    "RETRY WORKER: %d consecutive tick failures — backing off %ds. "
                    "Check DB connectivity and Ollama availability.",
                    consecutive_failures, backoff,
                )
                await asyncio.sleep(backoff)


# ---------------------------------------------------------------------------
# Per-tick: fetch all due entries and dispatch them
# ---------------------------------------------------------------------------

async def _tick() -> None:
    # Single session for both the due-entry fetch and the stale-entry prune —
    # avoids opening two connections from the pool for back-to-back operations.
    now = datetime.now(timezone.utc)
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(UploadRetryQueue).where(
                UploadRetryQueue.status == "pending",
                UploadRetryQueue.next_retry_at <= now,
            )
        )
        entries = result.scalars().all()

        # Prune failed entries older than 30 days so the queue doesn't grow unboundedly.
        cutoff = now - timedelta(days=30)
        await db.execute(
            delete(UploadRetryQueue).where(
                UploadRetryQueue.status == "failed",
                UploadRetryQueue.created_at < cutoff,
            )
        )
        await db.commit()

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
        # Re-attach with a row-level lock so concurrent ticks/ARQ workers
        # can't both claim the same entry in the TOCTOU window.
        result = await db.execute(
            select(UploadRetryQueue)
            .where(UploadRetryQueue.id == entry.id)
            .with_for_update(skip_locked=True)
        )
        entry = result.scalar_one_or_none()
        if entry is None or entry.status != "pending":
            return  # locked by a concurrent worker, skip

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
    raw_bytes = await asyncio.to_thread(download_file, "clothing-raw-temp", entry.raw_image_path)
    if not raw_bytes:
        raise RuntimeError("Could not download raw image from temp storage")

    # 2. Single Ollama call: detect garments + full metadata in one shot.
    garments = await detect_and_analyze_garments(raw_bytes)
    if not garments:
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
            await asyncio.to_thread(delete_file, "clothing-raw-temp", entry.raw_image_path)
            return

        # 4. Extract, bg-remove, classify, and persist each detected garment.
        garment_count = len(garments)
        processed_any = False

        # 4a. Extract all garments in parallel — rembg is CPU-bound in a thread so
        # multiple garments can be segmented concurrently without blocking the loop.
        extraction_results: list[bytes | BaseException] = list(
            await asyncio.gather(
                *[
                    asyncio.to_thread(
                        extract_garment, raw_bytes, g["bbox"], num_garments=garment_count
                    )
                    for g in garments
                ],
                return_exceptions=True,
            )
        )

        for idx, garment in enumerate(garments):
            is_placeholder_slot = idx == 0
            item_id = entry.clothing_item_id if is_placeholder_slot else uuid.uuid4()
            processed_path = f"{entry.user_id}/{item_id}.png"

            garment_bytes_or_exc = extraction_results[idx]
            if isinstance(garment_bytes_or_exc, BaseException):
                logger.warning("Retry %s garment %d extraction failed: %s", entry.id, idx, garment_bytes_or_exc)
                continue
            garment_bytes: bytes = garment_bytes_or_exc

            # 4b. Upload to processed bucket
            is_jpeg = garment_bytes[:2] == b'\xff\xd8'
            if is_jpeg:
                processed_path = processed_path.replace(".png", ".jpg")
                content_type = "image/jpeg"
            else:
                content_type = "image/png"
            if not await asyncio.to_thread(upload_file, settings.CLOTHING_BUCKET, processed_path, garment_bytes, content_type):
                logger.warning("Retry %s garment %d storage failed", entry.id, idx)
                continue

            # 4c. All metadata already in the garment dict from the single Ollama call.
            detected_type = garment.get("type", "other")
            anchors = _TYPE_ANCHORS.get(detected_type, _TYPE_ANCHORS["other"])
            confidence = 0.85 if detected_type != "other" else 0.50
            label = garment.get("label", "clothing")

            # 4d. Generate pose-conditioned wrinkle maps (8 poses × 128×192px PNG)
            from app.services.wrinkle_generation import generate_and_upload_wrinkle_maps
            wrinkle_paths = await asyncio.to_thread(
                generate_and_upload_wrinkle_maps, detected_type, str(entry.user_id), str(item_id)
            )

            if is_placeholder_slot:
                placeholder.name = entry.original_name or label
                placeholder.type = detected_type
                placeholder.processed_image_path = processed_path
                placeholder.detection_confidence = confidence
                placeholder.anchor_points = anchors
                placeholder.color = garment.get("color")
                placeholder.pattern = garment.get("pattern")
                placeholder.style = garment.get("style")
                placeholder.sub_type = garment.get("sub_type")
                placeholder.size_label = garment.get("size_label", "Unknown")
                placeholder.processing_status = "completed"
                placeholder.wrinkle_maps = wrinkle_paths or None
            else:
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
                    color=garment.get("color"),
                    pattern=garment.get("pattern"),
                    style=garment.get("style"),
                    sub_type=garment.get("sub_type"),
                    size_label=garment.get("size_label", "Unknown"),
                    processing_status="completed",
                    wrinkle_maps=wrinkle_paths or None,
                )
                db.add(new_item)

            # 3D mesh reconstruction is disabled (MESH_GENERATION_ENABLED=False).
            # Re-enable when the 3D wardrobe feature is built (see SNAPCHAT_TRYON_PLAN.md §F1).

            processed_any = True

        if not processed_any:
            raise RuntimeError("All garments failed during extraction/upload")

        await db.commit()

    await _mark_succeeded(entry)
    await asyncio.to_thread(delete_file, "clothing-raw-temp", entry.raw_image_path)
    logger.info(
        "Retry %s succeeded after %d attempt(s)", entry.id, entry.attempt_count
    )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _process_entry_by_id(entry_id: uuid.UUID) -> None:
    """Called directly by the ARQ process_upload_job to handle a fresh upload."""
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(UploadRetryQueue).where(UploadRetryQueue.id == entry_id)
        )
        entry = result.scalar_one_or_none()
    if entry is None:
        logger.warning("process_entry_by_id: entry %s not found", entry_id)
        return
    await _process_entry(entry)


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

            await asyncio.to_thread(delete_file, "clothing-raw-temp", row.raw_image_path)
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


