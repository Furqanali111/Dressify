# Dressify — Codebase Analysis: Improvements 5

> Generated: 2026-05-02
> Deep-dive across all backend routers, services, and frontend features after Phase 4 improvements.

---

## 1. Security Risk: Bypass Auth Hardcoded Token in Production Code (`auth.py`) — (ignored for now)

*   **File:** `app/routers/auth.py` line 31
*   **Issue:** The dev bypass token `"BYPASS_AUTH_FURQAN_54321"` is a **hardcoded string literal** inside the router.
*   **Fix (pending):** Move the bypass token to `.env` / `Settings` as `BYPASS_AUTH_TOKEN: str | None = None`.

---

## 2. Full Wardrobe ORM Fetch in Outfit Generator (`outfits.py`) ✅ Fixed

*   **Issue:** `POST /outfits/generate` loaded every field of every ClothingItem into full ORM objects (including unused JSONB `anchor_points`, `detection_confidence`, etc.).
*   **Fix:** Replaced with scalar column query selecting only `id`, `name`, `type`, `sub_type`, `color`, `pattern`, `style` where `processing_status == "completed"`. Pre-built `valid_ids` set for AI output sanitisation.

---

## 3. Notifications: No Per-Notification Read Endpoint (`notifications.py`) ✅ Fixed

*   **Issue:** Only `POST /notifications/read-all` existed — no way to mark a single notification as read.
*   **Fix:** Added `PATCH /notifications/{id}/read` endpoint that marks a single notification as read and returns the updated record.

---

## 4. Weather API: No Caching, New HTTP Client Per Call (`weather.py`) ✅ Fixed

*   **Issue:** Weather fetched fresh on every AI request with a new `httpx.AsyncClient()` created and torn down every call.
*   **Fix:** Rewrote with a module-level `httpx.AsyncClient` singleton (connection pool reuse) and a dict-based TTL cache keyed on `(lat_rounded, lon_rounded)` with a 15-minute TTL. Failures are cached for 60 seconds to avoid hammering the API.

---

## 5. Frontend: No "Delete Account" UI (`profile_screen.dart`) ✅ Fixed

*   **Issue:** Backend `DELETE /users/me` existed but no UI surface existed to trigger it — GDPR/App Store compliance violation.
*   **Fix:** Added a red "Danger Zone" section to the Profile screen with a "Delete Account" row. Tapping it shows an `AlertDialog` warning the user that deletion is permanent. On confirmation: calls `DELETE /users/me`, signs out, navigates to Sign-In screen.

---

## 6. Frontend: Wear Logging Never Called from UI ✅ Fixed

*   **Issue:** `POST /wear-logs` endpoint existed but no UI ever called it, making all analytics charts permanently empty.
*   **Fix:**
    *   Added `logWear(outfitId)` method to `OutfitsNotifier` in `outfits_provider.dart`.
    *   Added `logWear` variant to the `WardrobeAction` enum in `wardrobe_action_sheet.dart` with a "Log Wear" bottom sheet row (👗 icon).
    *   Added `WardrobeAction.logWear` case to `OutfitCard._showContextMenu` — long-pressing an outfit now shows "Log Wear" as the first option, calling the API and showing a success toast.

---

## 7. `ai_feedback_screen.dart` AppBar Title Collision ✅ Fixed

*   **Issue:** The AI Feedback selection screen showed "Style Tips" — same as the analytics screen — causing confusing navigation.
*   **Fix:** Renamed AppBar title to `'AI Style Report'`.
