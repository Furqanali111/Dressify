from pydantic import BaseModel, ConfigDict
from typing import List, Literal, Optional
from datetime import datetime
import uuid

class Suggestion(BaseModel):
    category: Literal['color', 'balance', 'occasion', 'accessories']
    title: str
    detail: str

class FeedbackRequest(BaseModel):
    outfit_id: Optional[uuid.UUID] = None
    clothing_item_ids: Optional[List[uuid.UUID]] = None
    occasion: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None

class AiFeedbackResponse(BaseModel):
    id: Optional[uuid.UUID] = None
    outfit_id: Optional[uuid.UUID] = None
    score: float
    verdict: str
    suggestions: List[Suggestion]
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
