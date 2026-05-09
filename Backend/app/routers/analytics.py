import asyncio
import logging
from collections import Counter
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query, Request
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
    days: int = Query(default=90, ge=7, le=365, description="How many days of wear history to include"),
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

    # ── Scalar-only wear log fetch (bounded to `days` window) ─────────────────
    log_since = datetime.now(timezone.utc) - timedelta(days=days)
    log_rows = (await db.execute(
        select(WearLog.clothing_item_ids, WearLog.logged_at)
        .where(
            WearLog.user_id == current_user.id,
            WearLog.logged_at >= log_since,
        )
        .order_by(WearLog.logged_at.desc())
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
        ).where(
            ClothingItem.user_id == current_user.id,
        )
    )).all()

    # ── Most worn (top 5) + underutilised (up to 10) ────────────────────────
    item_map = {str(row.id): row for row in item_rows}

    most_worn_candidates = [
        (item_map[cid], cnt)
        for cid, cnt in wear_counter.most_common(5)
        if cid in item_map
    ]
    underutilised_candidates = [
        (row, wear_counter.get(str(row.id), 0))
        for row in item_rows
        if str(row.id) not in recently_worn_ids and row.processing_status == "completed"
    ][:10]

    # Fetch all signed URLs in parallel — get_signed_url is a blocking Supabase
    # call; running them concurrently via asyncio.to_thread keeps the event loop
    # free and reduces total latency from N×T to ~T.
    all_candidates = most_worn_candidates + underutilised_candidates

    async def _signed(path: str | None) -> str:
        if not path:
            return ""
        return await asyncio.to_thread(get_signed_url, settings.CLOTHING_BUCKET, path) or ""

    urls = await asyncio.gather(*[_signed(row.processed_image_path) for row, _ in all_candidates])

    def _build(row, count: int, url: str) -> WornItem:
        return WornItem(id=str(row.id), name=row.name, type=row.type, wear_count=count, processed_url=url)

    split = len(most_worn_candidates)
    most_worn      = [_build(r, c, urls[i])       for i, (r, c) in enumerate(most_worn_candidates)]
    underutilised  = [_build(r, c, urls[split + i]) for i, (r, c) in enumerate(underutilised_candidates)]

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
