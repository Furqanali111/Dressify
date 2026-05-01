import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from app.db import Base


class UserStylePreference(Base):
    __tablename__ = "user_style_preferences"

    user_id         = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    liked_colors    = Column(JSONB, nullable=True)
    liked_styles    = Column(JSONB, nullable=True)
    liked_patterns  = Column(JSONB, nullable=True)
    disliked_styles = Column(JSONB, nullable=True)
    updated_at      = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class OutfitInteraction(Base):
    __tablename__ = "outfit_interactions"

    id                = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id           = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    action            = Column(String(20), nullable=False)
    clothing_item_ids = Column(JSONB, nullable=True)
    outfit_id         = Column(UUID(as_uuid=True), ForeignKey("outfits.id", ondelete="SET NULL"), nullable=True)
    created_at        = Column(DateTime(timezone=True), server_default=func.now())
