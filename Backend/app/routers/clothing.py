import asyncio
import logging
import uuid
from typing import Optional
from datetime import datetime  # used in cursor parsing

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete as sql_delete
from pydantic import BaseModel

from app.config import settings
from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.profile import Profile
from app.models.upload_retry_queue import UploadRetryQueue
from app.models.user import User
from app.deps import get_current_user
from app.schemas.clothing import ClothingItemResponse, ClothingItemUpdate, ClothingListResponse, FitRatingResponse
from app.services.fit_rating import compute_fit_rating
from app.services import storage
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/clothing", tags=["Clothing"])


async def _inject_urls(item) -> ClothingItemResponse:
    from app.schemas.clothing import WrinkleMapEntry

    resp = ClothingItemResponse.model_validate(item)
    raw_maps: dict | None = getattr(item, "wrinkle_maps", None)
    poses: list[tuple[str, str]] = list(raw_maps.items()) if raw_maps else []

    async def _sign(bucket: str, path: str) -> str | None:
        return await asyncio.to_thread(storage.get_signed_url, bucket, path)

    async def _noop() -> None:
        return None

    # Sign the processed image, GLB, and all wrinkle maps in one parallel batch
    # instead of sequential awaits (30 items × 8 poses = 240 round-trips otherwise).
    results: list = await asyncio.gather(
        _sign(settings.CLOTHING_BUCKET, item.processed_image_path) if item.processed_image_path else _noop(),
        _sign("clothing-meshes", item.glb_mesh_path) if item.glb_mesh_path else _noop(),
        *[_sign(settings.CLOTHING_BUCKET, path) for _, path in poses],
        return_exceptions=True,
    )

    processed_url = results[0]
    resp.processed_url = (processed_url if isinstance(processed_url, str) else None) or ""

    glb_url = results[1]
    if isinstance(glb_url, str) and glb_url:
        resp.glb_mesh_path = glb_url

    if poses:
        signed = [
            WrinkleMapEntry(pose=pose, url=url)
            for (pose, _), url in zip(poses, results[2:])
            if isinstance(url, str) and url
        ]
        resp.wrinkle_maps = signed or None

    return resp


@router.get("", response_model=ClothingListResponse)
@limiter.limit("60/minute")
async def get_clothing(
    request: Request,
    type: Optional[str] = None,
    sort_by: Optional[str] = "newest",
    cursor: Optional[str] = None,
    limit: int = Query(default=30, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Optimize: Select only columns needed for grid view
    query = select(
        ClothingItem.id,
        ClothingItem.name,
        ClothingItem.type,
        ClothingItem.processed_image_path,
        ClothingItem.processing_status,
        ClothingItem.glb_mesh_path,
        ClothingItem.mesh_status,
        ClothingItem.wrinkle_maps,
        ClothingItem.size_label,
        ClothingItem.created_at,
    ).where(
        ClothingItem.user_id == current_user.id,
    )

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
            raise HTTPException(status_code=400, detail="Invalid cursor format")

    if sort_by == "oldest":
        query = query.order_by(ClothingItem.created_at.asc()).limit(limit + 1)
    else:
        query = query.order_by(ClothingItem.created_at.desc()).limit(limit + 1)
    
    result = await db.execute(query)
    items = result.all()

    next_cursor = None
    if len(items) > limit:
        next_cursor = items[limit - 1].created_at.isoformat()
        items = items[:limit]

    signed = await asyncio.gather(*[_inject_urls(i) for i in items])
    return ClothingListResponse(items=list(signed), next_cursor=next_cursor)


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

    return await _inject_urls(item)


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

    return await _inject_urls(item)


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


_RAW_BUCKET = "clothing-raw-temp"


async def _purge_retry_entries(item_ids: list[uuid.UUID], db: AsyncSession) -> None:
    """Delete non-succeeded retry-queue rows for the given items and their raw images."""
    rows = (await db.execute(
        select(UploadRetryQueue.id, UploadRetryQueue.raw_image_path)
        .where(
            UploadRetryQueue.clothing_item_id.in_(item_ids),
            UploadRetryQueue.status != "succeeded",
        )
    )).all()

    if not rows:
        return

    for row in rows:
        await asyncio.to_thread(storage.delete_file, _RAW_BUCKET, row.raw_image_path)

    await db.execute(
        sql_delete(UploadRetryQueue).where(
            UploadRetryQueue.id.in_([r.id for r in rows])
        )
    )
    try:
        await db.commit()
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error("Failed to purge retry queue entries: %s", e)


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

    # Clean up retry-queue entry before deleting the item.
    await _purge_retry_entries([item_id], db)

    # Commit DB deletion first. If storage cleanup fails afterwards the file is
    # merely orphaned (wasted bytes), which is far less damaging than the reverse
    # order: storage deleted + DB commit failure → broken record pointing to a
    # missing file, which is a visible UX bug for the user.
    try:
        await db.delete(item)
        await db.commit()
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error(f"DB error deleting clothing item {item_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to delete item")

    # Delete all storage files in parallel — processed image, GLB, wrinkle maps.
    raw_maps: dict | None = getattr(item, "wrinkle_maps", None)
    cleanup = []
    if item.processed_image_path:
        cleanup.append(asyncio.to_thread(storage.delete_file, settings.CLOTHING_BUCKET, item.processed_image_path))
    if item.glb_mesh_path:
        cleanup.append(asyncio.to_thread(storage.delete_file, "clothing-meshes", item.glb_mesh_path))
    if raw_maps:
        cleanup.extend(
            asyncio.to_thread(storage.delete_file, settings.CLOTHING_BUCKET, path)
            for path in raw_maps.values()
        )
    if cleanup:
        await asyncio.gather(*cleanup, return_exceptions=True)

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
    # Fetch items to get all storage paths before deleting.
    rows = (await db.execute(
        select(
            ClothingItem.id,
            ClothingItem.processed_image_path,
            ClothingItem.glb_mesh_path,
            ClothingItem.wrinkle_maps,
        )
        .where(
            ClothingItem.id.in_(body.clothing_item_ids),
            ClothingItem.user_id == current_user.id,
        )
    )).all()

    if not rows:
        return None

    ids = [r.id for r in rows]

    # Clean up retry-queue entries and raw images.
    await _purge_retry_entries(ids, db)

    # Commit DB deletion before storage cleanup for the same reason as single
    # delete: a missing file is recoverable; a broken DB record is not.
    try:
        await db.execute(sql_delete(ClothingItem).where(ClothingItem.id.in_(ids)))
        await db.commit()
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error("Failed to batch delete clothing items: %s", e)
        raise HTTPException(status_code=500, detail="Could not delete items.")

    cleanup = []
    for row in rows:
        if row.processed_image_path:
            cleanup.append(asyncio.to_thread(storage.delete_file, settings.CLOTHING_BUCKET, row.processed_image_path))
        if row.glb_mesh_path:
            cleanup.append(asyncio.to_thread(storage.delete_file, "clothing-meshes", row.glb_mesh_path))
        if row.wrinkle_maps:
            cleanup.extend(
                asyncio.to_thread(storage.delete_file, settings.CLOTHING_BUCKET, path)
                for path in row.wrinkle_maps.values()
            )
    if cleanup:
        await asyncio.gather(*cleanup, return_exceptions=True)

    return None
