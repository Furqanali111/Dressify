import uuid as _uuid
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.notification import Notification


def push_notification(
    db: AsyncSession,
    user_id: _uuid.UUID,
    notif_type: str,
    title: str,
    body: str,
) -> None:
    """Add a notification to the session. Caller is responsible for committing."""
    db.add(Notification(
        id=_uuid.uuid4(),
        user_id=user_id,
        type=notif_type,
        title=title,
        body=body,
    ))
