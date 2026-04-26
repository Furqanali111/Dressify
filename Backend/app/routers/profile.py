from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db import get_db
from app.schemas.profile import ProfileUpdate, ProfileResponse
from app.models.profile import Profile
from app.models.user import User
from app.deps import get_current_user

router = APIRouter(prefix="/profile", tags=["Profile"])

@router.get("", response_model=ProfileResponse)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Profile).where(Profile.user_id == current_user.id))
    profile = result.scalar_one_or_none()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    return profile

@router.patch("", response_model=ProfileResponse)
async def update_profile(
    update_data: ProfileUpdate, 
    current_user: User = Depends(get_current_user), 
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Profile).where(Profile.user_id == current_user.id))
    profile = result.scalar_one_or_none()
    
    if not profile:
        profile = Profile(user_id=current_user.id)
        db.add(profile)
        
    update_dict = update_data.model_dump(exclude_unset=True)
    for key, value in update_dict.items():
        setattr(profile, key, value)
        
    await db.commit()
    await db.refresh(profile)
    
    return profile
