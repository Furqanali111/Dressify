from pydantic import BaseModel, ConfigDict, Field
from typing import List, Literal, Optional
from datetime import datetime
import uuid

AvatarKind = Literal[
    "maleSlim", "maleAthletic", "maleAverage", "maleCurvy", "malePlus",
    "femaleSlim", "femaleAthletic", "femaleAverage", "femaleCurvy", "femalePlus",
]


class ItemPosition(BaseModel):
    x: float = Field(..., ge=0.0, le=1.0)
    y: float = Field(..., ge=0.0, le=1.0)
    scale: Optional[float] = Field(None, gt=0.0, le=10.0)


class OutfitItemSchema(BaseModel):
    clothing_item_id: uuid.UUID
    position: Optional[ItemPosition] = None


class OutfitCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    avatar_kind: AvatarKind
    items: List[OutfitItemSchema] = Field(..., min_length=1, max_length=20)


class OutfitUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    is_starred: Optional[bool] = None


class GenerateOutfitRequest(BaseModel):
    occasion: str = Field(..., min_length=1, max_length=50)
    avatar_kind: Optional[AvatarKind] = None
    lat: Optional[float] = Field(None, ge=-90.0, le=90.0)
    lon: Optional[float] = Field(None, ge=-180.0, le=180.0)
    seed_item_id: Optional[uuid.UUID] = None


class OutfitResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    avatar_kind: AvatarKind
    is_starred: bool = False
    items: List[OutfitItemSchema]
    created_at: datetime
    personalized: bool = False

    model_config = ConfigDict(from_attributes=True)


class OutfitListResponse(BaseModel):
    items: List[OutfitResponse]
    next_cursor: Optional[str] = None
