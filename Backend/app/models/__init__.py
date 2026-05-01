from app.db import Base
from app.models.user import User
from app.models.profile import Profile
from app.models.clothing_item import ClothingItem
from app.models.outfit import Outfit, OutfitItem
from app.models.ai_feedback import AiFeedback
from app.models.upload_retry_queue import UploadRetryQueue
from app.models.notification import Notification

# Expose all models for Alembic
__all__ = [
    "Base",
    "User",
    "Profile",
    "ClothingItem",
    "Outfit",
    "OutfitItem",
    "AiFeedback",
    "UploadRetryQueue",
    "Notification",
]
