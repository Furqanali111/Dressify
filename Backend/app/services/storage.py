from app.security import supabase
from app.config import settings
import logging

logger = logging.getLogger(__name__)


def upload_file(bucket_name: str, file_path: str, file_bytes: bytes, content_type: str = "image/jpeg") -> bool:
    try:
        supabase.storage.from_(bucket_name).upload(
            file_path,
            file_bytes,
            file_options={"content-type": content_type},
        )
        return True
    except Exception as e:
        logger.error(f"Failed to upload to {bucket_name}/{file_path}: {e}")
        return False


def download_file(bucket_name: str, file_path: str) -> bytes | None:
    """Download a file from Supabase storage. Returns raw bytes or None on failure."""
    try:
        return supabase.storage.from_(bucket_name).download(file_path)
    except Exception as e:
        logger.error(f"Failed to download {bucket_name}/{file_path}: {e}")
        return None


def delete_file(bucket_name: str, file_path: str) -> bool:
    """Delete a single file from Supabase storage. Returns True on success."""
    try:
        supabase.storage.from_(bucket_name).remove([file_path])
        return True
    except Exception as e:
        logger.error(f"Failed to delete {bucket_name}/{file_path}: {e}")
        return False


def get_signed_url(bucket_name: str, file_path: str, expires_in: int = 3600) -> str | None:
    try:
        res = supabase.storage.from_(bucket_name).create_signed_url(file_path, expires_in)
        if isinstance(res, dict) and "signedURL" in res:
            return res["signedURL"]
        return res
    except Exception as e:
        logger.error(f"Failed to get signed url for {bucket_name}/{file_path}: {e}")
        return None
