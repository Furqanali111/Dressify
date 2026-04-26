import io
import json
import base64
import logging

from rembg import remove, new_session
from PIL import Image

logger = logging.getLogger(__name__)

# Anchor points per type (normalized 0..1 within garment image).
# Used as the garment's snap anchor when overlaying on the avatar canvas.
_TYPE_ANCHORS: dict[str, dict] = {
    "top":       {"shoulder": {"x": 0.5, "y": 0.15}, "chest": {"x": 0.5, "y": 0.38}},
    "jacket":    {"shoulder": {"x": 0.5, "y": 0.13}, "chest": {"x": 0.5, "y": 0.35}},
    "dress":     {"shoulder": {"x": 0.5, "y": 0.10}, "chest": {"x": 0.5, "y": 0.30}, "waist": {"x": 0.5, "y": 0.55}},
    "bottom":    {"waist":    {"x": 0.5, "y": 0.06}, "hip":   {"x": 0.5, "y": 0.20}},
    "shoes":     {"feet":     {"x": 0.5, "y": 0.08}},
    "accessory": {"chest":    {"x": 0.5, "y": 0.50}},
    "other":     {"chest":    {"x": 0.5, "y": 0.40}},
}

_VALID_TYPES = frozenset({"top", "bottom", "dress", "jacket", "shoes", "accessory", "other"})

# Initialize sessions lazily or globally
_cloth_seg_session = None

def get_cloth_seg_session():
    global _cloth_seg_session
    if _cloth_seg_session is None:
        _cloth_seg_session = new_session("u2net_cloth_seg")
    return _cloth_seg_session

def remove_background(image_bytes: bytes, use_cloth_seg: bool = False) -> bytes:
    try:
        input_image = Image.open(io.BytesIO(image_bytes))
        
        if use_cloth_seg:
            session = get_cloth_seg_session()
            output_image = remove(input_image, session=session)
        else:
            output_image = remove(input_image)
            
        img_byte_arr = io.BytesIO()
        output_image.save(img_byte_arr, format="PNG")
        return img_byte_arr.getvalue()
    except Exception as e:
        logger.error(f"Background removal failed: {e}")
        raise


async def detect_type_and_anchors(image_bytes: bytes) -> tuple[str, dict, float]:
    """Classify clothing type and estimate dynamic anchor points via vision AI."""
    detected_type = "other"
    dynamic_anchors = None
    
    try:
        vision_result = await _analyze_garment_with_vision(image_bytes)
        detected_type = vision_result.get("type", "other")
        dynamic_anchors = vision_result.get("anchors")
    except Exception as e:
        logger.warning(f"Clothing vision analysis failed, defaulting to 'other': {e}")

    # Fallback to hardcoded anchors if AI failed to return valid ones
    if not dynamic_anchors or not isinstance(dynamic_anchors, dict):
        anchors = _TYPE_ANCHORS.get(detected_type, _TYPE_ANCHORS["other"])
    else:
        anchors = dynamic_anchors

    confidence = 0.85 if detected_type != "other" else 0.50
    return detected_type, anchors, confidence


async def _analyze_garment_with_vision(image_bytes: bytes) -> dict:
    from openai import AsyncOpenAI
    from app.config import settings

    b64 = base64.b64encode(image_bytes).decode("utf-8")

    if settings.OPENAI_API_KEY:
        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        model = "gpt-4o-mini"
    else:
        client = AsyncOpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = "llama3.2-vision"

    prompt = (
        "Analyze this clothing item image which has its background removed and cropped tightly to the garment. "
        "First, classify it into exactly one of these categories: top, bottom, dress, jacket, shoes, accessory, other. "
        "Second, estimate the normalized X and Y coordinates (between 0.0 and 1.0) for key anchor points needed to dress a 2D avatar. "
        "(0,0 is top-left, 1,1 is bottom-right). "
        "For example, a top needs 'shoulder' and 'chest' anchors. A bottom needs 'waist' and 'hip'. "
        'Reply strictly with a JSON object in this format: {"type": "<category>", "anchors": {"shoulder": {"x": 0.5, "y": 0.15}, ...}}.'
    )

    response = await client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/png;base64,{b64}"},
                    },
                ],
            }
        ],
        response_format={"type": "json_object"},
        temperature=0.1,
        max_tokens=100,
    )

    content = response.choices[0].message.content
    data = json.loads(content)
    
    detected_type = str(data.get("type", "other")).lower().strip()
    if detected_type not in _VALID_TYPES:
        detected_type = "other"
        
    return {
        "type": detected_type,
        "anchors": data.get("anchors")
    }
