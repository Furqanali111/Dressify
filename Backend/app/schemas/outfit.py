from pydantic import BaseModel, ConfigDict, Field
from typing import List, Literal, Optional
from datetime import datetime
import uuid

AvatarKind = Literal[
    "maleSlim", "maleAthletic", "maleAverage", "maleCurvy", "malePlus",
    "femaleSlim", "femaleAthletic", "femaleAverage", "femaleCurvy", "femalePlus",
]


class OutfitItemSchema(BaseModel):
    clothing_item_id: uuid.UUID
    position: Optional[dict] = None


class OutfitCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    avatar_kind: AvatarKind
    items: List[OutfitItemSchema]


class OutfitUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    is_starred: Optional[bool] = None


class GenerateOutfitRequest(BaseModel):
    occasion: str = Field(..., min_length=1, max_length=50)
    avatar_kind: Optional[AvatarKind] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    seed_item_id: Optional[uuid.UUID] = None


class OutfitResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    avatar_kind: str
    is_starred: bool = False
    items: List[OutfitItemSchema]
    created_at: datetime
    personalized: bool = False

    model_config = ConfigDict(from_attributes=True)


class OutfitListResponse(BaseModel):
    items: List[OutfitResponse]
    next_cursor: Optional[str] = None
