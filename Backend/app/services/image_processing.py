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

# Lazy-initialised background removal session (reused across requests).
# isnet-general-use handles real-world photos (coloured backgrounds, flat-lays,
# hangers, etc.) far better than u2net_cloth_seg, which only works reliably on
# e-commerce white-background product shots.
_seg_session = None


def _get_seg_session():
    global _seg_session
    if _seg_session is None:
        _seg_session = new_session("isnet-general-use")
    return _seg_session


def _resize_for_seg(img: Image.Image) -> Image.Image:
    """Downscale to _SEG_MAX_PX on the longest side, preserving aspect ratio."""
    w, h = img.size
    if max(w, h) <= _SEG_MAX_PX:
        return img
    scale = _SEG_MAX_PX / max(w, h)
    return img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)


# ---------------------------------------------------------------------------
# Step 1 — detect all garments in an image using Llama 3.2-vision
# ---------------------------------------------------------------------------

async def detect_and_analyze_garments(image_bytes: bytes) -> list[dict]:
    """Single Ollama call: detect every garment in the photo AND return full metadata.

    One call replaces the old detect_garments_in_image + analyze_garment_complete pair,
    cutting total Ollama calls per upload from 2 down to 1.

    Returns a list of dicts (one per garment):
        label, bbox, type, color, pattern, style, sub_type, size_label
    """
    from openai import AsyncOpenAI

    b64 = base64.b64encode(image_bytes).decode("utf-8")

    if settings.OPENAI_API_KEY:
        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        model = settings.OPENAI_API_MODEL
    else:
        client = AsyncOpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = settings.OLLAMA_VISION_MODEL

    prompt = (
        "You are a fashion AI expert. Identify every distinct clothing item in this photo.\n"
        "For EACH item return its bounding box AND full fashion metadata.\n"
        "Reply ONLY with a JSON object:\n"
        '{"garments": [{"label": "shirt", '
        '"bbox": {"x": 0.10, "y": 0.05, "w": 0.35, "h": 0.40}, '
        '"type": "<top|bottom|dress|jacket|shoes|accessory|other>", '
        '"color": "<primary color e.g. navy blue>", '
        '"pattern": "<solid|striped|plaid|floral|graphic|other>", '
        '"style": "<casual|formal|sporty|vintage|streetwear|other>", '
        '"sub_type": "<e.g. polo shirt, cargo pants>", '
        '"size_label": "<XS|S|M|L|XL|XXL|One Size|Unknown>"}]}\n'
        f"List at most {_MAX_GARMENTS} items. "
        "bbox coordinates are normalized 0.0–1.0 (origin top-left). "
        'If no clothing is visible return {"garments": []}.'
    )

    response = await client.chat.completions.create(
        model=model,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
            ],
        }],
        response_format={"type": "json_object"},
        temperature=0.1,
        max_tokens=500,
    )

    data = json.loads(response.choices[0].message.content or '{"garments": []}')
    raw_garments = data.get("garments", [])

    if not raw_garments:
        logger.info("detect_and_analyze_garments: no clothing found in image")
        return []

    validated: list[dict] = []
    for g in raw_garments:
        bbox = g.get("bbox", {})
        x = float(bbox.get("x", 0))
        y = float(bbox.get("y", 0))
        w = float(bbox.get("w", 1))
        h = float(bbox.get("h", 1))
        x, y = max(0.0, min(x, 1.0)), max(0.0, min(y, 1.0))
        w, h = max(0.05, min(w, 1.0 - x)), max(0.05, min(h, 1.0 - y))

        detected_type = str(g.get("type", "other")).lower().strip()
        if detected_type not in _VALID_TYPES:
            detected_type = "other"

        raw_size = g.get("size_label", "Unknown")
        size_label = raw_size if raw_size in _VALID_SIZES else "Unknown"

        validated.append({
            "label": str(g.get("label", "clothing")).strip().title(),
            "bbox": {"x": x, "y": y, "w": w, "h": h},
            "type": detected_type,
            "color": g.get("color"),
            "pattern": g.get("pattern"),
            "style": g.get("style"),
            "sub_type": g.get("sub_type"),
            "size_label": size_label,
        })

    return validated[:_MAX_GARMENTS]


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

    # Keep RGBA crop as fallback (used if rembg returns an empty/transparent result)
    fallback = io.BytesIO()
    crop_resized.save(fallback, format="PNG")

    # Convert to RGB for rembg input (RGBA causes issues with some rembg versions)
    crop_rgb = crop_resized.convert("RGB")
    crop_input = io.BytesIO()
    crop_rgb.save(crop_input, format="PNG")

    # Background removal — strips everything behind the garment
    try:
        session = _get_seg_session()
        result_bytes = remove(crop_input.getvalue(), session=session)

        # Validate: if rembg returned near-empty (fully transparent), fall back to plain crop.
        # u2net_cloth_seg struggles with real-world photos that have coloured backgrounds.
        if result_bytes:
            check = Image.open(io.BytesIO(result_bytes))
            if check.mode == "RGBA":
                visible = sum(1 for p in check.getchannel("A").getdata() if p > 10)
                if visible >= 200:
                    return result_bytes
        logger.warning("rembg returned near-empty result; using plain crop as fallback")
    except Exception as exc:
        logger.warning("rembg failed (%s); using plain crop as fallback", exc)

    return fallback.getvalue()


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
        model = settings.OPENAI_API_MODEL
    else:
        client = AsyncOpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = settings.OLLAMA_VISION_MODEL

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


_VALID_SIZES = frozenset({"XS", "S", "M", "L", "XL", "XXL", "One Size", "Unknown"})


async def analyze_garment_complete(image_bytes: bytes) -> dict:
    """Single Ollama call replacing detect_type_and_anchors + extract_metadata_job.

    Returns type, anchors, color, pattern, style, sub_type, size_label in one shot.
    """
    from openai import AsyncOpenAI

    b64 = base64.b64encode(image_bytes).decode("utf-8")

    if settings.OPENAI_API_KEY:
        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        model = settings.OPENAI_API_MODEL
    else:
        client = AsyncOpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = settings.OLLAMA_VISION_MODEL

    prompt = (
        "You are a fashion AI. Analyze this background-removed clothing item image.\n"
        "Return ONLY a JSON object with exactly these keys:\n"
        '{"type":"<top|bottom|dress|jacket|shoes|accessory|other>",'
        '"anchors":{"<key>":{"x":0.5,"y":0.15}},'
        '"color":"<primary color e.g. navy blue>",'
        '"pattern":"<solid|striped|plaid|floral|graphic|other>",'
        '"style":"<casual|formal|sporty|vintage|streetwear|other>",'
        '"sub_type":"<specific item e.g. polo shirt, cargo pants>",'
        '"size_label":"<XS|S|M|L|XL|XXL|One Size|Unknown>"}\n'
        "Anchor keys by type — top/jacket: shoulder+chest; dress: shoulder+chest+waist; "
        "bottom: waist+hip; shoes: feet; accessory/other: chest. "
        "Coordinates normalized 0.0–1.0 from top-left."
    )

    try:
        response = await client.chat.completions.create(
            model=model,
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
                ],
            }],
            response_format={"type": "json_object"},
            temperature=0.1,
            max_tokens=200,
        )
        raw = json.loads(response.choices[0].message.content or "{}")
        detected_type = str(raw.get("type", "other")).lower().strip()
        if detected_type not in _VALID_TYPES:
            detected_type = "other"
        raw["type"] = detected_type
        raw_size = raw.get("size_label", "Unknown")
        raw["size_label"] = raw_size if raw_size in _VALID_SIZES else "Unknown"
        return raw
    except Exception as exc:
        logger.warning("analyze_garment_complete failed: %s", exc)
        return {}
