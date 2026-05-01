from pydantic import BaseModel, ConfigDict, field_validator
from typing import Literal, Optional
from datetime import datetime
import uuid

InteractionAction = Literal["viewed", "tried", "saved", "dismissed", "shared"]


class StyleProfileResponse(BaseModel):
    user_id:         uuid.UUID
    liked_colors:    list[str] = []
    liked_styles:    list[str] = []
    liked_patterns:  list[str] = []
    disliked_styles: list[str] = []
    updated_at:      Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class StyleProfileUpdate(BaseModel):
    liked_colors:    Optional[list[str]] = None
    liked_styles:    Optional[list[str]] = None
    liked_patterns:  Optional[list[str]] = None
    disliked_styles: Optional[list[str]] = None

    @field_validator("liked_colors", "liked_styles", "liked_patterns", "disliked_styles", mode="before")
    @classmethod
    def _validate_str_list(cls, v: object) -> object:
        if v is None:
            return v
        if not isinstance(v, list):
            raise ValueError("Must be a list of strings")
        cleaned = []
        for item in v:
            if not isinstance(item, str):
                raise ValueError("Each item must be a string")
            stripped = item.strip()
            if len(stripped) > 64:
                raise ValueError("Each item must be 64 characters or fewer")
            if stripped:
                cleaned.append(stripped)
        return cleaned


class InteractionCreate(BaseModel):
    action:            InteractionAction
    clothing_item_ids: Optional[list[uuid.UUID]] = None
    outfit_id:         Optional[uuid.UUID] = None


class InteractionResponse(BaseModel):
    id:         uuid.UUID
    user_id:    uuid.UUID
    action:     str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
