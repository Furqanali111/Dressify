from fastapi import APIRouter, Depends, HTTPException, status
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
import uuid
import logging

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Auth"])

@router.post("/auth/google", response_model=AuthResponse)
async def google_auth(request: GoogleAuthRequest, db: AsyncSession = Depends(get_db)):
    try:
        if settings.BYPASS_AUTH_FURQAN_54321 and request.id_token == "BYPASS_AUTH_FURQAN_54321":
            # Bypass auth flow
            user_id = uuid.UUID("00000000-0000-0000-0000-000000000000")
            email = "bypass@dressify.local"
            display_name = "Furqan (Bypass)"
            avatar_url = ""
        else:
            # Verify with Supabase
            auth_response = supabase.auth.sign_in_with_id_token({
                "provider": "google",
                "id_token": request.id_token
            })
            
            sb_user = auth_response.user
            if not sb_user:
                raise HTTPException(status_code=400, detail="Supabase authentication failed")

            user_id = uuid.UUID(sb_user.id)
            email = sb_user.email
            display_name = sb_user.user_metadata.get("full_name") or sb_user.user_metadata.get("name")
            avatar_url = sb_user.user_metadata.get("avatar_url") or sb_user.user_metadata.get("picture")

        # Upsert user in our database
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        
        if not user:
            user = User(
                id=user_id,
                email=email,
                display_name=display_name,
                avatar_url=avatar_url
            )
            db.add(user)
        else:
            user.display_name = display_name
            user.avatar_url = avatar_url
            
        await db.commit()
        await db.refresh(user)
        
        # Check if profile exists
        profile_result = await db.execute(select(Profile).where(Profile.user_id == user_id))
        profile = profile_result.scalar_one_or_none()
        has_profile = profile is not None
        
        # Mint backend JWT
        jwt_token = create_access_token(str(user.id))
        
        return AuthResponse(
            jwt=jwt_token,
            user=UserResponse.model_validate(user),
            has_profile=has_profile
        )
        
    except Exception as e:
        logger.error(f"Google auth error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )

@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    profile_result = await db.execute(select(Profile).where(Profile.user_id == current_user.id))
    profile = profile_result.scalar_one_or_none()
    
    profile_data = ProfileResponse.model_validate(profile) if profile else None
    
    return {
        "user": UserResponse.model_validate(current_user),
        "profile": profile_data,
        "avatar_kind": profile.avatar_kind if profile else None
    }
