"""
Procedural wrinkle map generation.

Generates 8 pose-conditioned greyscale PNGs (128×192 px) per garment at upload
time. Each map represents fold/shadow intensity for one canonical body pose.
At runtime, the camera try-on painter blends the matched map onto the warped
garment via BlendMode.multiply at 35% opacity.

No Blender or cloth simulation required — gaussian-ellipse zones tuned per pose
produce perceptually plausible fabric folds for standard try-on use.
"""

import io
import logging

import numpy as np
from PIL import Image, ImageFilter

from app.config import settings

logger = logging.getLogger(__name__)

CANONICAL_POSES = [
    "arms_down",
    "arms_45",
    "arms_90",
    "lean_left_15",
    "lean_right_15",
    "seated",
    "one_arm_raised",
    "crossed_arms",
]

_W, _H = 128, 192  # output size in pixels

# ---------------------------------------------------------------------------
# Zone definitions
# ---------------------------------------------------------------------------
# Each zone: (cx, cy, sigma_x, sigma_y, intensity)
#   cx, cy     — ellipse centre, normalized 0-1 (0,0 = top-left)
#   sigma_x/y  — gaussian spread, normalized to image dimensions
#   intensity  — peak brightness weight 0-1

# Top / jacket / dress zones — wrinkles cluster at chest, axilla, waist
_TOP_ZONES: dict[str, list[tuple]] = {
    "arms_down": [
        (0.50, 0.32, 0.22, 0.025, 0.55),  # horizontal chest fold
        (0.50, 0.55, 0.18, 0.025, 0.35),  # waist fold
        (0.16, 0.40, 0.06, 0.090, 0.30),  # left side drape
        (0.84, 0.40, 0.06, 0.090, 0.30),  # right side drape
    ],
    "arms_45": [
        (0.14, 0.27, 0.11, 0.080, 0.65),  # left axilla diagonal
        (0.86, 0.27, 0.11, 0.080, 0.65),  # right axilla diagonal
        (0.50, 0.38, 0.20, 0.040, 0.40),  # chest fold
        (0.18, 0.46, 0.05, 0.130, 0.35),  # left sleeve seam
        (0.82, 0.46, 0.05, 0.130, 0.35),  # right sleeve seam
    ],
    "arms_90": [
        (0.10, 0.25, 0.10, 0.130, 0.80),  # left axilla strong
        (0.90, 0.25, 0.10, 0.130, 0.80),  # right axilla strong
        (0.50, 0.28, 0.32, 0.050, 0.55),  # horizontal chest tension
        (0.20, 0.40, 0.07, 0.110, 0.45),  # left side tension
        (0.80, 0.40, 0.07, 0.110, 0.45),  # right side tension
    ],
    "lean_left_15": [
        (0.73, 0.36, 0.16, 0.230, 0.70),  # right side compression
        (0.83, 0.57, 0.11, 0.140, 0.55),  # right lower compression
        (0.20, 0.30, 0.11, 0.180, 0.30),  # left tension (stretch)
        (0.50, 0.46, 0.24, 0.040, 0.35),  # mild waist pull
    ],
    "lean_right_15": [
        (0.27, 0.36, 0.16, 0.230, 0.70),  # left side compression
        (0.17, 0.57, 0.11, 0.140, 0.55),  # left lower compression
        (0.80, 0.30, 0.11, 0.180, 0.30),  # right tension
        (0.50, 0.46, 0.24, 0.040, 0.35),  # mild waist pull
    ],
    "seated": [
        (0.50, 0.58, 0.34, 0.050, 0.78),  # main waist fold
        (0.50, 0.65, 0.28, 0.040, 0.62),  # secondary waist fold
        (0.30, 0.53, 0.11, 0.070, 0.50),  # left hip bunching
        (0.70, 0.53, 0.11, 0.070, 0.50),  # right hip bunching
        (0.50, 0.35, 0.20, 0.040, 0.28),  # chest relaxed
    ],
    "one_arm_raised": [
        (0.12, 0.21, 0.11, 0.160, 0.82),  # left axilla/shoulder strong
        (0.15, 0.39, 0.07, 0.180, 0.62),  # left side tension
        (0.83, 0.29, 0.07, 0.090, 0.35),  # right side mild
        (0.50, 0.30, 0.21, 0.040, 0.40),  # chest diagonal tension
        (0.34, 0.43, 0.17, 0.050, 0.45),  # body pull-left wrinkle
    ],
    "crossed_arms": [
        (0.50, 0.32, 0.35, 0.060, 0.82),  # strong horizontal chest
        (0.35, 0.38, 0.14, 0.040, 0.65),  # left chest crease
        (0.65, 0.38, 0.14, 0.040, 0.65),  # right chest crease
        (0.24, 0.30, 0.09, 0.110, 0.55),  # left side bunching
        (0.76, 0.30, 0.09, 0.110, 0.55),  # right side bunching
        (0.50, 0.51, 0.20, 0.040, 0.32),  # waist relaxed
    ],
}

# Bottom garment zones — wrinkles cluster at waist, seat, inner thigh
_BOTTOM_ZONES: dict[str, list[tuple]] = {
    "arms_down": [
        (0.50, 0.08, 0.30, 0.040, 0.50),  # waistband pull
        (0.30, 0.25, 0.12, 0.080, 0.35),  # left hip crease
        (0.70, 0.25, 0.12, 0.080, 0.35),  # right hip crease
        (0.50, 0.50, 0.15, 0.050, 0.25),  # inseam tension
    ],
    "arms_45": [
        (0.50, 0.08, 0.30, 0.040, 0.50),
        (0.28, 0.22, 0.14, 0.090, 0.40),
        (0.72, 0.22, 0.14, 0.090, 0.40),
        (0.50, 0.45, 0.12, 0.060, 0.30),
    ],
    "arms_90": [
        (0.50, 0.08, 0.30, 0.040, 0.52),
        (0.25, 0.20, 0.14, 0.100, 0.45),
        (0.75, 0.20, 0.14, 0.100, 0.45),
        (0.50, 0.50, 0.12, 0.050, 0.28),
    ],
    "lean_left_15": [
        (0.50, 0.09, 0.28, 0.050, 0.55),
        (0.68, 0.28, 0.16, 0.180, 0.65),  # right thigh compression
        (0.25, 0.25, 0.10, 0.150, 0.30),  # left thigh tension
    ],
    "lean_right_15": [
        (0.50, 0.09, 0.28, 0.050, 0.55),
        (0.32, 0.28, 0.16, 0.180, 0.65),  # left thigh compression
        (0.75, 0.25, 0.10, 0.150, 0.30),  # right thigh tension
    ],
    "seated": [
        (0.50, 0.12, 0.35, 0.060, 0.78),  # strong waist compression
        (0.50, 0.22, 0.30, 0.050, 0.65),  # secondary waist fold
        (0.50, 0.40, 0.28, 0.050, 0.58),  # thigh compression line
        (0.25, 0.32, 0.12, 0.120, 0.50),  # left inner thigh
        (0.75, 0.32, 0.12, 0.120, 0.50),  # right inner thigh
        (0.50, 0.60, 0.20, 0.060, 0.40),  # knee area
    ],
    "one_arm_raised": [
        (0.50, 0.09, 0.30, 0.040, 0.52),
        (0.30, 0.24, 0.13, 0.090, 0.40),
        (0.70, 0.24, 0.13, 0.090, 0.35),
        (0.50, 0.48, 0.12, 0.050, 0.28),
    ],
    "crossed_arms": [
        (0.50, 0.09, 0.30, 0.040, 0.52),
        (0.30, 0.22, 0.12, 0.090, 0.38),
        (0.70, 0.22, 0.12, 0.090, 0.38),
        (0.50, 0.48, 0.12, 0.050, 0.28),
    ],
}


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def _render_zones(zones: list[tuple]) -> np.ndarray:
    """Render a list of gaussian zones into a (H, W) float32 array [0, 1]."""
    y_lin = np.linspace(0, 1, _H, dtype=np.float32)
    x_lin = np.linspace(0, 1, _W, dtype=np.float32)
    yy, xx = np.meshgrid(y_lin, x_lin, indexing="ij")  # (H, W)
    acc = np.zeros((_H, _W), dtype=np.float32)
    for cx, cy, sx, sy, intensity in zones:
        sx = max(sx, 1e-6)
        sy = max(sy, 1e-6)
        blob = intensity * np.exp(
            -0.5 * ((xx - cx) / sx) ** 2 - 0.5 * ((yy - cy) / sy) ** 2
        )
        acc += blob
    return acc


def _noise_layer(seed: int, strength: float = 0.10) -> np.ndarray:
    """Reproducible gaussian noise smoothed to fabric-texture scale."""
    rng = np.random.RandomState(seed & 0x7FFFFFFF)
    raw = rng.randn(_H, _W).astype(np.float32) * strength
    # Smooth to suppress single-pixel speckling
    img = Image.fromarray(
        np.clip(raw * 128 + 128, 0, 255).astype(np.uint8), mode="L"
    )
    img = img.filter(ImageFilter.GaussianBlur(radius=1.2))
    return (np.array(img, dtype=np.float32) - 128.0) / 128.0 * strength


def generate_wrinkle_map(garment_type: str, pose: str) -> bytes:
    """Return 128×192 greyscale PNG bytes for (garment_type, pose).

    Brighter pixels = stronger fold/shadow. Composited in Flutter via a
    ColorFilter that maps luminance directly to alpha (A' = opacity * R),
    so bright zone pixels produce a stronger dark overlay on the garment.
    """
    zone_table = _BOTTOM_ZONES if garment_type == "bottom" else _TOP_ZONES
    zones = zone_table.get(pose)
    if not zones:
        # Unknown pose — return neutral mid-grey (no fold detail)
        img = Image.new("L", (_W, _H), color=128)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()

    acc = _render_zones(zones)

    seed = hash(f"{garment_type}:{pose}")
    acc = acc + _noise_layer(seed, strength=0.09)
    acc = np.clip(acc, 0.0, 1.0)

    img = Image.fromarray((acc * 255).astype(np.uint8), mode="L")
    img = img.filter(ImageFilter.GaussianBlur(radius=1.5))

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def generate_and_upload_wrinkle_maps(
    garment_type: str,
    user_id: str,
    item_id: str,
) -> dict[str, str]:
    """Generate all 8 wrinkle maps and upload to clothing storage in parallel.

    Returns {pose: storage_path} for every successfully uploaded map.
    Partial success is acceptable — missing poses fall back to no wrinkle effect.
    Called synchronously from the background ARQ worker.
    """
    from concurrent.futures import ThreadPoolExecutor
    from app.services.storage import upload_file

    def _one(pose: str) -> tuple[str, str | None]:
        try:
            map_bytes = generate_wrinkle_map(garment_type, pose)
            path = f"wrinkle/{user_id}/{item_id}/{pose}.png"
            ok = upload_file(settings.CLOTHING_BUCKET, path, map_bytes, "image/png")
            if ok:
                return pose, path
            logger.warning("wrinkle upload failed: item=%s pose=%s", item_id, pose)
        except Exception as exc:
            logger.warning("wrinkle generation error: item=%s pose=%s: %s", item_id, pose, exc)
        return pose, None

    results: dict[str, str] = {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        for pose, path in pool.map(_one, CANONICAL_POSES):
            if path:
                results[pose] = path
    return results
