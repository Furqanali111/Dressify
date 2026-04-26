from pydantic import BaseModel, ConfigDict, Field
from typing import Optional
from datetime import datetime
import uuid


class ClothingItemResponse(BaseModel):
    id: uuid.UUID
    name: str
    type: str
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


class ClothingItemUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    type: Optional[str] = Field(None, max_length=50)
    color: Optional[str] = Field(None, max_length=50)
    pattern: Optional[str] = Field(None, max_length=50)
    style: Optional[str] = Field(None, max_length=50)
    sub_type: Optional[str] = Field(None, max_length=100)


class ClothingListResponse(BaseModel):
    items: list[ClothingItemResponse]
    next_cursor: Optional[str] = None
