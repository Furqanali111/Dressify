import uuid

from sqlalchemy import Column, String, Integer, Text, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from app.db import Base


class UploadRetryQueue(Base):
    """
    Tracks raw-image uploads whose garment-detection step failed transiently
    (e.g. Ollama unavailable). The retry worker re-attempts detection every
    RETRY_INTERVAL_SECONDS until the item succeeds or max_attempts is reached.

    Bucket: clothing-raw-temp  (must be created manually in Supabase dashboard)
    """
    __tablename__ = "upload_retry_queue"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Owner
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # The placeholder ClothingItem created immediately so the user sees a card.
    # SET NULL if the user deletes the placeholder before a retry succeeds.
    clothing_item_id = Column(
        UUID(as_uuid=True),
        ForeignKey("clothing_items.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Path of the raw image stored in the clothing-raw-temp bucket.
    raw_image_path = Column(String, nullable=False)

    # Original user-supplied name (used to name garments after successful retry).
    original_name = Column(String, nullable=False, default="")

    # Retry tracking
    attempt_count = Column(Integer, nullable=False, default=0)
    max_attempts = Column(Integer, nullable=False, default=3)
    next_retry_at = Column(DateTime(timezone=True), nullable=False)

    # Status: pending | retrying | succeeded | failed
    status = Column(String, nullable=False, default="pending")

    # Last error message (truncated to 500 chars)
    error_message = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
