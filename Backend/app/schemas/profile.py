from pydantic import BaseModel, ConfigDict, model_validator, Field
from typing import Optional
from decimal import Decimal
from datetime import datetime
import uuid


class ProfileUpdate(BaseModel):
    height_cm:   Optional[Decimal] = None
    weight_kg:   Optional[Decimal] = None
    body_type:   Optional[str] = None
    gender:      Optional[str] = None
    avatar_kind: Optional[str] = None
    # Phase 4.1 — body measurements
    chest_cm:    Optional[Decimal] = Field(None, ge=50, le=200)
    waist_cm:    Optional[Decimal] = Field(None, ge=50, le=180)
    hip_cm:      Optional[Decimal] = Field(None, ge=50, le=200)
    shoulder_cm: Optional[Decimal] = Field(None, ge=30, le=80)


class ProfileResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    height_cm:   Optional[Decimal] = None
    weight_kg:   Optional[Decimal] = None
    body_type:   Optional[str] = None
    gender:      Optional[str] = None
    avatar_kind: Optional[str] = None
    preferences: Optional[dict] = None
    # Phase 4.1
    chest_cm:    Optional[Decimal] = None
    waist_cm:    Optional[Decimal] = None
    hip_cm:      Optional[Decimal] = None
    shoulder_cm: Optional[Decimal] = None
    fit_scale_top:    float = 1.0
    fit_scale_bottom: float = 1.0
    fit_scale_dress:  float = 1.0
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="after")
    def _compute_fit_scales(self) -> "ProfileResponse":
        from app.services.fit_scale import compute_fit_scales
        top, bottom, dress = compute_fit_scales(
            self.avatar_kind,
            float(self.chest_cm)    if self.chest_cm    is not None else None,
            float(self.waist_cm)    if self.waist_cm    is not None else None,
            float(self.hip_cm)      if self.hip_cm      is not None else None,
            float(self.shoulder_cm) if self.shoulder_cm is not None else None,
        )
        self.fit_scale_top    = top
        self.fit_scale_bottom = bottom
        self.fit_scale_dress  = dress
        return self
