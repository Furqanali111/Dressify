from pydantic import BaseModel, ConfigDict
from typing import Literal, Optional
from datetime import datetime
import uuid

InteractionAction = Literal["viewed", "tried", "saved", "dismissed", "shared"]


class StyleProfileResponse(BaseModel):
    user_id:         uuid.UUID
    liked_colors:    list[str] = []
    liked_styles:    list[str] = []
    liked_patterns:  list[str] = []
    disliked_styles: list[str] = []
    updated_at:      Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class StyleProfileUpdate(BaseModel):
    liked_colors:    Optional[list[str]] = None
    liked_styles:    Optional[list[str]] = None
    liked_patterns:  Optional[list[str]] = None
    disliked_styles: Optional[list[str]] = None


class InteractionCreate(BaseModel):
    action:            InteractionAction
    clothing_item_ids: Optional[list[uuid.UUID]] = None
    outfit_id:         Optional[uuid.UUID] = None


class InteractionResponse(BaseModel):
    id:         uuid.UUID
    user_id:    uuid.UUID
    action:     str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
