"""
Quick local test for background removal.

Usage (from Backend/ with venv active):
    python test_rembg.py path/to/shirt_photo.jpg

Outputs:  output_rembg.png  (the cleaned, auto-cropped result)
"""
import sys
import io
import numpy as np
from PIL import Image, ImageFilter
from rembg import new_session, remove

MODEL  = "birefnet-general"
KERNEL = 41
TRIM_MARGIN    = 0.20
TRIM_THRESHOLD = 100.0


def _resize(img: Image.Image, max_px: int = 1024) -> Image.Image:
    w, h = img.size
    if max(w, h) <= max_px:
        return img
    scale = max_px / max(w, h)
    return img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)


def _clean_alpha(result: Image.Image, kernel: int = KERNEL) -> Image.Image:
    r, g, b, a = result.split()
    a = a.filter(ImageFilter.MinFilter(size=kernel))
    a = a.filter(ImageFilter.MaxFilter(size=kernel))
    return Image.merge("RGBA", (r, g, b, a))


def _trim_bottom_outliers(result: Image.Image) -> Image.Image:
    arr   = np.array(result).astype(np.float32)
    alpha = arr[:, :, 3]
    rgb   = arr[:, :, :3]
    h, w  = alpha.shape
    opaque = alpha > 127
    if not opaque.any():
        return result
    cy   = h // 2
    band = max(1, h // 6)
    cm   = opaque[max(0, cy - band): cy + band]
    cr   = rgb[max(0, cy - band): cy + band]
    if not cm.any():
        return result
    ref  = cr[cm].mean(axis=0)
    scan = max(4, int(h * TRIM_MARGIN))
    bottom = h
    for i in range(h - 1, max(h - scan - 1, 0), -1):
        row_mask = opaque[i]
        if not row_mask.any():
            continue
        dist = float(np.sqrt(np.sum((rgb[i][row_mask].mean(axis=0) - ref) ** 2)))
        if dist > TRIM_THRESHOLD:
            bottom = i
        else:
            break
    if bottom < h:
        print(f"  Trimmed {h - bottom} outlier row(s) from bottom")
        result = result.crop((0, 0, w, bottom))
    return result


def process(path: str) -> None:
    print(f"Loading {path} …")
    with open(path, "rb") as f:
        raw = f.read()

    img = Image.open(io.BytesIO(raw)).convert("RGB")
    print(f"  Original size : {img.size}")

    region = _resize(img)
    print(f"  Resized to    : {region.size}")

    print(f"  Loading rembg model '{MODEL}' …")
    session = new_session(MODEL)

    print("  Running background removal …")
    result = remove(region, session=session)
    print(f"  rembg output  : {result.size}")

    alpha0 = np.array(result)[:, :, 3]
    print(f"  Opaque before clean : {(alpha0 > 127).mean()*100:.1f}%")

    result = _clean_alpha(result)
    alpha1 = np.array(result)[:, :, 3]
    print(f"  Opaque after  clean : {(alpha1 > 127).mean()*100:.1f}%")

    result = _trim_bottom_outliers(result)

    # Auto-crop
    alpha2 = np.array(result)[:, :, 3]
    rows = np.any(alpha2 > 127, axis=1)
    cols = np.any(alpha2 > 127, axis=0)
    if rows.any() and cols.any():
        rmin, rmax = int(np.where(rows)[0][0]), int(np.where(rows)[0][-1])
        cmin, cmax = int(np.where(cols)[0][0]), int(np.where(cols)[0][-1])
        px = max(4, int(result.width  * 0.02))
        py = max(4, int(result.height * 0.02))
        result = result.crop((
            max(0, cmin - px), max(0, rmin - py),
            min(result.width, cmax + px + 1), min(result.height, rmax + py + 1),
        ))
        print(f"  Auto-cropped to : {result.size}")

    out_path = "output_rembg.png"
    result.save(out_path, format="PNG")
    print(f"\nSaved → {out_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_rembg.py <image_path>")
        sys.exit(1)
    process(sys.argv[1])
