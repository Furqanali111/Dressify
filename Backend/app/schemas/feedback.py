from pydantic import BaseModel, ConfigDict
from typing import List, Literal, Optional
from datetime import datetime
import uuid

class Suggestion(BaseModel):
    category: Literal['color', 'balance', 'occasion', 'trend']
    title: str
    detail: str

class FeedbackRequest(BaseModel):
    outfit_id: uuid.UUID
    occasion: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None

class AiFeedbackResponse(BaseModel):
    id: uuid.UUID
    outfit_id: uuid.UUID
    score: float
    verdict: str
    suggestions: List[Suggestion]
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
