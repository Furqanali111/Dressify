import logging
from collections import Counter
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

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
    # ── Total items & outfits ────────────────────────────────────────────────
    items_result  = await db.execute(select(ClothingItem).where(ClothingItem.user_id == current_user.id))
    all_items     = items_result.scalars().all()
    outfits_count = (await db.execute(
        select(func.count()).where(Outfit.user_id == current_user.id)
    )).scalar_one()

    # ── Wear log counts per clothing item ───────────────────────────────────
    logs_result = await db.execute(
        select(WearLog).where(WearLog.user_id == current_user.id)
    )
    all_logs = logs_result.scalars().all()

    wear_counter: Counter = Counter()
    for log in all_logs:
        if log.clothing_item_ids:
            for cid in log.clothing_item_ids:
                wear_counter[cid] += 1

    item_map = {str(i.id): i for i in all_items}

    def _worn_item(item: ClothingItem, count: int) -> WornItem:
        url = get_signed_url("clothing-processed", item.processed_image_path) if item.processed_image_path else ""
        return WornItem(id=str(item.id), name=item.name, type=item.type, wear_count=count, processed_url=url)

    # ── Most worn (top 5) ────────────────────────────────────────────────────
    most_worn = [
        _worn_item(item_map[cid], cnt)
        for cid, cnt in wear_counter.most_common(5)
        if cid in item_map
    ]

    # ── Underutilised (no wear in last 30 days) ──────────────────────────────
    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    recently_worn_ids: set[str] = set()
    for log in all_logs:
        log_time = log.logged_at
        if log_time.tzinfo is None:
            log_time = log_time.replace(tzinfo=timezone.utc)
        if log_time >= cutoff and log.clothing_item_ids:
            recently_worn_ids.update(log.clothing_item_ids)

    underutilised = [
        _worn_item(item, wear_counter.get(str(item.id), 0))
        for item in all_items
        if str(item.id) not in recently_worn_ids and item.processing_status == "completed"
    ][:10]

    # ── Color distribution ───────────────────────────────────────────────────
    color_dist: Counter = Counter()
    for item in all_items:
        if item.color:
            color_dist[item.color.lower().strip()] += 1

    # ── Style breakdown ──────────────────────────────────────────────────────
    style_dist: Counter = Counter()
    for item in all_items:
        if item.style:
            style_dist[item.style.lower().strip()] += 1

    # ── Outfit frequency (last 4 ISO weeks) ──────────────────────────────────
    now = datetime.now(timezone.utc)
    weekly: dict[str, int] = {}
    for w in range(4):
        week_start = now - timedelta(weeks=w)
        label = f"{week_start.isocalendar().year}-W{week_start.isocalendar().week:02d}"
        weekly[label] = 0

    for log in all_logs:
        log_time = log.logged_at
        if log_time.tzinfo is None:
            log_time = log_time.replace(tzinfo=timezone.utc)
        iso = log_time.isocalendar()
        label = f"{iso.year}-W{iso.week:02d}"
        if label in weekly:
            weekly[label] += 1

    outfit_frequency = [WeeklyFrequency(week=k, count=v) for k, v in sorted(weekly.items())]

    return WardrobeAnalyticsResponse(
        total_items=len(all_items),
        total_outfits=outfits_count,
        most_worn=most_worn,
        underutilised=underutilised,
        color_distribution=dict(color_dist.most_common(10)),
        style_breakdown=dict(style_dist.most_common(8)),
        outfit_frequency=outfit_frequency,
    )
