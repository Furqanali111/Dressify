import uuid
from sqlalchemy import Column, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from app.db import Base


class WearLog(Base):
    __tablename__ = "wear_logs"

    id                = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id           = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    outfit_id         = Column(UUID(as_uuid=True), ForeignKey("outfits.id", ondelete="SET NULL"), nullable=True)
    clothing_item_ids = Column(JSONB, nullable=True)
    logged_at         = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_wear_logs_user_logged", "user_id", "logged_at"),
    )
