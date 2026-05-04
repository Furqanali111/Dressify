from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime
import uuid

class GoogleAuthRequest(BaseModel):
    id_token: str

class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    profile_url: Optional[str] = None
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class AuthResponse(BaseModel):
    jwt: str
    user: UserResponse
    has_profile: bool
