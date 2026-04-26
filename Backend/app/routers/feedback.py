from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db import get_db
from app.models.ai_feedback import AiFeedback
from app.models.outfit import Outfit, OutfitItem
from app.models.clothing_item import ClothingItem
from app.models.user import User
from app.deps import get_current_user
from app.schemas.feedback import FeedbackRequest, AiFeedbackResponse
from app.services.ai_feedback import get_feedback_for_outfit
from app.services.weather import get_current_weather
from app.main import limiter
import uuid

router = APIRouter(prefix="/feedback", tags=["AI Feedback"])

@router.post("", response_model=AiFeedbackResponse)
@limiter.limit("5/minute")
async def generate_feedback(
    request: Request,
    body: FeedbackRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Verify outfit belongs to user
    outfit_result = await db.execute(select(Outfit).where(Outfit.id == body.outfit_id, Outfit.user_id == current_user.id))
    outfit = outfit_result.scalar_one_or_none()
    
    if not outfit:
        raise HTTPException(status_code=404, detail="Outfit not found")
        
    # Fetch all clothing items in this outfit to construct a description for the AI
    oi_result = await db.execute(select(OutfitItem).where(OutfitItem.outfit_id == outfit.id))
    outfit_items = oi_result.scalars().all()
    
    clothing_descriptions = []
    for oi in outfit_items:
        ci_result = await db.execute(select(ClothingItem).where(ClothingItem.id == oi.clothing_item_id))
        ci = ci_result.scalar_one_or_none()
        if ci:
            desc = f"{ci.name} ({ci.type})"
            extras = [e for e in [ci.sub_type, ci.color, ci.pattern, ci.style] if e]
            if extras:
                desc += f" - {', '.join(extras)}"
            clothing_descriptions.append(desc)
            
    outfit_details_str = ", ".join(clothing_descriptions) if clothing_descriptions else "Empty Outfit"
        
    # Fetch user's entire wardrobe for recommendations
    wardrobe_result = await db.execute(select(ClothingItem).where(ClothingItem.user_id == current_user.id))
    wardrobe_items = wardrobe_result.scalars().all()
    wardrobe_descriptions = []
    for w in wardrobe_items:
        desc = f"{w.name} ({w.type})"
        extras = [e for e in [w.sub_type, w.color, w.pattern, w.style] if e]
        if extras:
            desc += f" - {', '.join(extras)}"
        wardrobe_descriptions.append(desc)
        
    wardrobe_details_str = ", ".join(wardrobe_descriptions) if wardrobe_descriptions else "No other items in wardrobe"
        
    weather_context = None
    if body.lat is not None and body.lon is not None:
        weather_context = await get_current_weather(body.lat, body.lon)
        
    feedback_data = get_feedback_for_outfit(outfit_details_str, body.occasion, wardrobe_details_str, weather_context)
    
    feedback = AiFeedback(
        id=uuid.uuid4(),
        outfit_id=body.outfit_id,
        score=feedback_data["score"],
        verdict=feedback_data["verdict"],
        suggestions=feedback_data["suggestions"]
    )
    
    db.add(feedback)
    await db.commit()
    await db.refresh(feedback)
    
    return feedback
