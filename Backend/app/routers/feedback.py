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
    if body.outfit_id:
        outfit_result = await db.execute(select(Outfit).where(Outfit.id == body.outfit_id, Outfit.user_id == current_user.id))
        outfit = outfit_result.scalar_one_or_none()
        if not outfit:
            raise HTTPException(status_code=404, detail="Outfit not found")
            
        oi_result = await db.execute(select(OutfitItem).where(OutfitItem.outfit_id == outfit.id))
        outfit_items = oi_result.scalars().all()
        item_ids = [oi.clothing_item_id for oi in outfit_items]
    elif body.clothing_item_ids:
        item_ids = body.clothing_item_ids
    else:
        raise HTTPException(status_code=400, detail="Must provide either outfit_id or clothing_item_ids")
        
    clothing_descriptions = []
    if item_ids:
        ci_result = await db.execute(select(ClothingItem).where(ClothingItem.id.in_(item_ids)))
        clothing_items = ci_result.scalars().all()
        for ci in clothing_items:
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
        
    try:
        feedback_data = get_feedback_for_outfit(outfit_details_str, body.occasion, wardrobe_details_str, weather_context)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    
    feedback_id = uuid.uuid4()
    
    if body.outfit_id:
        feedback = AiFeedback(
            id=feedback_id,
            outfit_id=body.outfit_id,
            score=feedback_data["score"],
            verdict=feedback_data["verdict"],
            suggestions=feedback_data["suggestions"]
        )
        db.add(feedback)
        await db.commit()
        await db.refresh(feedback)
        return feedback
    else:
        # If no outfit_id, don't persist to DB, just return the response
        from datetime import datetime
        return AiFeedbackResponse(
            id=feedback_id,
            outfit_id=None,
            score=feedback_data["score"],
            verdict=feedback_data["verdict"],
            suggestions=feedback_data["suggestions"],
            created_at=datetime.utcnow()
        )
