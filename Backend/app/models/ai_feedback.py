import uuid
from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from app.db import Base

class AiFeedback(Base):
    __tablename__ = "ai_feedback"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    outfit_id = Column(UUID(as_uuid=True), ForeignKey("outfits.id", ondelete="CASCADE"), nullable=False)
    score = Column(Numeric(3, 1), nullable=False)
    verdict = Column(String, nullable=False)
    suggestions = Column(JSONB, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
