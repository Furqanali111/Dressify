import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from gotrue.errors import AuthApiError
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db import get_db
from app.schemas.auth import GoogleAuthRequest, AuthResponse, UserResponse
from app.schemas.profile import ProfileResponse
from app.models.user import User
from app.models.profile import Profile
from app.security import supabase, create_access_token
from app.deps import get_current_user
from app.config import settings
from app.core.limiter import limiter
from app.routers.users import user_to_response

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Auth"])


@router.post("/auth/google", response_model=AuthResponse)
@limiter.limit("10/minute")
async def google_auth(request: Request, body: GoogleAuthRequest, db: AsyncSession = Depends(get_db)):
    user_id: uuid.UUID
    email: str | None
    display_name: str | None
    avatar_url: str | None

    if settings.bypass_auth_enabled and body.id_token == settings.BYPASS_AUTH_TOKEN:
        user_id = uuid.UUID("00000000-0000-0000-0000-000000000000")
        email = "bypass@dressify.local"
        display_name = "Furqan (Bypass)"
        avatar_url = ""
    else:
        try:
            auth_response = supabase.auth.sign_in_with_id_token({
                "provider": "google",
                "token": body.id_token,
            })
        except AuthApiError as e:
            logger.warning(f"Supabase auth rejected token: {e}")
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired Google token")
        except Exception as e:
            logger.error(f"Supabase auth call failed: {e}", exc_info=True)
            raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Authentication service unavailable")

        sb_user = auth_response.user
        if not sb_user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Supabase authentication failed")

        user_id = uuid.UUID(sb_user.id)
        email = sb_user.email
        meta = sb_user.user_metadata or {}
        display_name = meta.get("full_name") or meta.get("name")
        avatar_url = meta.get("avatar_url") or meta.get("picture")

    # Upsert user
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        user = User(id=user_id, email=email, display_name=display_name, avatar_url=avatar_url)
        db.add(user)
    else:
        user.display_name = display_name
        user.avatar_url = avatar_url

    try:
        await db.commit()
        await db.refresh(user)
    except IntegrityError as e:
        await db.rollback()
        logger.error(f"DB integrity error upserting user {user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to persist user")
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error(f"DB error upserting user {user_id}: {e}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error")

    profile_result = await db.execute(select(Profile).where(Profile.user_id == user_id))
    profile = profile_result.scalar_one_or_none()
    has_profile = profile is not None

    jwt_token = create_access_token(str(user.id))
    return AuthResponse(
        jwt=jwt_token,
        user=user_to_response(user),
        has_profile=has_profile,
    )


@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    profile_result = await db.execute(select(Profile).where(Profile.user_id == current_user.id))
    profile = profile_result.scalar_one_or_none()

    return {
        "user": user_to_response(current_user),
        "profile": ProfileResponse.model_validate(profile) if profile else None,
        "avatar_kind": profile.avatar_kind if profile else None,
    }
