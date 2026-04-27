# Dressify — Suggested Improvements: Phase 2 & Phase 3

> Findings from a full codebase review conducted after Phase 3 completion.
> Organized by severity. Each item includes the file path, line reference, and a concrete fix direction.

---

## CRITICAL

### 1. Hardcoded Bypass Auth Token *(Security)*
**File:** [Backend/app/routers/auth.py](Backend/app/routers/auth.py)

The magic token `BYPASS_AUTH_FURQAN_54321` is a literal string in source code. Anyone with repo access can authenticate as the bypass user. The protection relies solely on `ENVIRONMENT != "production"`, which is a weak gate.

**Fix:** Move the token into an env var (e.g. `BYPASS_AUTH_TOKEN`). Only read it when `ENVIRONMENT == "development"`. Rotate it like any secret. *(skipped per user request)*

---

### 2. Uncaught Future in Frame Processing *(Memory / Stability)* ✅ FIXED
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `_onFrame()`

Added `.catchError((_) {})` after `.then(...)` so transient pose-detector throws no longer silently kill the overlay.

---

### 3. Stream Not Restarted After Capture Failure *(Stability)* ✅ FIXED
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `_capture()`

`startImageStream` failures in the `finally` block now surface an `AppToast.error('Tap to restart camera')` instead of being swallowed silently.

---

### 4. Race Condition: `addPostFrameCallback` Accumulates Every Build *(Stability)* ✅ FIXED
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `build()` (tab mode branch)

Replaced `ref.watch + addPostFrameCallback` with `ref.listen` in `build()`, so garment reloads are triggered once per provider change, not once per rebuild.

---

### 5. `_decodeNetworkImage` Hangs Forever on Slow / 404 Images *(Memory Leak)* ✅ FIXED
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `_decodeNetworkImage()`

Added `completer.future.timeout(AppConstants.imageLoadTimeout, ...)` so stuck completers throw a `TimeoutException` after 15 seconds.

---

### 6. N+1 Database Queries in Outfit Listing *(Performance)* ✅ FIXED
**File:** [Backend/app/routers/outfits.py](Backend/app/routers/outfits.py) — `get_outfits()`

`_build_outfit_response` made synchronous. All `GET /outfits`, `GET /outfits/{id}`, and `PATCH /outfits/{id}` queries now use `.options(selectinload(Outfit.items))` so items are loaded in a single join query. Added `items` relationship to `Outfit` model.

---

## HIGH PRIORITY

### 7. Silent Garment Load Failure in Try-On Screen ✅ FIXED
**File:** [Frontend/lib/features/try_on/try_on_screen.dart](Frontend/lib/features/try_on/try_on_screen.dart) — `_loadGarments()`

Added `Set<String> _failedIds`. After each load cycle, a tappable red banner shows "X item(s) couldn't load — tap to retry." that calls `_loadGarments()` again.

---

### 8. Entire Wardrobe Rendered at Once — No Pagination ✅ FIXED
**File:** [Frontend/lib/features/wardrobe/wardrobe_screen.dart](Frontend/lib/features/wardrobe/wardrobe_screen.dart) — `_ClothingTab`

- `GET /clothing` now accepts `cursor` and `limit=30` params and returns `next_cursor` for keyset pagination.
- `WardrobeNotifier` gained `fetchMore()` + `hasMore` getter.
- `_ClothingTab` converted to `ConsumerStatefulWidget` with a `ScrollController`; triggers `fetchMore()` 200 px before the bottom. Shows a spinner as the trailing item while loading.

---

### 9. Background Metadata Task Scheduled Before DB Commit ✅ FIXED
**File:** [Backend/app/routers/upload.py](Backend/app/routers/upload.py)

`background_tasks.add_task(extract_clothing_metadata, ...)` moved to after `await db.commit()`. `garment_bytes` is now passed through the results tuple so it's available post-commit.

---

### 10. `avatar_kind` Not Validated on Outfit Creation ✅ FIXED (pre-existing)
**File:** [Backend/app/schemas/outfit.py](Backend/app/schemas/outfit.py)

`OutfitCreate.avatar_kind` already typed as `AvatarKind = Literal[...]`. Pydantic rejects any unknown value automatically.

---

### 11. No Rate Limiting on GET Clothing / Outfit Endpoints ✅ FIXED
**File:** [Backend/app/routers/clothing.py](Backend/app/routers/clothing.py), [Backend/app/routers/outfits.py](Backend/app/routers/outfits.py)

`@limiter.limit("60/minute")` added to `GET /clothing`, `GET /clothing/{id}`, `GET /outfits`, and `GET /outfits/{id}`.

---

### 12. Failed Upload Temp Files Never Cleaned Up ✅ FIXED (pre-existing)
**File:** [Backend/app/services/retry_worker.py](Backend/app/services/retry_worker.py)

`_handle_failure` already calls `delete_file("clothing-raw-temp", row.raw_image_path)` when `attempt_count >= max_attempts`.

---

### 13. No Confirmation Before Clothing Item Delete ✅ FIXED
**File:** [Frontend/lib/features/wardrobe/wardrobe_screen.dart](Frontend/lib/features/wardrobe/wardrobe_screen.dart)

`AlertDialog("Delete [name]?" / Cancel / Delete)` added before both clothing item and outfit delete paths.

---

### 14. `CachedNetworkImage` Caches at Full Resolution ✅ FIXED
**File:** [Frontend/lib/features/wardrobe/wardrobe_screen.dart](Frontend/lib/features/wardrobe/wardrobe_screen.dart) — `_ClothingImage`

`memCacheWidth: 200` added to `CachedNetworkImage` so the framework downsizes the decoded bitmap to 2× the card width instead of caching the full 1024 px garment.

---

## MEDIUM PRIORITY

### 15. Potential Null Crash in Avatar Kind Lookup ✅ FIXED
**File:** [Frontend/lib/features/try_on/try_on_screen.dart](Frontend/lib/features/try_on/try_on_screen.dart)

Replaced the guarded `profile!.avatarKind` force-unwrap with:
```dart
_avatar = AvatarKind.values.firstWhere(
  (e) => e.name == (profileState.value?.avatarKind ?? ''),
  orElse: () => AvatarKind.maleAthletic,
);
```

---

### 16. `TextEditingController.dispose()` Called Immediately After Dialog ✅ FIXED
**File:** [Frontend/lib/features/wardrobe/wardrobe_screen.dart](Frontend/lib/features/wardrobe/wardrobe_screen.dart) — rename outfit dialog

`ctrl.dispose()` wrapped in `WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose())` so it runs after the dialog's exit animation completes.

---

### 17. Platform Detection in Getter Uses `Theme.of(context)` Unsafely ✅ FIXED
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `_formatGroup`

Replaced `Theme.of(context).platform` with `defaultTargetPlatform` from `flutter/foundation.dart`. No context dependency, no exception risk.

---

### 18. Broad Exception Catches Mask Programming Errors ✅ FIXED
**File:** [Backend/app/routers/clothing.py](Backend/app/routers/clothing.py), [Backend/app/routers/outfits.py](Backend/app/routers/outfits.py)

`except Exception` replaced with `except SQLAlchemyError` (imported from `sqlalchemy.exc`) in the `PATCH` handlers of both routers. Unexpected exceptions now propagate naturally.

---

### 19. Retry Worker Swallows All Exceptions Silently ✅ FIXED
**File:** [Backend/app/services/retry_worker.py](Backend/app/services/retry_worker.py)

`run_retry_worker` now tracks `consecutive_failures`. After 5 consecutive failures it logs `CRITICAL` and backs off exponentially (60 s → up to 10 min) before resuming. Resets to 0 on the first successful tick.

---

### 20. Outfit Save: `outfitsProvider.fetch()` Not Awaited ✅ FIXED
**File:** [Frontend/lib/features/try_on/try_on_screen.dart](Frontend/lib/features/try_on/try_on_screen.dart) — `_save()`

Changed `ref.read(outfitsProvider.notifier).fetch()` → `await ref.read(outfitsProvider.notifier).fetch()` so `_saving` is not reset until the list is actually refreshed.

---

## LOW PRIORITY

### 21. Hardcoded Magic Values Should Be Constants ✅ FIXED

Created `Frontend/lib/core/theme/app_constants.dart` with:

| Constant | Value | Replaces |
|---|---|---|
| `AppConstants.frameThrottle` | `Duration(milliseconds: 250)` | `camera_try_on_screen.dart` |
| `AppConstants.cameraResolution` | `ResolutionPreset.medium` | `camera_try_on_screen.dart` |
| `AppConstants.imageLoadTimeout` | `Duration(seconds: 15)` | `camera_try_on_screen.dart` |
| `AppConstants.tryOnCanvasColor` | `Color(0xFF1A1A2A)` | `try_on_screen.dart` |
| `AppConstants.saveFeedbackDuration` | `Duration(seconds: 2)` | `try_on_screen.dart` |

Both screens updated to import and use these constants.

---

### 22. No Retry on Transient Network Errors in Providers
**File:** [Frontend/lib/core/providers/wardrobe_provider.dart](Frontend/lib/core/providers/wardrobe_provider.dart), [Frontend/lib/core/providers/outfits_provider.dart](Frontend/lib/core/providers/outfits_provider.dart)

Transient timeouts set the provider to error state immediately; the user must manually pull-to-refresh. A `dio_retry` interceptor or manual retry with exponential backoff would reduce friction significantly.

*(Deferred — requires adding a dependency or significant provider refactor)*

---

### 23. Outfit Name Length Only Enforced in UI ✅ FIXED (pre-existing)
**File:** [Backend/app/schemas/outfit.py](Backend/app/schemas/outfit.py)

Both `OutfitCreate` and `OutfitUpdate` already use `Field(..., min_length=1, max_length=100)`. Server enforces the same limit as the UI TextField.

---

### 24. No Toast Dismiss / Full-Text View for Long Error Messages

`AppToast.error()` truncates long messages. Users cannot dismiss early or see the full text. Consider adding a `SnackBar` action ("Details") that opens a dialog with the full message.

*(Deferred — requires `AppToast` API refactor)*

---

### 25. Hot-Reload Orphans `PoseDetector` Instance in Dev Mode
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart)

Not critical for production. Wrapping `_detector.processImage(...)` in a try-catch that checks `_closed` state would prevent noisy dev logs. Deferred.

---

## Recommended Priority Order

### Immediate (fix before next test round) — ✅ ALL DONE
- [x] Item 4 — fix `addPostFrameCallback` race in camera tab
- [x] Item 2 — add `.catchError()` to `_onFrame`
- [x] Item 3 — surface error if stream fails to restart after capture
- [x] Item 5 — add timeout to `_decodeNetworkImage`
- [x] Item 9 — move background task scheduling after DB commit

### Next sprint — ✅ ALL DONE
- [x] Item 6 — fix N+1 outfit query with `selectinload`
- [x] Item 8 — add wardrobe pagination / infinite scroll
- [x] Item 7 — surface partial garment load failures in try-on
- [x] Item 13 — confirm-before-delete dialog
- [x] Item 11 — rate-limit GET endpoints

### Ongoing / housekeeping — ✅ DONE (except 22, 24, 25)
- [x] Item 10 — avatar_kind validation (pre-existing)
- [x] Item 12 — temp file cleanup (pre-existing)
- [x] Item 14 — CachedNetworkImage mem cache sizing
- [x] Item 15 — avatar kind null crash
- [x] Item 16 — TextEditingController safe disposal
- [x] Item 17 — Platform detection without context
- [x] Item 18 — Broad exception catches → SQLAlchemyError
- [x] Item 19 — Retry worker circuit breaker + exponential backoff
- [x] Item 20 — await outfitsProvider.fetch()
- [x] Item 21 — Hardcoded magic values → AppConstants
- [ ] Item 22 — Transient network retry in providers *(deferred)*
- [x] Item 23 — Outfit name max_length in Pydantic (pre-existing)
- [ ] Item 24 — Toast full-text view *(deferred)*
- [ ] Item 25 — Hot-reload PoseDetector orphan *(deferred, dev-only)*

---

*Generated after Phase 3 completion — 2026-04-27*
*Implementation completed — 2026-04-27*
