"""Add upload_retry_queue table

Revision ID: d5e6f7a8b9c0
Revises: baf1c8f5d6f4
Create Date: 2026-04-27 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "d5e6f7a8b9c0"
down_revision: Union[str, None] = "baf1c8f5d6f4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "upload_retry_queue",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "clothing_item_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("clothing_items.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("raw_image_path", sa.String(), nullable=False),
        sa.Column("original_name", sa.String(), nullable=False, server_default=""),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("max_attempts", sa.Integer(), nullable=False, server_default="3"),
        sa.Column("next_retry_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="pending"),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_upload_retry_queue_user_id",
        "upload_retry_queue",
        ["user_id"],
    )
    op.create_index(
        "ix_upload_retry_queue_status_next_retry",
        "upload_retry_queue",
        ["status", "next_retry_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_upload_retry_queue_status_next_retry", table_name="upload_retry_queue")
    op.drop_index("ix_upload_retry_queue_user_id", table_name="upload_retry_queue")
    op.drop_table("upload_retry_queue")
