import asyncio
import logging
import uuid

from fastapi import APIRouter, Depends, Request, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.config import settings
from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.style_preference import UserStylePreference, OutfitInteraction
from app.models.user import User
from app.deps import get_current_user
from app.services import storage
from app.schemas.style_preference import (
    StyleProfileResponse,
    StyleProfileUpdate,
    InteractionCreate,
    InteractionResponse,
)
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Users"])


def _pref_to_response(pref: UserStylePreference) -> StyleProfileResponse:
    return StyleProfileResponse(
        user_id=pref.user_id,
        liked_colors=pref.liked_colors or [],
        liked_styles=pref.liked_styles or [],
        liked_patterns=pref.liked_patterns or [],
        disliked_styles=pref.disliked_styles or [],
        updated_at=pref.updated_at,
    )


@router.get("/users/me/style-profile", response_model=StyleProfileResponse)
@limiter.limit("60/minute")
async def get_style_profile(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(UserStylePreference).where(UserStylePreference.user_id == current_user.id)
    )
    pref = result.scalar_one_or_none()
    if pref is None:
        pref = UserStylePreference(user_id=current_user.id)
        db.add(pref)
        await db.commit()
        await db.refresh(pref)
    return _pref_to_response(pref)


@router.patch("/users/me/style-profile", response_model=StyleProfileResponse)
@limiter.limit("20/minute")
async def update_style_profile(
    request: Request,
    body: StyleProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(UserStylePreference).where(UserStylePreference.user_id == current_user.id)
    )
    pref = result.scalar_one_or_none()
    if pref is None:
        pref = UserStylePreference(user_id=current_user.id)
        db.add(pref)

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(pref, field, value)

    await db.commit()
    await db.refresh(pref)
    return _pref_to_response(pref)


@router.post("/interactions", response_model=InteractionResponse, status_code=201)
@limiter.limit("120/minute")
async def log_interaction(
    request: Request,
    body: InteractionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    interaction = OutfitInteraction(
        id=uuid.uuid4(),
        user_id=current_user.id,
        action=body.action,
        clothing_item_ids=[str(i) for i in body.clothing_item_ids] if body.clothing_item_ids else None,
        outfit_id=body.outfit_id,
    )
    db.add(interaction)
    await db.commit()
    await db.refresh(interaction)
    return interaction


@router.delete("/users/me", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("5/minute")
async def delete_account(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Wipe all clothing images from Supabase Storage BEFORE deleting the DB records
    # This is required for GDPR/CCPA compliance — no orphaned user data in storage.
    image_rows = (await db.execute(
        select(ClothingItem.processed_image_path)
        .where(
            ClothingItem.user_id == current_user.id,
            ClothingItem.processed_image_path.isnot(None),
        )
    )).all()
    for (path,) in image_rows:
        await asyncio.to_thread(storage.delete_file, settings.CLOTHING_BUCKET, path)

    try:
        db.delete(current_user)
        await db.commit()
    except Exception as e:
        await db.rollback()
        logger.error("Failed to delete user account: %s", e)
        raise HTTPException(status_code=500, detail="Could not delete account")

    return None
