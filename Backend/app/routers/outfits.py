from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.db import get_db
from app.models.outfit import Outfit, OutfitItem
from app.models.user import User
from app.models.clothing_item import ClothingItem
from app.deps import get_current_user
from app.schemas.outfit import OutfitCreate, OutfitResponse, OutfitItemSchema, OutfitItemResponse, GenerateOutfitRequest
from app.schemas.clothing import ClothingItemResponse
from app.services.weather import get_current_weather
from app.services.ai_outfit_generator import generate_outfit
from app.main import limiter
import uuid

router = APIRouter(prefix="/outfits", tags=["Outfits"])

@router.post("", response_model=OutfitResponse)
async def create_outfit(
    outfit_in: OutfitCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    outfit_id = uuid.uuid4()
    outfit = Outfit(
        id=outfit_id,
        user_id=current_user.id,
        name=outfit_in.name,
        avatar_kind=outfit_in.avatar_kind
    )
    db.add(outfit)
    
    items = []
    for item in outfit_in.items:
        oi = OutfitItem(
            outfit_id=outfit_id,
            clothing_item_id=item.clothing_item_id,
            position=item.position
        )
        db.add(oi)
        items.append(item)
        
    await db.commit()
    await db.refresh(outfit)
    
    return OutfitResponse(
        id=outfit.id,
        user_id=outfit.user_id,
        name=outfit.name,
        avatar_kind=outfit.avatar_kind,
        items=items,
        created_at=outfit.created_at
    )

@router.get("", response_model=list[OutfitResponse])
async def get_outfits(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Outfit).where(Outfit.user_id == current_user.id))
    outfits = result.scalars().all()
    
    outfits_resp = []
    for o in outfits:
        items_result = await db.execute(select(OutfitItem).where(OutfitItem.outfit_id == o.id))
        items = items_result.scalars().all()
        outfits_resp.append(OutfitResponse(
            id=o.id,
            user_id=o.user_id,
            name=o.name,
            avatar_kind=o.avatar_kind,
            items=[OutfitItemSchema(clothing_item_id=i.clothing_item_id, position=i.position) for i in items],
            created_at=o.created_at
        ))
        
    return {"status": "success"}

@router.post("/generate", response_model=OutfitResponse)
@limiter.limit("5/minute")
async def auto_generate_outfit(
    request: Request,
    body: GenerateOutfitRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Fetch wardrobe
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
    
    weather_context = None
    if body.lat is not None and body.lon is not None:
        weather_context = await get_current_weather(body.lat, body.lon)
        
    chosen_ids = generate_outfit(wardrobe_details_str, body.occasion, weather_context, seed_item_details)
    
    if not chosen_ids:
        raise HTTPException(status_code=500, detail="AI could not generate an outfit")
        
    # Verify chosen_ids belong to user
    valid_ids = [str(w.id) for w in wardrobe_items]
    final_ids = [uid for uid in chosen_ids if str(uid) in valid_ids]
    
    if not final_ids:
        raise HTTPException(status_code=500, detail="AI returned invalid item IDs")
        
    # Create outfit
    new_outfit = Outfit(
        id=uuid.uuid4(),
        user_id=current_user.id,
        name=f"Generated for {body.occasion}"
    )
    db.add(new_outfit)
    
    items = []
    for ci_id in final_ids:
        db.add(OutfitItem(id=uuid.uuid4(), outfit_id=new_outfit.id, clothing_item_id=uuid.UUID(ci_id)))
        # populate response
        ci = next((w for w in wardrobe_items if str(w.id) == ci_id), None)
        if ci:
            items.append(ClothingItemResponse.model_validate(ci))
        
    await db.commit()
    await db.refresh(new_outfit)
    
    response = OutfitResponse.model_validate(new_outfit)
    response.items = items
    return response

@router.delete("/{outfit_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_outfit(
    outfit_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Outfit).where(Outfit.id == outfit_id, Outfit.user_id == current_user.id))
    outfit = result.scalar_one_or_none()
    
    if not outfit:
        raise HTTPException(status_code=404, detail="Outfit not found")
        
    await db.delete(outfit)
    await db.commit()
    return None
