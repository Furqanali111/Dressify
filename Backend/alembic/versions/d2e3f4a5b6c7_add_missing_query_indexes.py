"""add missing query indexes

Three gaps left by earlier migrations:

1. ai_feedback(outfit_id, created_at DESC)
   GET /feedback/outfits/{id} filters by outfit_id and sorts by created_at.
   Without this, every call does a full table scan on ai_feedback.

2. upload_retry_queue(status, next_retry_at)
   The retry worker ticks every N seconds and queries:
     WHERE status = 'pending' AND next_retry_at <= now()
   A composite index lets PG skip all non-pending rows entirely.

3. notifications(user_id, is_read) — partial WHERE is_read = false
   GET /notifications/unread-count runs on every app start and polls
   frequently. A partial index on unread rows only is tiny and lightning-fast.

Revision ID: d2e3f4a5b6c7
Revises: c1d2e3f4a5b6
Create Date: 2026-05-09
"""
from alembic import op

revision = 'd2e3f4a5b6c7'
down_revision = 'c1d2e3f4a5b6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. ai_feedback — outfit lookup + recency sort
    op.create_index(
        'ix_ai_feedback_outfit_created',
        'ai_feedback',
        ['outfit_id', 'created_at'],
        postgresql_ops={'created_at': 'DESC'},
        if_not_exists=True,
    )

    # 2. upload_retry_queue — composite filter used by the retry worker tick
    op.create_index(
        'ix_upload_retry_queue_status_next',
        'upload_retry_queue',
        ['status', 'next_retry_at'],
        if_not_exists=True,
    )

    # 3. notifications — partial index for unread-count query
    #    Only indexes rows where is_read = false, keeping the index tiny.
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_notifications_unread
        ON notifications (user_id)
        WHERE is_read = false
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_notifications_unread")
    op.drop_index('ix_upload_retry_queue_status_next', table_name='upload_retry_queue')
    op.drop_index('ix_ai_feedback_outfit_created', table_name='ai_feedback')
