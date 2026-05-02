"""Background task: update UserStylePreference from AI feedback signals."""
from __future__ import annotations
import logging
from typing import Optional

from app.db import AsyncSessionLocal
from app.models.style_preference import UserStylePreference

logger = logging.getLogger(__name__)


def _merge_unique(existing: Optional[list], additions: list[str]) -> list[str]:
    base = list(existing or [])
    for item in additions:
        if item and item not in base:
            base.append(item)
    return base


async def update_style_preferences_from_feedback(
    user_id: str,
    score: float,
    suggestions: list[str],
    item_styles: list[str],
    item_colors: list[str],
    item_patterns: list[str],
) -> None:
    """Increment liked/disliked style preference fields based on feedback score.

    score >= 4  → items are liked → add styles/colors/patterns to liked_*
    score <= 2  → items are disliked → add styles to disliked_styles
    """
    try:
        async with AsyncSessionLocal() as session:
            from sqlalchemy import select
            from uuid import UUID
            uid = UUID(user_id) if isinstance(user_id, str) else user_id
            result = await session.execute(
                select(UserStylePreference).where(UserStylePreference.user_id == uid)
            )
            pref = result.scalar_one_or_none()
            if pref is None:
                pref = UserStylePreference(user_id=uid)
                session.add(pref)

            if score >= 4:
                pref.liked_styles   = _merge_unique(pref.liked_styles,   item_styles)
                pref.liked_colors   = _merge_unique(pref.liked_colors,    item_colors)
                pref.liked_patterns = _merge_unique(pref.liked_patterns,  item_patterns)
            elif score <= 2:
                pref.disliked_styles = _merge_unique(pref.disliked_styles, item_styles)

            await session.commit()
    except Exception as e:
        logger.error(f"Failed to update style preferences for user {user_id}: {e}", exc_info=True)
