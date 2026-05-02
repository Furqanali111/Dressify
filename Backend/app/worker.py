"""
ARQ background worker.

Handles jobs that must survive web-process restarts — primarily AI metadata
extraction, which is too slow to run inline and too important to fire-and-forget.

Run alongside the API with:
    arq app.worker.WorkerSettings
"""
import logging
import uuid

from arq.connections import RedisSettings

from app.config import settings
from app.services.storage import download_file

logger = logging.getLogger(__name__)


async def extract_metadata_job(ctx: dict, item_id_str: str, bucket: str, path: str) -> None:
    """Download the processed garment image from storage and run AI metadata extraction.

    Args are plain strings so they serialise cleanly through Redis (no large blobs).
    The image is already in Supabase storage at bucket/path by the time this runs.
    """
    from app.services.ai_vision import extract_clothing_metadata

    image_bytes = download_file(bucket, path)
    if not image_bytes:
        logger.error(
            "extract_metadata_job: cannot download %s/%s — skipping metadata for item %s",
            bucket, path, item_id_str,
        )
        return

    await extract_clothing_metadata(uuid.UUID(item_id_str), image_bytes)


class WorkerSettings:
    functions = [extract_metadata_job]
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    max_jobs = 5            # concurrent jobs per worker process
    job_timeout = 300       # seconds before a job is considered hung
    keep_result = 3600      # keep job result in Redis for 1 h (useful for debugging)
