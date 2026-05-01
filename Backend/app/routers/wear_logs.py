import uuid
import logging

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.models.wear_log import WearLog
from app.models.user import User
from app.deps import get_current_user
from app.core.limiter import limiter
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/wear-logs", tags=["Wear Logs"])


class WearLogCreate(BaseModel):
    outfit_id:         Optional[uuid.UUID] = None
    clothing_item_ids: Optional[list[uuid.UUID]] = None


class WearLogResponse(BaseModel):
    id:        uuid.UUID
    user_id:   uuid.UUID
    outfit_id: Optional[uuid.UUID] = None
    logged_at: datetime

    class Config:
        from_attributes = True


@router.post("", response_model=WearLogResponse, status_code=201)
@limiter.limit("60/minute")
async def log_wear(
    request: Request,
    body: WearLogCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    log = WearLog(
        id=uuid.uuid4(),
        user_id=current_user.id,
        outfit_id=body.outfit_id,
        clothing_item_ids=[str(i) for i in body.clothing_item_ids] if body.clothing_item_ids else None,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log
