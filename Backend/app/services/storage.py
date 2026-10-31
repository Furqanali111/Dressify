import time
import logging

from app.security import supabase_admin as supabase

logger = logging.getLogger(__name__)

_TRANSIENT_KEYWORDS = ("disconnected", "connection", "timeout", "reset", "protocol")


def _is_transient(exc: Exception) -> bool:
    return any(k in str(exc).lower() for k in _TRANSIENT_KEYWORDS)


def upload_file(
    bucket_name: str,
    file_path: str,
    file_bytes: bytes,
    content_type: str = "image/jpeg",
    upsert: bool = False,
    _retries: int = 3,
) -> bool:
    for attempt in range(_retries):
        try:
            supabase.storage.from_(bucket_name).upload(
                file_path,
                file_bytes,
                file_options={"content-type": content_type, "upsert": str(upsert).lower()},
            )
            return True
        except Exception as e:
            if attempt < _retries - 1 and _is_transient(e):
                time.sleep(0.5 * (attempt + 1))
                continue
            logger.error("Failed to upload to %s/%s: %s", bucket_name, file_path, e, exc_info=True)
            return False
    return False  # unreachable but satisfies type checker


def download_file(bucket_name: str, file_path: str) -> bytes | None:
    """Download a file from Supabase storage. Returns raw bytes or None on failure."""
    try:
        return supabase.storage.from_(bucket_name).download(file_path)
    except Exception as e:
        logger.error(f"Failed to download {bucket_name}/{file_path}: {e}", exc_info=True)
        return None


def delete_file(bucket_name: str, file_path: str) -> bool:
    """Delete a single file from Supabase storage. Returns True on success."""
    try:
        supabase.storage.from_(bucket_name).remove([file_path])
        return True
    except Exception as e:
        logger.error(f"Failed to delete {bucket_name}/{file_path}: {e}", exc_info=True)
        return False


def get_signed_url(bucket_name: str, file_path: str, expires_in: int = 3600) -> str | None:
    try:
        res = supabase.storage.from_(bucket_name).create_signed_url(file_path, expires_in)
        if isinstance(res, dict) and "signedURL" in res:
            return res["signedURL"]
        return res
    except Exception as e:
        logger.error(f"Failed to get signed url for {bucket_name}/{file_path}: {e}", exc_info=True)
        return None


def file_exists(bucket_name: str, file_path: str) -> bool:
    """True if an object exists at file_path (checked via a folder listing, no download)."""
    folder, _, name = file_path.rpartition("/")
    try:
        entries = supabase.storage.from_(bucket_name).list(folder, {"search": name})
        return any(e.get("name") == name for e in entries or [])
    except Exception as e:
        logger.error("Failed to check %s/%s: %s", bucket_name, file_path, e)
        return False
