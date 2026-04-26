from pydantic import BaseModel, ConfigDict
from typing import Optional
from decimal import Decimal
from datetime import datetime
import uuid

class ProfileUpdate(BaseModel):
    height_cm: Optional[Decimal] = None
    weight_kg: Optional[Decimal] = None
    body_type: Optional[str] = None
    avatar_kind: Optional[str] = None

class ProfileResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    height_cm: Optional[Decimal] = None
    weight_kg: Optional[Decimal] = None
    body_type: Optional[str] = None
    avatar_kind: Optional[str] = None
    preferences: Optional[dict] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
