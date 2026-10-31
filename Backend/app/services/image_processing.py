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
_rembg_lock = None  # initialized lazily to avoid issues with multiprocessing forks


def _get_rembg_lock():
    global _rembg_lock
    if _rembg_lock is None:
        import threading
        _rembg_lock = threading.Lock()
    return _rembg_lock


def _get_rembg_session():
    global _rembg_session
    if _rembg_session is not None:
        return _rembg_session
    with _get_rembg_lock():
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


def _clean_alpha(result: Image.Image, close_kernel: int = 11, open_kernel: int = 21) -> Image.Image:
    """Morphological closing then opening on the alpha channel.

    Closing (MaxFilter → MinFilter) fills interior holes — transparent gaps left
    by birefnet inside mesh fabric, buttons, or dark pattern patches.
    Opening (MinFilter → MaxFilter) removes exterior noise blobs around the garment.
    """
    r, g, b, a = result.split()
    # Closing: fill interior holes
    a = a.filter(ImageFilter.MaxFilter(size=close_kernel))
    a = a.filter(ImageFilter.MinFilter(size=close_kernel))
    # Opening: remove exterior artifact blobs
    a = a.filter(ImageFilter.MinFilter(size=open_kernel))
    a = a.filter(ImageFilter.MaxFilter(size=open_kernel))
    return Image.merge('RGBA', (r, g, b, a))


def _feather_alpha_edges(result: Image.Image, radius: float = 1.5) -> Image.Image:
    """Gaussian-blur the alpha channel to anti-alias garment edges.

    Hard binary alpha looks like a sticker in the live preview. A 1.5px blur
    creates a soft transition zone that blends naturally with the camera feed.
    RGB channels are untouched — only the alpha mask is smoothed.
    """
    r, g, b, a = result.split()
    a = a.filter(ImageFilter.GaussianBlur(radius=radius))
    return Image.merge('RGBA', (r, g, b, a))


def _normalize_white_balance(result: Image.Image) -> Image.Image:
    """Remove warm/cool lighting cast baked into the garment photo.

    Finds the median colour of the brightest 5% of opaque pixels and scales
    the RGB channels so the dominant highlight approaches neutral grey.
    Only applies when the channel imbalance exceeds 5% to avoid touching
    intentionally tinted garments (e.g. a warm-beige sweater).
    Correction is clamped to ±25% per channel to prevent over-whitening.
    """
    arr = np.array(result).astype(np.float32)
    alpha = arr[:, :, 3]
    rgb   = arr[:, :, :3]

    opaque_mask = alpha > 200
    if not opaque_mask.any():
        return result

    opaque_pixels = rgb[opaque_mask]
    luma = (0.2126 * opaque_pixels[:, 0]
            + 0.7152 * opaque_pixels[:, 1]
            + 0.0722 * opaque_pixels[:, 2])
    threshold = np.percentile(luma, 95)
    bright = opaque_pixels[luma >= threshold]

    if len(bright) < 10:
        return result

    ref = np.median(bright, axis=0)   # [R, G, B] of bright highlights
    peak = float(ref.max())
    if peak < 50:                      # too dark to reliably measure cast
        return result

    scale = peak / np.maximum(ref, 1.0)
    if float(np.max(np.abs(scale - 1.0))) < 0.05:
        return result                  # cast too small to bother correcting

    scale = np.clip(scale, 0.75, 1.25)
    corrected = np.clip(rgb * scale[np.newaxis, np.newaxis, :], 0, 255)
    out = arr.copy()
    out[:, :, :3] = corrected
    return Image.fromarray(out.astype(np.uint8), mode='RGBA')


def _ensure_min_resolution(result: Image.Image, min_long_side: int = 768) -> Image.Image:
    """Upscale to at least min_long_side px on the longest dimension.

    A tightly-cropped garment PNG can end up under 400px wide. Upscaling
    with LANCZOS prevents visible pixelation when the TPS warper stretches
    the image to fill the user's shoulder span on a high-DPI screen.
    """
    w, h = result.size
    if max(w, h) >= min_long_side:
        return result
    scale = min_long_side / max(w, h)
    return result.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)


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

        # 1. Fill interior holes (mesh, lace, buttons), then remove exterior blobs.
        result = _clean_alpha(result)

        # 2. Strip bottom rows whose colour strongly differs from the garment body
        #    (e.g. the mat or surface visible at the hem after rembg).
        result = _trim_bottom_outliers(result)

        # 3. Normalize white balance so the Flutter lighting filter works accurately.
        result = _normalize_white_balance(result)

        # 4. Auto-crop to a symmetric tight bounding box of remaining opaque pixels.
        #    Symmetric about the vertical centre axis prevents off-centre overlay
        #    when birefnet trims one shoulder slightly more than the other.
        alpha = np.array(result)[:, :, 3]
        rows = np.any(alpha > 127, axis=1)
        cols = np.any(alpha > 127, axis=0)

        if rows.any() and cols.any():
            rmin, rmax = int(np.where(rows)[0][0]),  int(np.where(rows)[0][-1])
            cmin, cmax = int(np.where(cols)[0][0]),  int(np.where(cols)[0][-1])

            # Force symmetric horizontal bounds around the garment centre.
            gcx  = (cmin + cmax) // 2
            half = max(cmax - gcx, gcx - cmin)
            cmin = max(0, gcx - half)
            cmax = min(result.width - 1, gcx + half)

            # 6% padding (was 2%) — gives TPS warper room at the garment boundary.
            px = max(6, int(result.width  * 0.06))
            py = max(6, int(result.height * 0.06))
            result = result.crop((
                max(0, cmin - px),
                max(0, rmin - py),
                min(result.width,  cmax + px + 1),
                min(result.height, rmax + py + 1),
            ))

        # 5. Upscale to at least 768px on the long side before feathering.
        result = _ensure_min_resolution(result)

        # 6. Feather alpha edges for smooth camera-feed blending.
        result = _feather_alpha_edges(result)

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


_VALID_SIZES = frozenset({"XS", "S", "M", "L", "XL", "XXL", "One Size", "Unknown"})
