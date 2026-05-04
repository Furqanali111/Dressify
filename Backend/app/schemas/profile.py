from pydantic import BaseModel, ConfigDict, model_validator, Field
from typing import Optional
from datetime import datetime
import uuid


class ProfileUpdate(BaseModel):
    height_cm:   Optional[float] = None
    weight_kg:   Optional[float] = None
    body_type:   Optional[str] = None
    gender:      Optional[str] = None
    avatar_kind: Optional[str] = None
    # Phase 4.1 — body measurements
    chest_cm:    Optional[float] = Field(None, ge=50, le=200)
    waist_cm:    Optional[float] = Field(None, ge=50, le=180)
    hip_cm:      Optional[float] = Field(None, ge=50, le=200)
    shoulder_cm: Optional[float] = Field(None, ge=30, le=80)


class ProfileResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    height_cm:   Optional[float] = None
    weight_kg:   Optional[float] = None
    body_type:   Optional[str] = None
    gender:      Optional[str] = None
    avatar_kind: Optional[str] = None
    preferences: Optional[dict] = None
    # Phase 4.1
    chest_cm:    Optional[float] = None
    waist_cm:    Optional[float] = None
    hip_cm:      Optional[float] = None
    shoulder_cm: Optional[float] = None
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
            self.chest_cm,
            self.waist_cm,
            self.hip_cm,
            self.shoulder_cm,
        )
        self.fit_scale_top    = top
        self.fit_scale_bottom = bottom
        self.fit_scale_dress  = dress
        return self
