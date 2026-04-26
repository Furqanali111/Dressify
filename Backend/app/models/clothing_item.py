import uuid
from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from app.db import Base

class ClothingItem(Base):
    __tablename__ = "clothing_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String, nullable=False)
    type = Column(String, nullable=False)
    raw_image_path = Column(String, nullable=False)
    processed_image_path = Column(String, nullable=True)
    detection_confidence = Column(Numeric(3, 2), nullable=True)
    anchor_points = Column(JSONB, nullable=True)
    color = Column(String, nullable=True)
    pattern = Column(String, nullable=True)
    style = Column(String, nullable=True)
    sub_type = Column(String, nullable=True)
    processing_status = Column(String, default="pending")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
