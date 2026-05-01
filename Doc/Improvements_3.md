# Dressify — Codebase Analysis: Improvements 3

> Generated: 2026-05-02
> This document outlines further codebase improvements based on a targeted analysis of the UI, backend endpoints, system performance, and user usability.

---

## 1. Dead UI Elements (Interactable but Not Implemented)

During a review of the Frontend components, several UI elements were identified that appear interactable but currently have no underlying logic (or `onTap` / `onChanged` handlers set to `null`).

*   **Profile Screen Settings (`profile_screen.dart`):** ✅ Fixed
    *   **"Upload complete" & "Style tips" Toggles:** Removed the non-functional toggles to avoid UI confusion.
    *   **"App Version" Row:** Updated to use a non-interactive layout rather than a disabled button to remove the misleading InkWell tap effect.

---

## 2. Missing Backend Endpoints & Improvements

Several operations currently rely on inefficient queries or lack proper API endpoints altogether.

*   **Missing Pagination on `GET /outfits`:** ✅ Fixed
    *   **File:** `app/routers/outfits.py`
    *   **Issue:** The `/outfits` endpoint fetches *all* outfits belonging to a user in a single database query. Unlike the `/clothing` endpoint (which properly implements cursor-based pagination), fetching all outfits at once will scale poorly as a user's collection grows.
*   **Missing Batch Delete for Wardrobe (`DELETE /clothing/batch`):** ✅ Fixed
    *   **Issue:** Users cannot delete multiple clothing items at once. If a user wants to clean up 20 items, the frontend must fire 20 individual HTTP `DELETE` requests, which is inefficient and prone to partial failures.
*   **Missing Account Deletion Endpoint (`DELETE /users/me`):** ✅ Fixed
    *   **Issue:** There is no endpoint or frontend UI to delete a user account and cleanly cascade the deletion to their associated Supabase storage files and database records. This is a strict requirement for GDPR compliance and App Store/Play Store review guidelines.

---

## 3. Performance Improvements

Critical bottlenecks were identified that could block the application event loop or degrade scalability.

*   **Event Loop Blocking during Image Processing (Backend):** ✅ Fixed
    *   **File:** `app/routers/upload.py` and `app/services/image_processing.py`
    *   **Issue:** The `extract_garment` function relies on Python's PIL (Pillow) library for image cropping and masking, which is a strictly CPU-bound operation. Currently, this function is called synchronously within the `async def upload_clothing` FastAPI endpoint. 
    *   **Fix:** Wrapped the PIL execution in `starlette.concurrency.run_in_threadpool` to prevent the synchronous image processing from blocking the FastAPI asyncio event loop. Without this, a single upload request will stall all other concurrent API requests for the entire server.
*   **Backend Memory Bloat (Related to Pagination):**
    *   **Issue:** As mentioned in Section 2, `GET /outfits` uses SQLAlchemy's `selectinload(Outfit.items)` without a `limit`. While `selectinload` prevents N+1 queries, loading hundreds of outfits and their nested relational items into backend memory at the exact same time will cause massive memory spikes.

---

## 4. User Usability Improvements

Features that would significantly enhance the day-to-day experience of the app.

*   *(Removed: Undo/Reset Button in Try-On Canvas - the canvas uses live AR ML pose detection to anchor garments, not manual dragging)*
*   **Wardrobe Sorting & Advanced Filtering:** ✅ Fixed
    *   **Issue:** The Wardrobe screen currently only supports filtering by `type` (e.g., tops, bottoms). 
    *   **Fix:** Added a `sort_by` parameter to `GET /clothing` and added a PopupMenuButton to the Wardrobe UI to allow sorting by "Newest First" and "Oldest First".
