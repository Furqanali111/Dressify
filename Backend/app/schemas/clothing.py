from pydantic import BaseModel, ConfigDict, Field
from typing import Literal, Optional
from datetime import datetime
import uuid


_VALID_SIZE_LABELS = {"XS", "S", "M", "L", "XL", "XXL", "One Size", "Unknown"}


class WrinkleMapEntry(BaseModel):
    pose: str
    url: str


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
    size_label: Optional[str] = None
    fit_notes: Optional[str] = None
    processing_status: str
    glb_mesh_path: Optional[str] = None
    mesh_status: Optional[str] = None
    wrinkle_maps: Optional[list[WrinkleMapEntry]] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ClothingItemUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    type: Optional[str] = Field(None, max_length=50)
    color: Optional[str] = Field(None, max_length=50)
    pattern: Optional[str] = Field(None, max_length=50)
    style: Optional[str] = Field(None, max_length=50)
    sub_type: Optional[str] = Field(None, max_length=100)
    size_label: Optional[str] = Field(None, max_length=10)
    fit_notes: Optional[str] = Field(None, max_length=500)


class ClothingListResponse(BaseModel):
    items: list[ClothingItemResponse]
    next_cursor: Optional[str] = None


class FitRatingResponse(BaseModel):
    item_id: uuid.UUID
    fit_rating: Literal["perfect", "may_be_snug", "runs_large", "unknown"]
    confidence: float
