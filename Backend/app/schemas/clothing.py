from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime
import uuid

class ClothingItemResponse(BaseModel):
    id: uuid.UUID
    name: str
    type: str
    raw_url: str = ""
    processed_url: str = ""
    anchor_points: Optional[dict] = None
    detection_confidence: Optional[float] = None
    color: Optional[str] = None
    pattern: Optional[str] = None
    style: Optional[str] = None
    sub_type: Optional[str] = None
    processing_status: str
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
    
class ClothingListResponse(BaseModel):
    items: list[ClothingItemResponse]
    next_cursor: Optional[str] = None
