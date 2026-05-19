import base64
import io
import json
import logging

import numpy as np
from PIL import Image, ImageFilter
from rembg import new_session, remove

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
_CROP_MAX_PX = 1024  # max dimension for the saved crop

# BiRefNet-general: transformer-based model, state-of-the-art accuracy, correctly
# handles clothing of any colour including dark garments (unlike isnet-general-use
# which treats dark clothing as background, and unlike u2net_cloth_seg which
# produces 3 stacked segmentation masks instead of a standard RGBA output).
_REMBG_MODEL = "birefnet-general"
_rembg_session = None


def _get_rembg_session():
    global _rembg_session
    if _rembg_session is None:
        _rembg_session = new_session(_REMBG_MODEL)
        logger.info("Loaded rembg model: %s", _REMBG_MODEL)
    return _rembg_session

def _resize_for_seg(img: Image.Image) -> Image.Image:
    """Downscale to _CROP_MAX_PX on the longest side, preserving aspect ratio."""
    w, h = img.size
    if max(w, h) <= _CROP_MAX_PX:
        return img
    scale = _CROP_MAX_PX / max(w, h)
    return img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)


def _clean_alpha(result: Image.Image, kernel: int = 21) -> Image.Image:
    """Morphological opening on the alpha channel: removes isolated noise blobs.

    Erosion (MinFilter) kills pixels whose neighbors are all transparent — this
    eliminates small artifact blobs left by rembg.  Dilation (MaxFilter) restores
    the main garment shape which, being a large connected region, survives erosion.
    """
    r, g, b, a = result.split()
    a = a.filter(ImageFilter.MinFilter(size=kernel))  # shrink small blobs to zero
    a = a.filter(ImageFilter.MaxFilter(size=kernel))  # grow the surviving garment back
    return Image.merge('RGBA', (r, g, b, a))


def _trim_bottom_outliers(result: Image.Image, margin: float = 0.20, threshold: float = 100.0) -> Image.Image:
    """Remove rows at the BOTTOM of the result whose color strongly differs from
    the garment body color (e.g. the mat/surface showing at the hem).

    Works by comparing each bottom row's mean opaque-pixel color against a
    reference sampled from the vertical centre of the image.  Rows with colour
    distance > threshold (Euclidean in RGB) are stripped, scanning inward until
    a row that matches the garment colour is found.
    """
    arr = np.array(result).astype(np.float32)
    alpha = arr[:, :, 3]
    rgb   = arr[:, :, :3]
    h, w  = alpha.shape

    opaque = alpha > 127
    if not opaque.any():
        return result

    # Reference colour from the vertical centre band (avoids edge-noise bias).
    cy   = h // 2
    band = max(1, h // 6)
    centre_mask = opaque[max(0, cy - band): cy + band]
    centre_rgb  = rgb[max(0, cy - band): cy + band]
    if not centre_mask.any():
        return result
    ref = centre_rgb[centre_mask].mean(axis=0)   # [R, G, B]

    scan   = max(4, int(h * margin))
    bottom = h   # exclusive end — start assuming no trim needed

    for i in range(h - 1, max(h - scan - 1, 0), -1):
        row_mask = opaque[i]
        if not row_mask.any():
            continue   # transparent row — skip, keep scanning
        mean_col = rgb[i][row_mask].mean(axis=0)
        dist     = float(np.sqrt(np.sum((mean_col - ref) ** 2)))
        if dist > threshold:
            bottom = i   # outlier row — mark for removal
        else:
            break        # first matching row from the bottom — stop

    if bottom < h:
        logger.debug("_trim_bottom_outliers: removed %d outlier row(s) from bottom", h - bottom)
        result = result.crop((0, 0, w, bottom))

    return result


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

def extract_garment(image_bytes: bytes, bbox: dict, num_garments: int = 1) -> bytes:
    """Extract a single garment, remove its background, and return a tight PNG.

    Strategy differs by photo type:
    - Single garment (num_garments == 1): run rembg on the FULL image so Ollama's
      (often inaccurate) bbox doesn't crop off part of the garment. Then auto-crop
      to the bounding box of opaque pixels, giving a tight, clean PNG.
    - Multiple garments: use Ollama's bbox + 15% padding to separate items, then
      apply rembg + auto-crop on that region.

    Falls back to a JPEG crop of the relevant region if rembg fails or produces
    less than 8% opaque pixels (segmentation failure).
    """
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    iw, ih = img.size

    if num_garments == 1:
        # Full image — let rembg find and isolate the garment without bbox bias.
        region = _resize_for_seg(img)
    else:
        # Tight per-item crop to avoid bleeding into adjacent garments.
        x, y, w, h = bbox["x"], bbox["y"], bbox["w"], bbox["h"]
        expand = 0.15
        left   = max(0, int((x - expand) * iw))
        top    = max(0, int((y - expand) * ih))
        right  = min(iw, int((x + w + expand) * iw))
        bottom = min(ih, int((y + h + expand) * ih))
        region = _resize_for_seg(img.crop((left, top, right, bottom)))

    try:
        result = remove(region, session=_get_rembg_session())  # RGBA PIL Image

        # Sanity-check: some models (e.g. u2net_cloth_seg) produce stacked
        # multi-class masks with 3× the input height. Reject those.
        if result.size != region.size:
            raise ValueError(
                f"rembg returned unexpected size {result.size} vs input {region.size}"
            )

        # 1. Remove isolated artifact blobs via morphological opening.
        result = _clean_alpha(result, kernel=41)

        # 2. Strip bottom rows whose colour strongly differs from the garment body
        #    (e.g. the mat or surface visible at the hem after rembg).
        result = _trim_bottom_outliers(result)

        # 3. Auto-crop to the tight bounding box of remaining opaque pixels.
        alpha = np.array(result)[:, :, 3]
        rows = np.any(alpha > 127, axis=1)
        cols = np.any(alpha > 127, axis=0)

        if rows.any() and cols.any():
            rmin, rmax = int(np.where(rows)[0][0]),  int(np.where(rows)[0][-1])
            cmin, cmax = int(np.where(cols)[0][0]),  int(np.where(cols)[0][-1])
            px = max(4, int(result.width  * 0.02))
            py = max(4, int(result.height * 0.02))
            result = result.crop((
                max(0, cmin - px),
                max(0, rmin - py),
                min(result.width,  cmax + px + 1),
                min(result.height, rmax + py + 1),
            ))

        opaque_ratio = float((np.array(result)[:, :, 3] > 127).mean())
        if opaque_ratio >= 0.08:
            out = io.BytesIO()
            result.save(out, format="PNG")
            return out.getvalue()

        logger.warning(
            "extract_garment: u2net_cloth_seg kept only %.1f%% opaque pixels "
            "(below 8%% threshold) — falling back to JPEG crop",
            opaque_ratio * 100,
        )
    except Exception as exc:
        logger.warning("extract_garment: rembg failed (%s) — falling back to JPEG crop", exc)

    out = io.BytesIO()
    region.save(out, format="JPEG", quality=88)
    return out.getvalue()


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
