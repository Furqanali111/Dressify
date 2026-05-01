"""create wear_logs table

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-04-29

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB

revision = "b2c3d4e5f6a7"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "wear_logs",
        sa.Column("id",               UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id",          UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("outfit_id",        UUID(as_uuid=True), sa.ForeignKey("outfits.id", ondelete="SET NULL"), nullable=True),
        sa.Column("clothing_item_ids", JSONB, nullable=True),
        sa.Column("logged_at",        sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_wear_logs_user_id",   "wear_logs", ["user_id"])
    op.create_index("ix_wear_logs_logged_at", "wear_logs", ["logged_at"])


def downgrade() -> None:
    op.drop_index("ix_wear_logs_logged_at", table_name="wear_logs")
    op.drop_index("ix_wear_logs_user_id",   table_name="wear_logs")
    op.drop_table("wear_logs")
