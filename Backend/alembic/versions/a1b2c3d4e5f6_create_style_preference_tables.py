"""create user_style_preferences and outfit_interactions tables

Revision ID: a1b2c3d4e5f6
Revises: f7a8b9c0d1e2
Create Date: 2026-04-29

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB

revision = "a1b2c3d4e5f6"
down_revision = "f7a8b9c0d1e2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_style_preferences",
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("liked_colors",    JSONB, nullable=True),
        sa.Column("liked_styles",    JSONB, nullable=True),
        sa.Column("liked_patterns",  JSONB, nullable=True),
        sa.Column("disliked_styles", JSONB, nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now()),
    )

    op.create_table(
        "outfit_interactions",
        sa.Column("id",                UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id",           UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("action",            sa.String(20), nullable=False),
        sa.Column("clothing_item_ids", JSONB, nullable=True),
        sa.Column("outfit_id",         UUID(as_uuid=True), sa.ForeignKey("outfits.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at",        sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_outfit_interactions_user_id", "outfit_interactions", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_outfit_interactions_user_id", table_name="outfit_interactions")
    op.drop_table("outfit_interactions")
    op.drop_table("user_style_preferences")
