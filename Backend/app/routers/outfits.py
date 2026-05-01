import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.db import get_db
from app.models.outfit import Outfit, OutfitItem
from app.models.style_preference import UserStylePreference
from app.models.user import User
from app.models.clothing_item import ClothingItem
from app.deps import get_current_user
from app.schemas.outfit import OutfitCreate, OutfitUpdate, OutfitResponse, OutfitItemSchema, GenerateOutfitRequest
from app.services.weather import get_current_weather
from app.services.ai_outfit_generator import generate_outfit
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/outfits", tags=["Outfits"])


def _build_outfit_response(outfit: Outfit) -> OutfitResponse:
    return OutfitResponse(
        id=outfit.id,
        user_id=outfit.user_id,
        name=outfit.name,
        avatar_kind=outfit.avatar_kind,
        items=[OutfitItemSchema(clothing_item_id=i.clothing_item_id, position=i.position) for i in outfit.items],
        created_at=outfit.created_at,
    )


@router.post("", response_model=OutfitResponse)
async def create_outfit(
    outfit_in: OutfitCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if outfit_in.items:
        requested_ids = [item.clothing_item_id for item in outfit_in.items]
        owned_result = await db.execute(
            select(ClothingItem.id).where(
                ClothingItem.id.in_(requested_ids),
                ClothingItem.user_id == current_user.id,
            )
        )
        owned_ids = {row[0] for row in owned_result.all()}
        missing = set(requested_ids) - owned_ids
        if missing:
            raise HTTPException(
                status_code=404,
                detail=f"Clothing item(s) not found: {', '.join(str(m) for m in missing)}",
            )

    outfit_id = uuid.uuid4()
    outfit = Outfit(
        id=outfit_id,
        user_id=current_user.id,
        name=outfit_in.name,
        avatar_kind=outfit_in.avatar_kind,
    )
    db.add(outfit)

    outfit_item_schemas = []
    for item in outfit_in.items:
        db.add(OutfitItem(
            outfit_id=outfit_id,
            clothing_item_id=item.clothing_item_id,
            position=item.position,
        ))
        outfit_item_schemas.append(item)

    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        logger.error(f"DB integrity error creating outfit: {e}")
        raise HTTPException(status_code=400, detail="Invalid clothing item reference")

    await db.refresh(outfit)
    return OutfitResponse(
        id=outfit.id,
        user_id=outfit.user_id,
        name=outfit.name,
        avatar_kind=outfit.avatar_kind,
        items=outfit_item_schemas,
        created_at=outfit.created_at,
    )


@router.get("", response_model=list[OutfitResponse])
@limiter.limit("60/minute")
async def get_outfits(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Outfit)
        .where(Outfit.user_id == current_user.id)
        .options(selectinload(Outfit.items))
    )
    outfits = result.scalars().all()
    return [_build_outfit_response(o) for o in outfits]


@router.get("/{outfit_id}", response_model=OutfitResponse)
@limiter.limit("60/minute")
async def get_outfit(
    request: Request,
    outfit_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Outfit)
        .where(Outfit.id == outfit_id, Outfit.user_id == current_user.id)
        .options(selectinload(Outfit.items))
    )
    outfit = result.scalar_one_or_none()

    if not outfit:
        raise HTTPException(status_code=404, detail="Outfit not found")

    return _build_outfit_response(outfit)


@router.patch("/{outfit_id}", response_model=OutfitResponse)
async def update_outfit(
    outfit_id: uuid.UUID,
    update_data: OutfitUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Outfit)
        .where(Outfit.id == outfit_id, Outfit.user_id == current_user.id)
        .options(selectinload(Outfit.items))
    )
    outfit = result.scalar_one_or_none()

    if not outfit:
        raise HTTPException(status_code=404, detail="Outfit not found")

    outfit.name = update_data.name

    try:
        await db.commit()
        await db.refresh(outfit)
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error(f"DB error updating outfit {outfit_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to update outfit")

    return _build_outfit_response(outfit)


@router.post("/generate", response_model=OutfitResponse)
@limiter.limit("5/minute")
async def auto_generate_outfit(
    request: Request,
    body: GenerateOutfitRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    wardrobe_result = await db.execute(select(ClothingItem).where(ClothingItem.user_id == current_user.id))
    wardrobe_items = wardrobe_result.scalars().all()
    if not wardrobe_items:
        raise HTTPException(status_code=400, detail="Wardrobe is empty")

    wardrobe_descriptions = []
    seed_item_details = None

    for w in wardrobe_items:
        desc = f"ID: {w.id} | {w.name} ({w.type})"
        extras = [e for e in [w.sub_type, w.color, w.pattern, w.style] if e]
        if extras:
            desc += f" - {', '.join(extras)}"
        wardrobe_descriptions.append(desc)
        if body.seed_item_id and w.id == body.seed_item_id:
            seed_item_details = desc

    wardrobe_details_str = "\n".join(wardrobe_descriptions)

    pref_result = await db.execute(
        select(UserStylePreference).where(UserStylePreference.user_id == current_user.id)
    )
    pref = pref_result.scalar_one_or_none()
    style_profile_str = None
    if pref:
        parts = []
        if pref.liked_styles:    parts.append(f"Liked styles: {', '.join(pref.liked_styles)}")
        if pref.liked_colors:    parts.append(f"Liked colors: {', '.join(pref.liked_colors)}")
        if pref.liked_patterns:  parts.append(f"Liked patterns: {', '.join(pref.liked_patterns)}")
        if pref.disliked_styles: parts.append(f"Disliked styles: {', '.join(pref.disliked_styles)}")
        style_profile_str = "; ".join(parts) if parts else None
    is_personalized = style_profile_str is not None

    weather_context = None
    if body.lat is not None and body.lon is not None:
        weather_context = await get_current_weather(body.lat, body.lon)

    try:
        chosen_ids = generate_outfit(wardrobe_details_str, body.occasion, weather_context, seed_item_details, style_profile_str)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error during outfit generation: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Outfit generation failed unexpectedly")

    if not chosen_ids:
        raise HTTPException(status_code=500, detail="AI could not generate an outfit")

    valid_ids = [str(w.id) for w in wardrobe_items]
    final_ids = [uid for uid in chosen_ids if str(uid) in valid_ids]

    if not final_ids:
        raise HTTPException(status_code=500, detail="AI returned invalid item IDs")

    avatar_kind = body.avatar_kind or "maleAverage"

    outfit_id = uuid.uuid4()
    new_outfit = Outfit(
        id=outfit_id,
        user_id=current_user.id,
        name=f"Generated — {body.occasion}",
        avatar_kind=avatar_kind,
    )
    db.add(new_outfit)

    outfit_item_schemas = []
    for ci_id in final_ids:
        ci_uuid = uuid.UUID(ci_id)
        db.add(OutfitItem(outfit_id=outfit_id, clothing_item_id=ci_uuid))
        outfit_item_schemas.append(OutfitItemSchema(clothing_item_id=ci_uuid))

    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        logger.error(f"DB integrity error saving generated outfit: {e}")
        raise HTTPException(status_code=400, detail="One or more items were removed before outfit creation")

    await db.refresh(new_outfit)

    return OutfitResponse(
        id=new_outfit.id,
        user_id=new_outfit.user_id,
        name=new_outfit.name,
        avatar_kind=new_outfit.avatar_kind,
        items=outfit_item_schemas,
        created_at=new_outfit.created_at,
        personalized=is_personalized,
    )


@router.delete("/{outfit_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_outfit(
    outfit_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Outfit).where(Outfit.id == outfit_id, Outfit.user_id == current_user.id)
    )
    outfit = result.scalar_one_or_none()

    if not outfit:
        raise HTTPException(status_code=404, detail="Outfit not found")

    await db.delete(outfit)
    await db.commit()
    return None
