# Dressify — Improvements, Bugs & Warnings (Round 7)

> Full line-by-line static-analysis audit — all Backend + Frontend files scanned.  
> Severity: **[H]** High · **[M]** Medium · **[L]** Low  
> Status: ✅ Fixed · ⚠️ Open

---

## Backend

### Bugs

| # | File | Line | Description | Sev | Status |
|---|------|------|-------------|-----|--------|
| B-BE-4 | `routers/clothing.py` | ~194 | `await db.delete(item)` — synchronous call, TypeError crash. | **[H]** | ✅ Fixed |
| B-BE-5 | `routers/users.py` | ~122 | `await db.delete(current_user)` — same crash. | **[H]** | ✅ Fixed |
| B-BE-6 | `routers/outfits.py` | ~326 | `await db.delete(outfit)` — same crash. | **[H]** | ✅ Fixed |
| B-BE-10 | `routers/auth.py` | ~55 | `sb_user.user_metadata.get()` without null-checking first. | **[M]** | ✅ Fixed |
| B-BE-17 | `services/retry_worker.py` | ~218 | `asyncio.create_task()` fire-and-forget — tasks dropped on restart. | **[M]** | ⚠️ Open |
| B-BE-18 | `routers/outfits.py` | ~119 | Malformed cursor silently ignored — pagination resets silently. | **[L]** | ✅ Fixed |

---

### Improvements

| # | File | Line | Description | Pri | Status |
|---|------|------|-------------|-----|--------|
| I-BE-1 | `routers/auth.py` | — | No rate limiting on `POST /auth/google`. | **[H]** | ✅ Fixed |
| I-BE-2 | `routers/outfits.py` | — | `POST /outfits` has no `@limiter.limit(...)`. | **[H]** | ✅ Fixed |
| I-BE-3 | `routers/notifications.py` | — | Add `DELETE /notifications` (clear all). | **[H]** | ✅ Fixed |
| I-BE-4 | Multiple models | — | Missing DB indexes on `user_id` / `created_at` columns. | **[H]** | ⚠️ Open |
| I-BE-5 | `routers/analytics.py` | — | Loads every wear-log with no date filter or pagination. | **[M]** | ⚠️ Open |
| I-BE-6 | `schemas/outfit.py` | ~40 | `OutfitResponse.avatar_kind` typed as `str` not `AvatarKind` Literal. | **[M]** | ✅ Fixed |
| I-BE-7 | `schemas/outfit.py` | ~20 | `OutfitCreate.items` has no min_length=1 guard. | **[M]** | ✅ Fixed |
| I-BE-8 | `services/storage.py` | — | Bare `Exception` catch hides real storage errors. | **[M]** | ✅ Fixed |
| I-BE-9 | `services/style_preferences.py` | — | No rollback on exception mid-function. | **[M]** | ✅ Fixed |
| I-BE-10 | `core/limiter.py` | — | In-memory limiter resets on restart. | **[M]** | ⚠️ Open |
| I-BE-11 | `services/notifications.py` | — | `push_notification()` silently drops notifs on rollback. | **[M]** | ✅ Fixed |
| I-BE-12 | `services/retry_worker.py` | — | Stale `failed` queue entries never pruned. | **[M]** | ⚠️ Open |
| I-BE-13 | `routers/clothing.py` | ~64 | Invalid cursor silently ignored — return 400 instead. | **[M]** | ✅ Fixed |
| I-BE-14 | `routers/users.py` | ~119 | `storage.delete_file()` called synchronously inside async route. | **[M]** | ✅ Fixed |
| I-BE-15 | `main.py` | ~68 | Global exception handler missing `exc_info=True`. | **[M]** | ✅ Fixed |
| I-BE-16 | `db.py` | ~12 | URL conversion overwrites existing driver spec — double-driver URL. | **[M]** | ✅ Fixed |
| I-BE-17 | `services/fit_scale.py` | ~49 | Silent fallback for unknown avatar_kind. | **[L]** | ✅ Fixed |
| I-BE-18 | `services/retry_worker.py` | ~56 | Backoff constants are magic numbers. | **[L]** | ✅ Fixed |
| I-BE-19 | `models/clothing_item.py` | — | No soft-delete; removed garments break outfit history. | **[L]** | ⚠️ Open |
| I-BE-20 | `routers/outfits.py` | — | No max-items-per-outfit guard. | **[L]** | ✅ Fixed |
| I-BE-21 | `services/ai_vision.py` | ~74 | Bucket name `"clothing-processed"` hardcoded. | **[L]** | ✅ Fixed |
| I-BE-22 | `services/weather.py` | — | Cache TTL uses `time.monotonic()` — unreliable across system sleep. | **[L]** | ✅ Fixed |
| I-BE-23 | `security.py` | — | `JWT_TTL_HOURS` never validated to be a positive integer. | **[L]** | ✅ Fixed |
| I-BE-24 | `main.py` | — | CORS `allow_methods=["*"]` and `allow_headers=["*"]`. | **[L]** | ✅ Fixed |

---

### Warnings

| # | File | Line | Description | Status |
|---|------|------|-------------|--------|
| W-BE-1 | `config.py` | — | Hardcoded bypass-auth token in source control. | ⚠️ Open |
| W-BE-3 | `services/weather.py` | — | Outfit generation reads weather context without null-guard. | ✅ Fixed |
| W-BE-4 | `routers/upload.py` | — | No global request-body size limit middleware. | ✅ Fixed |
| W-BE-5 | `alembic/versions/` | — | Migration file untracked in git. | ⚠️ Open |
| W-BE-6 | `services/image_processing.py` | ~48 | `Image.LANCZOS` deprecated since Pillow 10.0. | ✅ Fixed |
| W-BE-7 | `deps.py` | ~34 | Commented-out dead RLS code. | ✅ Fixed |
| W-BE-9 | `services/ai_vision.py` | ~65 | `.choices[0].message.content` without null-check. | ✅ Fixed |
| W-BE-10 | `services/style_preferences.py` | ~22 | `score: int` hint should be `score: float`. | ✅ Fixed |
| W-BE-11 | `routers/notifications.py` | ~105 | `HTTPException` imported inside function body. | ✅ Fixed |

---

## Frontend

### Bugs

| # | File | Line | Description | Sev | Status |
|---|------|------|-------------|-----|--------|
| B-FE-3 | `features/try_on/try_on_screen.dart` | ~122 | Concurrent `_loadGarments()` race on refresh. | **[H]** | ✅ Fixed |
| B-FE-11 | `core/models/clothing_item.dart` | ~52 | `DateTime.parse()` without fallback — crash on bad date. | **[M]** | ✅ Fixed |
| B-FE-12 | `core/models/wear_log.dart` | ~26 | `DateTime.parse()` without fallback — crash on bad date. | **[M]** | ✅ Fixed |
| B-FE-14 | `features/camera_try_on/camera_try_on_screen.dart` | ~1119 | `_GarmentPickerSheet` shows empty instead of spinner while loading. | **[M]** | ✅ Fixed |
| B-FE-16 | `features/splash/splash_screen.dart` | ~57 | `requestStartupPermissions` called after navigation — context disposed. | **[M]** | ✅ Fixed |
| B-FE-18 | `core/providers/auth_provider.dart` | ~70 | `response.data['user']` cast without null check. | **[M]** | ✅ Fixed |

---

### Improvements

| # | File | Line | Description | Pri | Status |
|---|------|------|-------------|-----|--------|
| I-FE-2 | `core/providers/wear_logs_provider.dart` | ~78 | Empty `catch` in `fetchMore` — loading state never reset. | **[M]** | ✅ Fixed |
| I-FE-4 | `features/upload/upload_screen.dart` | — | Upload has no send/receive timeout. | **[M]** | ✅ Fixed |
| I-FE-5 | `features/profile_setup/profile_setup_screen.dart` | ~155 | `double.tryParse(...) ?? 0` silently converts invalid input to 0. | **[M]** | ✅ Fixed |
| I-FE-6 | `features/profile_setup/profile_setup_screen.dart` | ~191 | `updateProfile()` failure ignored — navigation proceeds anyway. | **[M]** | ✅ Fixed |
| I-FE-7 | `features/wardrobe/edit_clothing_sheet.dart` | ~59 | `AppToast.success()` called after `Navigator.pop()`. | **[M]** | ✅ Fixed |
| I-FE-8 | `core/providers/fit_rating_provider.dart` | ~26 | `response.data!` non-null assertion. | **[M]** | ✅ Fixed |
| I-FE-9 | `features/try_on/try_on_screen.dart` | — | Fit-rating requests repeated on every badge toggle. | **[M]** | ⚠️ Open |
| I-FE-10 | `core/providers/wardrobe_provider.dart` | — | `pollUntilComplete()` fired unawaited. | **[M]** | ✅ Fixed |
| I-FE-11 | `features/style_tips/wardrobe_analytics_screen.dart` | ~421 | `_UnderutilisedList` tap handler is dead code (empty TODO). | **[M]** | ✅ Fixed |
| I-FE-12 | `features/wardrobe/style_me_sheet.dart` | — | Failed outfit generation produces no analytics event. | **[M]** | ⚠️ Open |
| I-FE-13 | `features/wardrobe/clothing_card.dart` | ~135 | `onLongPress` not disabled during `isProcessing` state. | **[M]** | ✅ Fixed |
| I-FE-14 | `camera_try_on_screen.dart` | ~256 | `ids.join(',')` string comparison for ID equality. | **[L]** | ✅ Fixed |
| I-FE-15 | `features/profile_setup/profile_setup_screen.dart` | ~305 | Gender stored as raw string literals. | **[L]** | ✅ Fixed |
| I-FE-16 | `core/router/app_router.dart` | ~27 | `_publicPaths` hardcoded. | **[L]** | ⚠️ Open |
| I-FE-17 | `features/camera_try_on/camera_try_on_screen.dart` | ~1119 | `_GarmentPickerSheet` loading vs empty state. | **[L]** | ✅ Fixed |
| I-FE-18 | Multiple screens | — | Icon-only `IconButton`s have no tooltip. | **[L]** | ⚠️ Open |
| I-FE-19 | `core/api/auth_interceptor.dart` | — | `_cachedToken` never cleared on sign-out. | **[L]** | ✅ Fixed |
| I-FE-20 | `app.dart` | — | No global `ErrorWidget.builder` override. | **[L]** | ✅ Fixed |
| I-FE-21 | `features/profile_setup/profile_setup_screen.dart` | ~156 | Magic constants `30.48` and `0.453592`. | **[L]** | ✅ Fixed |

---

### Warnings

| # | File | Line | Description | Status |
|---|------|------|-------------|--------|
| W-FE-1 | `pubspec.yaml` | — | `url_launcher` still listed — all call sites removed. | ✅ Fixed |
| W-FE-2 | `pubspec.yaml` | — | `google_mlkit_pose_detection: ^0.14.0` several versions behind. | ⚠️ Open |
| W-FE-3 | `features/try_on/try_on_screen.dart` | ~289 | `outfit` param nullable but used without guards. | ✅ Fixed |
| W-FE-4 | Multiple providers | — | `AsyncValue.value` accessed directly, bypassing `.when()`. | ✅ Fixed |
| W-FE-5 | Multiple files | — | Mix of `.withValues(alpha:)` and deprecated `.withOpacity()`. | ✅ Fixed |
| W-FE-6 | `wardrobe_analytics_screen.dart` | ~89 | List children generated without `Key` values. | ⚠️ Open |
| W-FE-7 | `features/wardrobe/wardrobe_screen.dart` | ~378 | `type == widget.filter!.name` — fragile string enum matching. | ⚠️ Open |
| W-FE-8 | `core/services/pose_detection_service.dart` | ~169 | Redundant `clamp(0.0, 1.0)` after `normalize()`. | ✅ Fixed |
| W-FE-9 | `macos/Flutter/GeneratedPluginRegistrant.swift` | — | Auto-generated file marked modified in git. | ✅ Fixed |
| W-FE-10 | Entire codebase | — | No widget or unit tests found. | ⚠️ Open |

---

## Summary

| Category | Count | ✅ Fixed | ⚠️ Open |
|----------|-------|----------|---------|
| Backend Bugs | 6 | 5 | 1 |
| Backend Improvements | 24 | 18 | 6 |
| Backend Warnings | 9 | 7 | 2 |
| Frontend Bugs | 6 | 6 | 0 |
| Frontend Improvements | 19 | 15 | 4 |
| Frontend Warnings | 10 | 7 | 3 |
| **Total** | **74** | **58** | **16** |
