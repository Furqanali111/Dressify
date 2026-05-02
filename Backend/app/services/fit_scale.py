from __future__ import annotations
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Avatar baseline measurements: (chest_cm, waist_cm, hip_cm, shoulder_cm)
_BASELINES: dict[str, tuple[float, float, float, float]] = {
    "femaleSlim":     (82.0,  62.0,  88.0,  36.0),
    "femaleAthletic": (88.0,  68.0,  90.0,  38.0),
    "femaleAverage":  (92.0,  72.0,  96.0,  38.0),
    "femaleCurvy":    (100.0, 80.0, 106.0,  40.0),
    "femalePlus":     (112.0, 92.0, 118.0,  42.0),
    "maleSlim":       (90.0,  76.0,  90.0,  40.0),
    "maleAthletic":   (100.0, 80.0,  96.0,  44.0),
    "maleAverage":    (96.0,  82.0,  96.0,  42.0),
    "maleCurvy":      (104.0, 90.0, 102.0,  44.0),
    "malePlus":       (114.0, 100.0, 112.0, 46.0),
}

_CLAMP_MIN = 0.80
_CLAMP_MAX = 1.20


def _clamp(v: float) -> float:
    return max(_CLAMP_MIN, min(_CLAMP_MAX, v))


def _avg(*values: Optional[float]) -> Optional[float]:
    valid = [v for v in values if v is not None]
    return sum(valid) / len(valid) if valid else None


def compute_fit_scales(
    avatar_kind: Optional[str],
    chest_cm: Optional[float],
    waist_cm: Optional[float],
    hip_cm: Optional[float],
    shoulder_cm: Optional[float],
) -> tuple[float, float, float]:
    """Return (scale_top, scale_bottom, scale_dress), clamped to [0.80, 1.20].

    Falls back to 1.0 when measurements or baseline are absent.
    scale_top    — applies to tops and jackets (driven by chest + shoulder)
    scale_bottom — applies to bottoms (driven by waist + hip)
    scale_dress  — average of top and bottom
    """
    has_any = any(v is not None for v in (chest_cm, waist_cm, hip_cm, shoulder_cm))
    if not has_any:
        return (1.0, 1.0, 1.0)

    baseline = _BASELINES.get(avatar_kind or "")
    if baseline is None:
        logger.warning("Unknown avatar_kind %r — falling back to 1.0 scales", avatar_kind)
        return (1.0, 1.0, 1.0)

    base_chest, base_waist, base_hip, base_shoulder = baseline

    r_chest    = chest_cm    / base_chest    if chest_cm    is not None else None
    r_waist    = waist_cm    / base_waist    if waist_cm    is not None else None
    r_hip      = hip_cm      / base_hip      if hip_cm      is not None else None
    r_shoulder = shoulder_cm / base_shoulder if shoulder_cm is not None else None

    raw_top    = _avg(r_chest, r_shoulder)
    raw_bottom = _avg(r_waist, r_hip)
    raw_dress  = _avg(raw_top, raw_bottom)

    scale_top    = _clamp(raw_top)    if raw_top    is not None else 1.0
    scale_bottom = _clamp(raw_bottom) if raw_bottom is not None else 1.0
    scale_dress  = _clamp(raw_dress)  if raw_dress  is not None else 1.0

    return (scale_top, scale_bottom, scale_dress)
