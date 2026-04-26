from pydantic import BaseModel, ConfigDict
from typing import List, Optional
from datetime import datetime
import uuid

class OutfitItemSchema(BaseModel):
    clothing_item_id: uuid.UUID
    position: Optional[dict] = None

class OutfitCreate(BaseModel):
    name: str
    avatar_kind: str
    items: List[OutfitItemSchema]

class GenerateOutfitRequest(BaseModel):
    occasion: str
    avatar_kind: str = "average"
    lat: Optional[float] = None
    lon: Optional[float] = None
    seed_item_id: Optional[uuid.UUID] = None

class OutfitResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    avatar_kind: str
    items: List[OutfitItemSchema]
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
