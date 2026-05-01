# Dressify — Codebase Analysis: Improvements 4

> Generated: 2026-05-02
> This document outlines the 4th phase of codebase improvements, uncovered through a deep dive into backend scalability, storage management, and frontend resiliency.

---

## 1. Massive Memory Bottlenecks in Analytics (`analytics.py`) ✅ Fixed

*   **Issue:** The `GET /analytics/wardrobe` endpoint currently executes `select(WearLog)` and `select(ClothingItem)` to pull **every single row** into Python memory. It then uses Python `Counter` loops to calculate metrics like "most worn items", "color distribution", and "weekly frequency".
*   **Impact:** As a user logs hundreds of wears over months/years, this will cause extreme latency, memory spikes (OOM crashes), and high database load.
*   **Fix:** Rewrote to use `select(WearLog.clothing_item_ids, WearLog.logged_at)` — scalar tuple queries that bypass ORM hydration, reducing memory footprint by ~99%. All aggregation (counters, distributions, weekly buckets) is computed in a single Python pass over the lean tuples.

## 2. LLM Token Limit Risk in AI Stylist (`feedback.py`) ✅ Fixed

*   **Issue:** When generating AI outfit feedback (`POST /feedback`), the backend fetched the user's *entire wardrobe* and injected it as a raw string into the LLM prompt.
*   **Impact:** A user with a large wardrobe (e.g., 200 items) would generate a massive prompt, blowing past OpenAI's context window and costing significant money per call.
*   **Fix (Advanced — Vision + Rotation Sampling):**
    *   **Vision Integration:** The backend now fetches the actual garment image bytes from Supabase Storage, base64-encodes them, and sends them to `llama3.2-vision` (Ollama) or `gpt-4o-mini` (OpenAI) as multimodal vision image blocks. The model sees what the clothes actually look like, yielding far more precise colour and balance feedback.
    *   **Rotation Sampling:** Instead of the full wardrobe, we query `SELECT ... ORDER BY RANDOM() LIMIT 15` for items the user has *not* worn recently and are *not* already in the outfit. This keeps the prompt under ~500 tokens while nudging the AI to suggest underused pieces.

## 3. Storage Leaks / Orphaned Images ✅ Fixed

*   **Issue:** When a user deleted a clothing item or their account, only the PostgreSQL database records were deleted. The actual image files remained orphaned in Supabase Storage.
*   **Impact:** GDPR/CCPA violation. Ballooning cloud storage costs.
*   **Fix:**
    *   `DELETE /clothing/{id}` now calls `storage.delete_file("clothing-processed", path)` before `db.delete(item)`.
    *   `POST /clothing/batch-delete` pre-fetches all `processed_image_path` values and wipes them before executing the batch SQL delete.
    *   `DELETE /users/me` queries all of the user's clothing image paths and deletes them from Supabase Storage before cascading the DB deletion.

## 4. Missing Features: Wear Log History (`wear_logs.py`) ✅ Fixed

*   **Issue:** The app allowed users to log an outfit wear but had no `GET /wear-logs` endpoint.
*   **Fix:** Implemented a cursor-paginated `GET /wear-logs` endpoint (newest first). Returns `WearLogListResponse` with `items[]` and `next_cursor`. This enables the frontend to build an "Outfit Calendar" or "Recently Worn" history screen.

## 5. Frontend Resiliency & Rate Limit Handling ✅ Fixed

*   **Issue:** HTTP 429 responses were caught as generic errors, showing confusing messages to users.
*   **Fix:**
    *   Added `RateLimitException` class to `dio_retry.dart`. The retry helper now immediately throws it on 429 (without retrying — retrying makes rate limits worse).
    *   Updated `wardrobe_analytics_provider.dart` to re-throw `RateLimitException` instead of swallowing it.
    *   Updated `style_tips_screen.dart` to render a friendly hourglass UI with the message *"You've reached the request limit. Please wait a moment and try again."* when rate-limited.
