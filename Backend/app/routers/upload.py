from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status, BackgroundTasks, Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.user import User
from app.deps import get_current_user
from app.services.storage import upload_file, get_signed_url
from app.services.image_processing import remove_background, detect_type_and_anchors
from app.services.ai_vision import extract_clothing_metadata
from app.schemas.clothing import ClothingItemResponse
from app.main import limiter
import uuid
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/upload", tags=["Upload"])

@router.post("", response_model=ClothingItemResponse)
@limiter.limit("5/minute")
async def upload_clothing(
    request: Request,
    background_tasks: BackgroundTasks,
    image: UploadFile = File(...),
    name: str = Form("Unnamed Item"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
        
    image_bytes = await image.read()
    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image must be < 10MB")
        
    item_id = uuid.uuid4()
    raw_path = f"{current_user.id}/{item_id}.jpg"
    processed_path = f"{current_user.id}/{item_id}.png"
    
    # 1. Persist raw
    if not upload_file("clothing-raw", raw_path, image_bytes, image.content_type):
        raise HTTPException(status_code=500, detail="Failed to upload raw image")
        
    # 2. rembg
    try:
        processed_bytes = remove_background(image_bytes)
    except Exception as e:
        logger.error(f"Image processing error: {e}")
        raise HTTPException(status_code=500, detail="Image processing failed")
        
    # 3. Upload processed
    if not upload_file("clothing-processed", processed_path, processed_bytes, "image/png"):
        raise HTTPException(status_code=500, detail="Failed to upload processed image")
        
    # 4. OpenCV static guess
    detected_type, anchors, confidence = detect_type_and_anchors(processed_bytes)
    
    # 5. DB insert
    item = ClothingItem(
        id=item_id,
        user_id=current_user.id,
        name=name,
        type=detected_type,
        raw_image_path=raw_path,
        processed_image_path=processed_path,
        detection_confidence=confidence,
        anchor_points=anchors
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    
    # 6. Sign URLs
    raw_url = get_signed_url("clothing-raw", raw_path)
    processed_url = get_signed_url("clothing-processed", processed_path)
    
    # 7. Queue async vision metadata extraction
    background_tasks.add_task(extract_clothing_metadata, item_id, processed_bytes)
    
    response = ClothingItemResponse.model_validate(item)
    response.raw_url = raw_url or ""
    response.processed_url = processed_url or ""
    
    return response
