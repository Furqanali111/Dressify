from __future__ import annotations
from typing import Optional, Literal

FitRating = Literal["perfect", "may_be_snug", "runs_large", "unknown"]

# Size label → estimated chest_cm range for women / men (mid-range used for comparison)
# Values represent the typical chest measurement (cm) someone wearing this size would have.
_SIZE_CHEST_RANGE: dict[str, tuple[float, float]] = {
    "XS":       (78.0,  84.0),
    "S":        (84.0,  90.0),
    "M":        (90.0,  96.0),
    "L":        (96.0, 104.0),
    "XL":      (104.0, 112.0),
    "XXL":     (112.0, 124.0),
    "One Size": (80.0, 116.0),
}

# Measurement used per garment type for the fit check
_TYPE_MEASUREMENT: dict[str, str] = {
    "top":    "chest",
    "jacket": "chest",
    "dress":  "chest",
    "bottom": "waist",
    "shoes":  "none",
}

# Waist size ranges (approx)
_SIZE_WAIST_RANGE: dict[str, tuple[float, float]] = {
    "XS":       (58.0,  64.0),
    "S":        (64.0,  70.0),
    "M":        (70.0,  76.0),
    "L":        (76.0,  84.0),
    "XL":       (84.0,  92.0),
    "XXL":      (92.0, 104.0),
    "One Size": (58.0, 104.0),
}


def compute_fit_rating(
    size_label: Optional[str],
    garment_type: str,
    chest_cm: Optional[float],
    waist_cm: Optional[float],
) -> dict:
    """Return {fit_rating, confidence}.

    fit_rating is one of: perfect, may_be_snug, runs_large, unknown.
    confidence is a float in [0.0, 1.0].
    """
    if not size_label or size_label == "Unknown":
        return {"fit_rating": "unknown", "confidence": 0.0}

    mtype = _TYPE_MEASUREMENT.get(garment_type, "none")
    if mtype == "none":
        return {"fit_rating": "unknown", "confidence": 0.0}

    if mtype == "chest":
        measurement = chest_cm
        ranges = _SIZE_CHEST_RANGE
    else:
        measurement = waist_cm
        ranges = _SIZE_WAIST_RANGE

    if measurement is None:
        return {"fit_rating": "unknown", "confidence": 0.0}

    size_range = ranges.get(size_label)
    if size_range is None:
        return {"fit_rating": "unknown", "confidence": 0.0}

    lo, hi = size_range
    mid = (lo + hi) / 2.0
    span = (hi - lo) / 2.0

    if lo <= measurement <= hi:
        # Within range — confidence rises toward 1.0 as measurement approaches mid
        closeness = 1.0 - abs(measurement - mid) / span
        return {"fit_rating": "perfect", "confidence": round(0.7 + 0.3 * closeness, 2)}
    elif measurement < lo:
        # User is smaller than this size — garment will run large
        diff_ratio = (lo - measurement) / span
        conf = round(min(0.95, 0.6 + 0.35 * diff_ratio), 2)
        return {"fit_rating": "runs_large", "confidence": conf}
    else:
        # User is larger than this size — garment may be snug
        diff_ratio = (measurement - hi) / span
        conf = round(min(0.95, 0.6 + 0.35 * diff_ratio), 2)
        return {"fit_rating": "may_be_snug", "confidence": conf}
