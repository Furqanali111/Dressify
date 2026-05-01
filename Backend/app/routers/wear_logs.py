import uuid
import logging

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.wear_log import WearLog
from app.models.user import User
from app.deps import get_current_user
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/wear-logs", tags=["Wear Logs"])


class WearLogCreate(BaseModel):
    outfit_id:         Optional[uuid.UUID] = None
    clothing_item_ids: Optional[list[uuid.UUID]] = None


class WearLogResponse(BaseModel):
    id:                uuid.UUID
    user_id:           uuid.UUID
    outfit_id:         Optional[uuid.UUID] = None
    clothing_item_ids: Optional[list[str]] = None
    logged_at:         datetime

    class Config:
        from_attributes = True


class WearLogListResponse(BaseModel):
    items:       list[WearLogResponse]
    next_cursor: Optional[str] = None


@router.post("", response_model=WearLogResponse, status_code=201)
@limiter.limit("60/minute")
async def log_wear(
    request: Request,
    body: WearLogCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Filter clothing_item_ids to only those owned by the current user
    safe_item_ids = None
    if body.clothing_item_ids:
        owned = await db.execute(
            select(ClothingItem.id).where(
                ClothingItem.id.in_(body.clothing_item_ids),
                ClothingItem.user_id == current_user.id,
            )
        )
        safe_item_ids = [str(row) for row in owned.scalars().all()]

    log = WearLog(
        id=uuid.uuid4(),
        user_id=current_user.id,
        outfit_id=body.outfit_id,
        clothing_item_ids=safe_item_ids,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log


@router.get("", response_model=WearLogListResponse)
@limiter.limit("60/minute")
async def get_wear_logs(
    request: Request,
    cursor: Optional[str] = None,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return paginated wear logs for the current user, newest first.

    Use the returned ``next_cursor`` value as the ``cursor`` query parameter
    in the next request to load the following page.
    """
    query = (
        select(WearLog)
        .where(WearLog.user_id == current_user.id)
        .order_by(WearLog.logged_at.desc())
    )

    if cursor:
        try:
            cursor_time = datetime.fromisoformat(cursor)
            query = query.where(WearLog.logged_at < cursor_time)
        except ValueError:
            pass  # Ignore malformed cursor — just return from the top

    query = query.limit(limit + 1)
    result = await db.execute(query)
    logs = result.scalars().all()

    next_cursor: Optional[str] = None
    if len(logs) > limit:
        next_cursor = logs[limit - 1].logged_at.isoformat()
        logs = logs[:limit]

    return WearLogListResponse(items=list(logs), next_cursor=next_cursor)
