import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db import get_db
from app.schemas.profile import ProfileUpdate, ProfileResponse
from app.models.profile import Profile
from app.models.user import User
from app.deps import get_current_user
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/profile", tags=["Profile"])


@router.get("", response_model=ProfileResponse)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Profile).where(Profile.user_id == current_user.id))
    profile = result.scalar_one_or_none()

    if not profile:
        profile = Profile(user_id=current_user.id)
        db.add(profile)
        try:
            await db.commit()
            await db.refresh(profile)
        except Exception as e:
            await db.rollback()
            logger.error(f"Failed to auto-create profile for user {current_user.id}: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail="Failed to initialise profile")

    return profile


@router.patch("", response_model=ProfileResponse)
@limiter.limit("10/minute")
async def update_profile(
    request: Request,
    update_data: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Profile).where(Profile.user_id == current_user.id))
    profile = result.scalar_one_or_none()

    if not profile:
        profile = Profile(user_id=current_user.id)
        db.add(profile)

    for key, value in update_data.model_dump(exclude_unset=True).items():
        setattr(profile, key, value)

    try:
        await db.commit()
        await db.refresh(profile)
    except IntegrityError as e:
        await db.rollback()
        logger.error(f"DB integrity error updating profile for user {current_user.id}: {e}")
        raise HTTPException(status_code=409, detail="Profile update conflict — please retry")
    except Exception as e:
        await db.rollback()
        logger.error(f"DB error updating profile for user {current_user.id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to save profile")

    return profile
