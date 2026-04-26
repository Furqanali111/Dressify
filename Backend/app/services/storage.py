from app.security import supabase
from app.config import settings
import logging

logger = logging.getLogger(__name__)

def upload_file(bucket_name: str, file_path: str, file_bytes: bytes, content_type: str = "image/jpeg") -> bool:
    try:
        supabase.storage.from_(bucket_name).upload(
            file_path, 
            file_bytes, 
            file_options={"content-type": content_type}
        )
        return True
    except Exception as e:
        logger.error(f"Failed to upload to {bucket_name}/{file_path}: {e}")
        return False

def get_signed_url(bucket_name: str, file_path: str, expires_in: int = 3600) -> str | None:
    try:
        # Supabase Python client returns a dict with 'signedURL' or a string depending on version
        res = supabase.storage.from_(bucket_name).create_signed_url(file_path, expires_in)
        if isinstance(res, dict) and "signedURL" in res:
            return res["signedURL"]
        return res
    except Exception as e:
        logger.error(f"Failed to get signed url for {bucket_name}/{file_path}: {e}")
        return None
