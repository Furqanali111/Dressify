# Dressify — Phase 1 Audit (Open Items)

> Last updated: 2026-04-26. Everything listed here is **not yet fixed** or implemented.

---

## 1. Backend

### 1.1 Test suite has no real assertions
**Directory:** [Backend/tests/](Backend/tests/)

The test files (`test_auth.py`, `test_upload.py`, `test_outfits.py`) exist but contain no real assertions or fixtures yet. Needs: pytest fixtures for DB + auth, at minimum one smoke test per endpoint, and CI integration.

### 1.2 Error Handling Improvements
**Files:** `Backend/app/routers/auth.py`, `Backend/app/routers/outfits.py`

- In `auth.py`, the `google_auth` endpoint has a broad `try...except Exception as e` that catches everything and returns `401 Unauthorized`. This could swallow database connectivity errors or other `500 Internal Server Errors`.
- In `outfits.py`, `generate_outfit` raises a `500 HTTPException` if the AI returns an empty list or invalid IDs. A fallback (e.g. rule-based outfit generation) could make it more robust.

---

## 2. Frontend

### 2.1 Missing "Style Tips" Screen
**File:** [Frontend/lib/features/feedback/ai_feedback_screen.dart](Frontend/lib/features/feedback/ai_feedback_screen.dart)

The dedicated "Style Tips" screen mentioned in the Phase 1 goals (`Project_Plan.md`) is currently just a placeholder that reads: "AI feedback rendered as a bottom sheet from Try-On. This route exists for deep-linking and a future full-page variant."

### 2.2 Unimplemented Notifications
**File:** [Frontend/lib/features/home/home_screen.dart](Frontend/lib/features/home/home_screen.dart)

The Home screen has a notification bell icon that shows a snackbar stating: "Notifications coming soon!".

### 2.3 Obsolete Naming
**File:** [Frontend/lib/core/mock/mock_data.dart](Frontend/lib/core/mock/mock_data.dart)

The `mock_data.dart` file no longer contains mock data; it only holds the `AvatarKind` and `ClothingType` enums and their UI extensions. It should be renamed to something like `enums.dart` or `models.dart` to avoid confusion.

---

## 3. Priority Order

| Priority | Item |
|---|---|
| 🔴 P1 | Build out the dedicated "Style Tips" screen in the frontend |
| 🟠 P2 | Fill out backend test assertions + CI |
| 🟡 P3 | Improve backend error handling (`auth.py` and AI fallbacks) |
| 🟢 P4 | Rename `mock_data.dart` and prepare notifications UI |
