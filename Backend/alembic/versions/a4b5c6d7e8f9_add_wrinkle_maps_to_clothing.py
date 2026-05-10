"""add wrinkle_maps to clothing_items

Revision ID: a4b5c6d7e8f9
Revises: 3f4bca9f6df1
Create Date: 2026-05-10 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'a4b5c6d7e8f9'
down_revision: Union[str, None] = '3f4bca9f6df1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'clothing_items',
        sa.Column('wrinkle_maps', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('clothing_items', 'wrinkle_maps')
