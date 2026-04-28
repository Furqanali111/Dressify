"""Add body measurements to profiles

Revision ID: e6f7a8b9c0d1
Revises: d5e6f7a8b9c0
Create Date: 2026-04-28 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e6f7a8b9c0d1"
down_revision: Union[str, None] = "d5e6f7a8b9c0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("profiles", sa.Column("chest_cm",    sa.Numeric(5, 2), nullable=True))
    op.add_column("profiles", sa.Column("waist_cm",    sa.Numeric(5, 2), nullable=True))
    op.add_column("profiles", sa.Column("hip_cm",      sa.Numeric(5, 2), nullable=True))
    op.add_column("profiles", sa.Column("shoulder_cm", sa.Numeric(5, 2), nullable=True))


def downgrade() -> None:
    op.drop_column("profiles", "shoulder_cm")
    op.drop_column("profiles", "hip_cm")
    op.drop_column("profiles", "waist_cm")
    op.drop_column("profiles", "chest_cm")
