"""
ARQ background worker.

Handles jobs that must survive web-process restarts — primarily AI metadata
extraction, which is too slow to run inline and too important to fire-and-forget.

Run alongside the API with:
    arq app.worker.WorkerSettings
"""
import asyncio
import logging
import sys
import uuid

# psycopg async (and SQLAlchemy async) require SelectorEventLoop on Windows.
# The ARQ worker process defaults to ProactorEventLoop; override it here before
# any engine or connection object is created.
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from arq.connections import RedisSettings

from app.config import settings
from app.services.storage import download_file

logger = logging.getLogger(__name__)


async def extract_metadata_job(ctx: dict, item_id_str: str, bucket: str, path: str) -> None:
    """Download the processed garment image from storage and run AI metadata extraction."""
    from app.services.ai_vision import extract_clothing_metadata

    image_bytes = download_file(bucket, path)
    if not image_bytes:
        logger.error(
            "extract_metadata_job: cannot download %s/%s — skipping metadata for item %s",
            bucket, path, item_id_str,
        )
        return

    await extract_clothing_metadata(uuid.UUID(item_id_str), image_bytes)


async def process_upload_job(ctx: dict, entry_id_str: str) -> None:
    """Full upload pipeline: detect garments, extract, store, update ClothingItem.

    Enqueued immediately by the upload endpoint so the user never waits for Ollama.
    Falls back to the retry worker (5-min poll) if this job fails.
    """
    from app.services.retry_worker import _process_entry_by_id
    await _process_entry_by_id(uuid.UUID(entry_id_str))


async def _worker_startup(ctx: dict) -> None:
    """Initialize the ARQ pool in the worker process so jobs can re-enqueue tasks."""
    from app.services.retry_worker import init_arq_pool
    await init_arq_pool()


async def _worker_shutdown(ctx: dict) -> None:
    from app.services.retry_worker import close_arq_pool
    await close_arq_pool()


class WorkerSettings:
    functions = [extract_metadata_job, process_upload_job]
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    on_startup = _worker_startup
    on_shutdown = _worker_shutdown
    max_jobs = 5
    job_timeout = 900   # 2 Ollama calls in process_upload_job ≈ 8 min; 15 min is safe
    keep_result = 3600
