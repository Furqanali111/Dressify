import base64
import io
import json
import logging

from PIL import Image
from rembg import remove, new_session

from app.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Anchor points per type (normalized 0..1 within the garment image).
# ---------------------------------------------------------------------------
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

_MAX_GARMENTS = 6
_SEG_MAX_PX = 1024  # resize before u2net to avoid OOM

# Lazy-initialised cloth segmentation session (reused across requests).
_cloth_seg_session = None


def _get_cloth_seg_session():
    global _cloth_seg_session
    if _cloth_seg_session is None:
        _cloth_seg_session = new_session("u2net_cloth_seg")
    return _cloth_seg_session


def _resize_for_seg(img: Image.Image) -> Image.Image:
    """Downscale to _SEG_MAX_PX on the longest side, preserving aspect ratio."""
    w, h = img.size
    if max(w, h) <= _SEG_MAX_PX:
        return img
    scale = _SEG_MAX_PX / max(w, h)
    return img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)


# ---------------------------------------------------------------------------
# Step 1 — detect all garments in an image using Llama 3.2-vision
# ---------------------------------------------------------------------------

async def detect_garments_in_image(image_bytes: bytes) -> list[dict]:
    """
    Ask Llama 3.2-vision to locate every clothing item in the image.

    Returns a list of dicts:
        [{"label": "shirt", "bbox": {"x": 0.10, "y": 0.05, "w": 0.35, "h": 0.40}}, ...]

    Coordinates are normalized (0.0–1.0), origin top-left.
    Falls back to a single full-image entry if the model is unavailable or returns
    unparseable output.
    """
    _FULL_IMAGE_FALLBACK = [{"label": "clothing", "bbox": {"x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0}}]

    try:
        from openai import AsyncOpenAI, APIConnectionError, APITimeoutError

        b64 = base64.b64encode(image_bytes).decode("utf-8")

        # Always use Ollama/Llama for garment detection (free, local)
        client = AsyncOpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = "llama3.2-vision"

        prompt = (
            "You are a computer vision assistant specialized in fashion. "
            "Look at this photo and identify every distinct clothing item visible on the person. "
            "For each item, return its common name and its bounding box as normalized coordinates "
            "(x, y = top-left corner; w, h = width and height; all values between 0.0 and 1.0). "
            "Reply ONLY with a JSON object in exactly this format:\n"
            '{"garments": [{"label": "shirt", "bbox": {"x": 0.10, "y": 0.05, "w": 0.35, "h": 0.40}}, ...]}\n'
            f"List at most {_MAX_GARMENTS} items. If no clothing is visible return an empty garments array."
        )

        response = await client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                    ],
                }
            ],
            response_format={"type": "json_object"},
            temperature=0.1,
            max_tokens=300,
        )

        data = json.loads(response.choices[0].message.content)
        garments = data.get("garments", [])

        validated: list[dict] = []
        for g in garments:
            bbox = g.get("bbox", {})
            x, y, w, h = (
                float(bbox.get("x", 0)),
                float(bbox.get("y", 0)),
                float(bbox.get("w", 1)),
                float(bbox.get("h", 1)),
            )
            # Clamp to valid range; skip degenerate boxes
            x, y = max(0.0, min(x, 1.0)), max(0.0, min(y, 1.0))
            w, h = max(0.05, min(w, 1.0 - x)), max(0.05, min(h, 1.0 - y))
            validated.append({"label": str(g.get("label", "clothing")), "bbox": {"x": x, "y": y, "w": w, "h": h}})

        if not validated:
            logger.warning("Garment detection returned no items — using full-image fallback")
            return _FULL_IMAGE_FALLBACK

        return validated[:_MAX_GARMENTS]

    except Exception as e:
        logger.warning(f"Garment detection failed ({type(e).__name__}: {e}) — using full-image fallback")
        return _FULL_IMAGE_FALLBACK


# ---------------------------------------------------------------------------
# Step 2 — extract a single garment from the image using its bbox
# ---------------------------------------------------------------------------

def extract_garment(image_bytes: bytes, bbox: dict, padding: float = 0.05) -> bytes:
    """
    Crop the image to the given normalized bbox (with padding), then apply
    u2net_cloth_seg to remove the non-garment background.

    Returns PNG bytes of the clean garment on a transparent background.
    """
    img = Image.open(io.BytesIO(image_bytes)).convert("RGBA")
    iw, ih = img.size

    x = bbox["x"]
    y = bbox["y"]
    w = bbox["w"]
    h = bbox["h"]

    # Add padding, clamp to image bounds
    pad_x = padding * iw
    pad_y = padding * ih
    left  = max(0, int(x * iw - pad_x))
    top   = max(0, int(y * ih - pad_y))
    right = min(iw, int((x + w) * iw + pad_x))
    bottom = min(ih, int((y + h) * ih + pad_y))

    crop = img.crop((left, top, right, bottom))
    crop_resized = _resize_for_seg(crop)

    # Convert to RGB for rembg input (RGBA causes issues with some rembg versions)
    crop_rgb = crop_resized.convert("RGB")
    crop_bytes = io.BytesIO()
    crop_rgb.save(crop_bytes, format="PNG")

    # Cloth segmentation — removes everything that isn't a garment
    session = _get_cloth_seg_session()
    result_bytes = remove(crop_bytes.getvalue(), session=session)

    return result_bytes


# ---------------------------------------------------------------------------
# Step 3 — classify type + compute anchor points for an extracted garment
# ---------------------------------------------------------------------------

async def detect_type_and_anchors(image_bytes: bytes) -> tuple[str, dict, float]:
    """Classify clothing type and estimate anchor points via Llama 3.2-vision."""
    detected_type = "other"
    dynamic_anchors = None

    try:
        vision_result = await _analyze_garment_with_vision(image_bytes)
        detected_type = vision_result.get("type", "other")
        dynamic_anchors = vision_result.get("anchors")
    except Exception as e:
        logger.warning(f"Garment vision analysis failed, defaulting to 'other': {e}")

    if not dynamic_anchors or not isinstance(dynamic_anchors, dict):
        anchors = _TYPE_ANCHORS.get(detected_type, _TYPE_ANCHORS["other"])
    else:
        anchors = dynamic_anchors

    confidence = 0.85 if detected_type != "other" else 0.50
    return detected_type, anchors, confidence


async def _analyze_garment_with_vision(image_bytes: bytes) -> dict:
    from openai import AsyncOpenAI

    b64 = base64.b64encode(image_bytes).decode("utf-8")

    if settings.OPENAI_API_KEY:
        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        model = "gpt-4o-mini"
    else:
        client = AsyncOpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = "llama3.2-vision"

    prompt = (
        "Analyze this clothing item image which has its background removed and is cropped tightly to the garment. "
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
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
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

    return {"type": detected_type, "anchors": data.get("anchors")}
