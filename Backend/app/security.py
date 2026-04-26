import jwt
from datetime import datetime, timedelta, timezone
from app.config import settings
from supabase import create_client, Client
import logging

logger = logging.getLogger(__name__)

supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)

def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=settings.JWT_TTL_HOURS)
    to_encode = {"sub": str(user_id), "exp": int(expire.timestamp()), "iss": settings.JWT_ISSUER}
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET, algorithm="HS256")
    return encoded_jwt

def verify_access_token(token: str) -> str | None:
    try:
        payload = jwt.decode(
            token, 
            settings.JWT_SECRET, 
            algorithms=["HS256"], 
            issuer=settings.JWT_ISSUER
        )
        return payload.get("sub")
    except jwt.PyJWTError as e:
        logger.error(f"JWT Verification failed: {e}")
        return None
