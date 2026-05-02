import logging
from collections import Counter
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, cast, String

from app.config import settings
from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.outfit import Outfit
from app.models.wear_log import WearLog
from app.models.user import User
from app.deps import get_current_user
from app.schemas.analytics import WardrobeAnalyticsResponse, WornItem, WeeklyFrequency
from app.services.storage import get_signed_url
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/wardrobe", response_model=WardrobeAnalyticsResponse)
@limiter.limit("10/minute")
async def get_wardrobe_analytics(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # ── Total items & outfits (aggregate, no ORM hydration) ─────────────────
    total_items: int = (await db.execute(
        select(func.count()).select_from(ClothingItem).where(ClothingItem.user_id == current_user.id)
    )).scalar_one()

    total_outfits: int = (await db.execute(
        select(func.count()).select_from(Outfit).where(Outfit.user_id == current_user.id)
    )).scalar_one()

    # ── Scalar-only wear log fetch (avoids loading full ORM rows) ─────────────
    # Select only the columns we actually need — clothing_item_ids and logged_at
    log_rows = (await db.execute(
        select(WearLog.clothing_item_ids, WearLog.logged_at)
        .where(WearLog.user_id == current_user.id)
    )).all()

    # ── Wear counter ──────────────────────────────────────────────────────────
    wear_counter: Counter = Counter()
    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    recently_worn_ids: set[str] = set()

    now = datetime.now(timezone.utc)
    weekly: dict[str, int] = {}
    for w in range(4):
        week_start = now - timedelta(weeks=w)
        label = f"{week_start.isocalendar().year}-W{week_start.isocalendar().week:02d}"
        weekly[label] = 0

    for item_ids, logged_at in log_rows:
        if item_ids:
            for cid in item_ids:
                wear_counter[cid] += 1

        log_time = logged_at
        if log_time.tzinfo is None:
            log_time = log_time.replace(tzinfo=timezone.utc)

        if log_time >= cutoff and item_ids:
            recently_worn_ids.update(item_ids)

        iso = log_time.isocalendar()
        label = f"{iso.year}-W{iso.week:02d}"
        if label in weekly:
            weekly[label] += 1

    # ── Scalar-only item fetch (only columns we need for display) ────────────
    item_rows = (await db.execute(
        select(
            ClothingItem.id,
            ClothingItem.name,
            ClothingItem.type,
            ClothingItem.color,
            ClothingItem.style,
            ClothingItem.processed_image_path,
            ClothingItem.processing_status,
        ).where(ClothingItem.user_id == current_user.id)
    )).all()

    # ── Most worn (top 5) ────────────────────────────────────────────────────
    item_map = {str(row.id): row for row in item_rows}

    def _worn_item(row, count: int) -> WornItem:
        url = get_signed_url(settings.CLOTHING_BUCKET, row.processed_image_path) if row.processed_image_path else ""
        return WornItem(id=str(row.id), name=row.name, type=row.type, wear_count=count, processed_url=url)

    most_worn = [
        _worn_item(item_map[cid], cnt)
        for cid, cnt in wear_counter.most_common(5)
        if cid in item_map
    ]

    # ── Underutilised (no wear in last 30 days, completed items only) ────────
    underutilised = [
        _worn_item(row, wear_counter.get(str(row.id), 0))
        for row in item_rows
        if str(row.id) not in recently_worn_ids and row.processing_status == "completed"
    ][:10]

    # ── Color & style distributions ──────────────────────────────────────────
    color_dist: Counter = Counter()
    style_dist: Counter = Counter()
    for row in item_rows:
        if row.color:
            color_dist[row.color.lower().strip()] += 1
        if row.style:
            style_dist[row.style.lower().strip()] += 1

    outfit_frequency = [WeeklyFrequency(week=k, count=v) for k, v in sorted(weekly.items())]

    return WardrobeAnalyticsResponse(
        total_items=total_items,
        total_outfits=total_outfits,
        most_worn=most_worn,
        underutilised=underutilised,
        color_distribution=dict(color_dist.most_common(10)),
        style_breakdown=dict(style_dist.most_common(8)),
        outfit_frequency=outfit_frequency,
    )
