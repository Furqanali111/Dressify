# Implementation Plan: Multi-Garment Upload

**Goal:** When a user uploads one photo (e.g. wearing a shirt and jeans), detect each individual garment, extract it as a clean transparent PNG, save each to Supabase storage, and return a list of ClothingItem records — one per garment. No raw image is ever saved.

**AI model:** Llama 3.2-vision via Ollama (free, self-hosted). Falls back gracefully if detection fails.

**Approach:** AI-first (Option A) — Llama 3.2 vision identifies each garment and its bounding box in the image → we crop each garment → apply `u2net_cloth_seg` per crop for clean extraction → run metadata AI per garment → insert DB record per garment.

---

## Files to Change

| File | Change Type | Status |
|------|-------------|--------|
| `Backend/app/services/image_processing.py` | Rewrite | ✅ Done |
| `Backend/app/routers/upload.py` | Rewrite | ✅ Done |
| `Frontend/lib/features/upload/upload_screen.dart` | Update | ✅ Done |
| `Frontend/lib/core/providers/wardrobe_provider.dart` | Minor update | ✅ Done (no change needed — fetch() already returns list) |
| `PHASE2_3_PLAN.md` | Update (remove item 2.0.1) | ✅ Done |

---

## Step 1 — image_processing.py: Add garment detection

**Function:** `detect_garments_in_image(image_bytes: bytes) -> list[dict]`

- Base64-encode the image and send to Llama 3.2-vision via Ollama.
- Prompt asks the model to identify every visible clothing item and return normalized bounding boxes.
- Expected JSON response (example only — any clothing item type is accepted):
  ```json
  {
    "garments": [
      {"label": "bomber jacket", "bbox": {"x": 0.10, "y": 0.05, "w": 0.35, "h": 0.40}},
      {"label": "cargo pants",   "bbox": {"x": 0.08, "y": 0.45, "w": 0.38, "h": 0.50}},
      {"label": "sneakers",      "bbox": {"x": 0.12, "y": 0.88, "w": 0.32, "h": 0.10}}
    ]
  }
  ```
  Coordinates are normalized (0.0–1.0), origin top-left. No garment type constraint — the model names what it sees (saree, kurta, hoodie, coat, belt, etc.).
- **Fallback:** If the model fails or returns nothing valid, return a single entry covering the full image `{"label": "clothing", "bbox": {"x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0}}` so the upload still succeeds.
- Cap at 6 garments per upload to prevent excessive DB inserts (`_MAX_GARMENTS` constant — easy to raise).

**Status:** ⬜ Pending

---

## Step 2 — image_processing.py: Add garment extraction per bbox

**Function:** `extract_garment(image_bytes: bytes, bbox: dict, padding: float = 0.05) -> bytes`

- Open the image with Pillow.
- Convert normalized bbox → pixel coordinates, add `padding * min(w, h)` on all sides, clamp to image bounds.
- Crop the image to the padded bbox.
- Run `u2net_cloth_seg` rembg session on the crop to remove non-garment pixels.
- Return PNG bytes of the clean garment.

**Status:** ⬜ Pending

---

## Step 3 — image_processing.py: Remove old public remove_background()

- `remove_background()` is only called from `upload.py`. After the rewrite it is no longer needed as a public function.
- Keep `get_cloth_seg_session()` as an internal helper.
- `detect_type_and_anchors()` stays unchanged — it still runs per-garment after extraction.

**Status:** ⬜ Pending

---

## Step 4 — upload.py: Rewrite endpoint

**New flow:**
1. Validate image type and size (unchanged).
2. Call `detect_garments_in_image(image_bytes)` → `garments: list[dict]`.
3. For each garment in `garments`:
   a. Call `extract_garment(image_bytes, garment["bbox"])` → `garment_bytes: bytes`.
   b. Generate a new `item_id = uuid.uuid4()`.
   c. `processed_path = f"{current_user.id}/{item_id}.png"`.
   d. `upload_file("clothing-processed", processed_path, garment_bytes, "image/png")` — no raw bucket.
   e. `detect_type_and_anchors(garment_bytes)` → `(detected_type, anchors, confidence)`.
   f. Insert `ClothingItem(...)` — no `raw_image_path`.
   g. Schedule `extract_clothing_metadata(item_id, garment_bytes)` background task.
   h. Build `ClothingItemResponse` with `processed_url`.
4. `await db.commit()` once after all inserts.
5. Return `list[ClothingItemResponse]`.

**Response model change:** `response_model=list[ClothingItemResponse]`

**Removed:** all `raw_path`, `raw_url`, `"clothing-raw"` bucket calls.

**Status:** ⬜ Pending

---

## Step 5 — upload_screen.dart: Handle list response

**Current:** expects a single `ClothingItem` from `POST /upload`, navigates to try-on with that item.

**New:**
- Parse response as `List<ClothingItem>`.
- If 1 item: same UX as before (show item, offer try-on).
- If 2+ items: show a summary card — "X items extracted" with a small grid of item type icons → "Go to Wardrobe" button that navigates to the wardrobe tab.
- On any upload completion, call `ref.read(wardrobeProvider.notifier).fetch()` to refresh the list.

**Status:** ⬜ Pending

---

## Step 6 — wardrobe_provider.dart: Minor check

- Confirm `fetch()` already handles a list (it does — returns `List<ClothingItem>`). No functional change needed.
- Possibly add a `addAll(List<ClothingItem> items)` helper to avoid a full re-fetch (optional optimisation).

**Status:** ⬜ Pending

---

## Step 7 — Update PHASE2_3_PLAN.md

- Remove blocker 2.0.1 (raw_image_path missing) — resolved by this implementation (column was never in the model).
- Add a note that multi-garment upload was delivered as part of the pre-Phase-2 upload rework.

**Status:** ⬜ Pending

---

## Risk & Fallbacks

| Risk | Mitigation |
|------|-----------|
| Llama 3.2-vision fails / returns bad JSON | Fallback to full-image single-item mode |
| u2net_cloth_seg OOM on large image | Resize image to max 1024px before segmentation |
| Garment bbox too small / inaccurate | Clamp bbox to at least 20% of image dimension |
| All garment extractions fail for an image | Return HTTP 422 with message "No garments could be extracted" |
| Ollama not running | Caught by existing `APIConnectionError` handler; fallback to full-image mode |
