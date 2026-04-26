import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, BackgroundTasks, Request
from PIL import UnidentifiedImageError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.models.clothing_item import ClothingItem
from app.models.user import User
from app.deps import get_current_user
from app.services.storage import upload_file, get_signed_url
from app.services.image_processing import detect_garments_in_image, extract_garment, detect_type_and_anchors
from app.services.ai_vision import extract_clothing_metadata
from app.schemas.clothing import ClothingItemResponse
from app.core.limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/upload", tags=["Upload"])


@router.post("", response_model=list[ClothingItemResponse])
@limiter.limit("5/minute")
async def upload_clothing(
    request: Request,
    background_tasks: BackgroundTasks,
    image: UploadFile = File(...),
    name: str = Form(""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    image_bytes = await image.read()
    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image must be < 10 MB")

    # 1. Detect every garment in the uploaded photo
    try:
        garments = await detect_garments_in_image(image_bytes)
    except Exception as e:
        logger.error(f"Garment detection step failed unexpectedly: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Could not analyse image for garments")

    # 2. For each garment: extract → classify → persist
    results: list[ClothingItemResponse] = []
    garment_count = len(garments)

    for idx, garment in enumerate(garments):
        item_id = uuid.uuid4()
        processed_path = f"{current_user.id}/{item_id}.png"

        # Derive a human-readable name
        label = garment.get("label", "clothing").strip().title()
        if garment_count == 1:
            item_name = name.strip() if name.strip() else label
        else:
            # e.g. "My Upload – Shirt (1/2)"
            base = name.strip() if name.strip() else label
            item_name = f"{base} ({idx + 1}/{garment_count})"

        # 2a. Extract garment pixels
        try:
            garment_bytes = extract_garment(image_bytes, garment["bbox"])
        except UnidentifiedImageError:
            logger.warning(f"Garment {idx + 1} skipped — unrecognised image format")
            continue
        except MemoryError:
            logger.error("OOM during garment extraction")
            raise HTTPException(status_code=503, detail="Server busy — try again shortly")
        except Exception as e:
            logger.warning(f"Garment {idx + 1} extraction failed, skipping: {e}")
            continue

        # 2b. Store extracted garment (no raw image saved)
        if not upload_file("clothing-processed", processed_path, garment_bytes, "image/png"):
            logger.warning(f"Garment {idx + 1} storage failed, skipping")
            continue

        # 2c. Classify type + anchors
        try:
            detected_type, anchors, confidence = await detect_type_and_anchors(garment_bytes)
        except Exception as e:
            logger.warning(f"Type detection failed for garment {idx + 1}: {e}")
            detected_type, anchors, confidence = "other", {}, 0.50

        # 2d. DB insert
        item = ClothingItem(
            id=item_id,
            user_id=current_user.id,
            name=item_name,
            type=detected_type,
            processed_image_path=processed_path,
            detection_confidence=confidence,
            anchor_points=anchors,
        )
        db.add(item)

        # 2e. Schedule async metadata extraction (color, pattern, style, sub_type)
        background_tasks.add_task(extract_clothing_metadata, item_id, garment_bytes)

        # 2f. Build response entry (sign URL after commit)
        results.append((item, processed_path))

    if not results:
        raise HTTPException(
            status_code=422,
            detail="No garments could be extracted from the uploaded image. "
                   "Please upload a clear photo of clothing items.",
        )

    # 3. Commit all inserts in one transaction
    await db.commit()

    # 4. Refresh and sign URLs
    response_items: list[ClothingItemResponse] = []
    for item, processed_path in results:
        await db.refresh(item)
        processed_url = get_signed_url("clothing-processed", processed_path) or ""
        resp = ClothingItemResponse.model_validate(item)
        resp.processed_url = processed_url
        response_items.append(resp)

    return response_items
