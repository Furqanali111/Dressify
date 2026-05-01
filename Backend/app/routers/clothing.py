import logging
import uuid
from typing import Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from pydantic import BaseModel

from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.profile import Profile
from app.models.user import User
from app.deps import get_current_user
from app.schemas.clothing import ClothingItemResponse, ClothingItemUpdate, ClothingListResponse, FitRatingResponse
from app.services.fit_rating import compute_fit_rating
from app.services import storage
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/clothing", tags=["Clothing"])


def inject_urls(item: ClothingItem) -> ClothingItemResponse:
    resp = ClothingItemResponse.model_validate(item)
    resp.processed_url = get_signed_url("clothing-processed", item.processed_image_path) if item.processed_image_path else ""
    return resp


@router.get("", response_model=ClothingListResponse)
@limiter.limit("60/minute")
async def get_clothing(
    request: Request,
    type: Optional[str] = None,
    sort_by: Optional[str] = "newest",
    cursor: Optional[str] = None,
    limit: int = 30,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(ClothingItem).where(ClothingItem.user_id == current_user.id)
    if type:
        query = query.where(ClothingItem.type == type)

    if cursor:
        try:
            cursor_time = datetime.fromisoformat(cursor)
            if sort_by == "oldest":
                query = query.where(ClothingItem.created_at > cursor_time)
            else:
                query = query.where(ClothingItem.created_at < cursor_time)
        except ValueError:
            pass

    if sort_by == "oldest":
        query = query.order_by(ClothingItem.created_at.asc()).limit(limit + 1)
    else:
        query = query.order_by(ClothingItem.created_at.desc()).limit(limit + 1)
    
    result = await db.execute(query)
    items = result.scalars().all()

    next_cursor = None
    if len(items) > limit:
        next_cursor = items[limit - 1].created_at.isoformat()
        items = items[:limit]

    return ClothingListResponse(
        items=[inject_urls(i) for i in items],
        next_cursor=next_cursor,
    )


@router.get("/{item_id}", response_model=ClothingItemResponse)
@limiter.limit("60/minute")
async def get_clothing_item(
    request: Request,
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ClothingItem).where(
            ClothingItem.id == item_id,
            ClothingItem.user_id == current_user.id,
        )
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    return inject_urls(item)


@router.patch("/{item_id}", response_model=ClothingItemResponse)
@limiter.limit("20/minute")
async def update_clothing_item(
    request: Request,
    item_id: uuid.UUID,
    update_data: ClothingItemUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ClothingItem).where(
            ClothingItem.id == item_id,
            ClothingItem.user_id == current_user.id,
        )
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    for key, value in update_data.model_dump(exclude_unset=True).items():
        setattr(item, key, value)

    try:
        await db.commit()
        await db.refresh(item)
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error(f"DB error updating clothing item {item_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to update item")

    return inject_urls(item)


@router.get("/{item_id}/fit", response_model=FitRatingResponse)
@limiter.limit("30/minute")
async def get_clothing_fit(
    request: Request,
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    item_result = await db.execute(
        select(ClothingItem).where(
            ClothingItem.id == item_id,
            ClothingItem.user_id == current_user.id,
        )
    )
    item = item_result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    profile_result = await db.execute(
        select(Profile).where(Profile.user_id == current_user.id)
    )
    profile = profile_result.scalar_one_or_none()

    chest_cm = float(profile.chest_cm) if profile and profile.chest_cm else None
    waist_cm = float(profile.waist_cm) if profile and profile.waist_cm else None

    rating = compute_fit_rating(item.size_label, item.type, chest_cm, waist_cm)
    return FitRatingResponse(item_id=item_id, **rating)


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_clothing_item(
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ClothingItem).where(
            ClothingItem.id == item_id,
            ClothingItem.user_id == current_user.id,
        )
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    # Delete physical files from Supabase Storage before removing the DB record
    if item.processed_image_path:
        storage.delete_file("clothing-processed", item.processed_image_path)

    try:
        await db.delete(item)
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        logger.error(f"DB integrity error deleting clothing item {item_id}: {e}")
        raise HTTPException(
            status_code=409,
            detail="Cannot delete this item — it is referenced by one or more outfits",
        )
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error(f"DB error deleting clothing item {item_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to delete item")

    return None


class BatchDeleteRequest(BaseModel):
    clothing_item_ids: list[uuid.UUID]


@router.post("/batch-delete", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("10/minute")
async def batch_delete_clothing(
    request: Request,
    body: BatchDeleteRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Fetch the items first so we can wipe their files from Supabase Storage
    rows_result = await db.execute(
        select(ClothingItem.processed_image_path).where(
            ClothingItem.id.in_(body.clothing_item_ids),
            ClothingItem.user_id == current_user.id,
        )
    )
    paths = [row.processed_image_path for row in rows_result.all() if row.processed_image_path]
    for path in paths:
        storage.delete_file("clothing-processed", path)

    try:
        await db.execute(
            delete(ClothingItem).where(
                ClothingItem.id.in_(body.clothing_item_ids),
                ClothingItem.user_id == current_user.id
            )
        )
        await db.commit()
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error("Failed to batch delete clothing items: %s", e)
        raise HTTPException(
            status_code=400,
            detail="Could not delete items. They may be part of an outfit."
        )

    return None
