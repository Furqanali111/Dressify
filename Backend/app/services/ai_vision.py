import base64
import json
import logging
from uuid import UUID
from openai import OpenAI
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db import AsyncSessionLocal
from app.config import settings
from app.models.clothing_item import ClothingItem

logger = logging.getLogger(__name__)

def encode_image_to_base64(image_bytes: bytes) -> str:
    return base64.b64encode(image_bytes).decode('utf-8')

async def extract_clothing_metadata(item_id: UUID, image_bytes: bytes):
    """
    Background task to extract clothing metadata using Llama 3.2 Vision and save it to the database.
    We create a fresh DB session here because the request's session is already closed.
    """
    try:
        base64_image = encode_image_to_base64(image_bytes)
        
        # Determine client and model
        if settings.OPENAI_API_KEY:
            client = OpenAI(api_key=settings.OPENAI_API_KEY)
            model = "gpt-4o-mini"
        else:
            client = OpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
            model = "llama3.2-vision"
            
        prompt = """
        You are an AI fashion expert. Analyze this image of a clothing item.
        Respond strictly with a JSON object matching this schema:
        {
            "color": "primary color of the item (e.g., navy blue, red)",
            "pattern": "pattern on the item (e.g., solid, striped, floral, graphic print)",
            "style": "style or vibe (e.g., casual, formal, vintage, sporty)",
            "sub_type": "specific type of clothing (e.g., polo T-shirt, zipper hoodie, cargo pants, bomber jacket)"
        }
        """

        response = client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
            max_tokens=150
        )
        
        content = response.choices[0].message.content
        metadata = json.loads(content)
        
        # Save to DB
        async with AsyncSessionLocal() as session:
            result = await session.execute(select(ClothingItem).where(ClothingItem.id == item_id))
            item = result.scalar_one_or_none()
            if item:
                item.color = metadata.get("color")
                item.pattern = metadata.get("pattern")
                item.style = metadata.get("style")
                item.sub_type = metadata.get("sub_type")
                item.processing_status = "completed"
                await session.commit()
                logger.info(f"Successfully extracted and saved metadata for item {item_id}")
            else:
                logger.error(f"Item {item_id} not found in DB when trying to save metadata")
                
    except Exception as e:
        logger.error(f"Failed to extract clothing metadata in background task: {e}")
        # Mark as failed in DB
        async with AsyncSessionLocal() as session:
            result = await session.execute(select(ClothingItem).where(ClothingItem.id == item_id))
            item = result.scalar_one_or_none()
            if item:
                item.processing_status = "failed"
                await session.commit()
