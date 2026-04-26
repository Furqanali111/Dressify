import logging
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.user import User
from app.deps import get_current_user
from app.schemas.clothing import ClothingItemResponse, ClothingItemUpdate, ClothingListResponse
from app.services.storage import get_signed_url
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/clothing", tags=["Clothing"])


def inject_urls(item: ClothingItem) -> ClothingItemResponse:
    resp = ClothingItemResponse.model_validate(item)
    resp.processed_url = get_signed_url("clothing-processed", item.processed_image_path) if item.processed_image_path else ""
    return resp


@router.get("", response_model=ClothingListResponse)
async def get_clothing(
    type: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(ClothingItem).where(ClothingItem.user_id == current_user.id)
    if type:
        query = query.where(ClothingItem.type == type)

    result = await db.execute(query)
    items = result.scalars().all()

    return ClothingListResponse(
        items=[inject_urls(i) for i in items],
        next_cursor=None,
    )


@router.get("/{item_id}", response_model=ClothingItemResponse)
async def get_clothing_item(
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
    except Exception as e:
        await db.rollback()
        logger.error(f"DB error updating clothing item {item_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to update item")

    return inject_urls(item)


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
    except Exception as e:
        await db.rollback()
        logger.error(f"DB error deleting clothing item {item_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to delete item")

    return None
