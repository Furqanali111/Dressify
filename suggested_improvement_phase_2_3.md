# Dressify — Suggested Improvements: Phase 2 & Phase 3

> Findings from a full codebase review conducted after Phase 3 completion.
> Organized by severity. Each item includes the file path, line reference, and a concrete fix direction.

---

## CRITICAL

### 1. Hardcoded Bypass Auth Token *(Security)*
**File:** [Backend/app/routers/auth.py](Backend/app/routers/auth.py)

The magic token `BYPASS_AUTH_FURQAN_54321` is a literal string in source code. Anyone with repo access can authenticate as the bypass user. The protection relies solely on `ENVIRONMENT != "production"`, which is a weak gate.

**Fix:** Move the token into an env var (e.g. `BYPASS_AUTH_TOKEN`). Only read it when `ENVIRONMENT == "development"`. Rotate it like any secret.

---

### 2. Uncaught Future in Frame Processing *(Memory / Stability)*
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `_onFrame()`

`_poseService.processFrame(...).then(...)` has no `.catchError()`. If the pose detector throws, the error is silently discarded and the camera overlay stops updating with no feedback to the user.

**Fix:**
```dart
_poseService
    .processFrame(...)
    .then((anchors) { if (mounted) setState(() => _anchors = anchors); })
    .catchError((_) { /* log; optionally show a one-time warning */ });
```

---

### 3. Stream Not Restarted After Capture Failure *(Stability)*
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `_capture()`

In the `finally` block, `startImageStream` failure is silently swallowed. If restarting the stream fails, `_capturing` is reset to `false` so the UI looks normal, but pose detection is dead for the rest of the session.

**Fix:** If `startImageStream` throws in `finally`, surface an `AppToast.error` and optionally set a `_streamDead` flag that shows a "Tap to restart camera" overlay.

---

### 4. Race Condition: `addPostFrameCallback` Accumulates Every Build *(Stability)*
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `build()` (tab mode branch)

`WidgetsBinding.instance.addPostFrameCallback((_) { _loadItems(providerItems); })` is called on every `build()`. If the widget rebuilds multiple times before a frame is rasterised (e.g. during orientation change), multiple concurrent `_loadItems()` calls race, potentially disposing images that are still being painted.

**Fix:** Move the listener to `initState` / use `ref.listen` instead of `ref.watch` + postFrameCallback:
```dart
ref.listen<List<ClothingItem>>(cameraGarmentsProvider, (_, next) {
  _loadItems(next);
});
```

---

### 5. `_decodeNetworkImage` Hangs Forever on Slow / 404 Images *(Memory Leak)*
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `_decodeNetworkImage()`

If the network image never resolves (404, timeout, CDN hiccup), the `Completer` never completes, the `ImageStreamListener` stays attached forever, and `_loadGarments` awaits indefinitely.

**Fix:**
```dart
return completer.future.timeout(
  const Duration(seconds: 15),
  onTimeout: () => throw TimeoutException('Image load timed out: $url'),
);
```

---

### 6. N+1 Database Queries in Outfit Listing *(Performance)*
**File:** [Backend/app/routers/outfits.py](Backend/app/routers/outfits.py) — `get_outfits()`

For 10 outfits the endpoint runs 11 queries: one to list outfits, then one per outfit inside `_build_outfit_response`. This degrades linearly.

**Fix:** Use SQLAlchemy eager loading:
```python
result = await db.execute(
    select(Outfit)
    .where(Outfit.user_id == current_user.id)
    .options(selectinload(Outfit.items))
)
```

---

## HIGH PRIORITY

### 7. Silent Garment Load Failure in Try-On Screen
**File:** [Frontend/lib/features/try_on/try_on_screen.dart](Frontend/lib/features/try_on/try_on_screen.dart) — `_loadGarments()`

Individual garment image failures are caught and swallowed. The user sees the loading spinner complete but the canvas has fewer items than expected — no indicator that something went wrong.

**Fix:** Track failed items in a `Set<String> _failedIds`. After loading, if `_failedIds.isNotEmpty`, show a banner: "X item(s) couldn't load — tap to retry."

---

### 8. Entire Wardrobe Rendered at Once — No Pagination
**File:** [Frontend/lib/features/wardrobe/wardrobe_screen.dart](Frontend/lib/features/wardrobe/wardrobe_screen.dart) — clothing `GridView.builder`

`itemCount: items.length` with no virtual scrolling. At 200+ items this causes OOM on mid-range devices and jank on scroll.

**Fix:** implement infinite scroll (fetch 30 items per page, load more on `ScrollController` threshold)

---

### 9. Background Metadata Task Scheduled Before DB Commit
**File:** [Backend/app/routers/upload.py](Backend/app/routers/upload.py)

`background_tasks.add_task(extract_clothing_metadata, item_id, ...)` is registered before `await db.commit()`. If the task executes before commit (possible under high concurrency), it reads a row that doesn't exist yet and fails silently — leaving `color`, `pattern`, `style`, `sub_type` permanently null.

**Fix:** Move `background_tasks.add_task(...)` to after `await db.commit()`.

---

### 10. `avatar_kind` Not Validated on Outfit Creation
**File:** [Backend/app/routers/outfits.py](Backend/app/routers/outfits.py)

Any string is accepted as `avatar_kind`. The frontend can't render an unknown avatar kind, but the DB stores it happily.

**Fix:** Use the same `Literal[...]` type already used in other schemas, or a `ClothingAvatarKind` enum. Pydantic will reject invalid values automatically.

---

### 11. No Rate Limiting on GET Clothing / Outfit Endpoints
**File:** [Backend/app/routers/clothing.py](Backend/app/routers/clothing.py), [Backend/app/routers/outfits.py](Backend/app/routers/outfits.py)

POST and PATCH endpoints have `@limiter.limit(...)` decorators, but GET list endpoints don't. A client can hammer these to enumerate a user's wardrobe or spike DB load.

**Fix:** Add `@limiter.limit("60/minute")` (or similar) to `GET /clothing` and `GET /outfits`.

---

### 12. Failed Upload Temp Files Never Cleaned Up
**File:** [Backend/app/services/retry_worker.py](Backend/app/services/retry_worker.py)

Items marked `failed` in `upload_retry_queue` leave their raw image in the `clothing-raw-temp` bucket indefinitely. No cleanup job exists.

**Fix:** In the tick that marks an item `failed`, delete the corresponding file from `clothing-raw-temp`. Alternatively, add a nightly cleanup sweep for temp files older than 7 days.

---

### 13. No Confirmation Before Clothing Item Delete
**File:** [Frontend/lib/features/wardrobe/wardrobe_screen.dart](Frontend/lib/features/wardrobe/wardrobe_screen.dart) — `_ItemAction.delete` handler

One tap in the action sheet deletes the item immediately. There is no undo.

**Fix:** Show an `AlertDialog` with "Delete [name]?" / Cancel / Delete before calling `wardrobeProvider.notifier.delete(...)`.

---

### 14. `CachedNetworkImage` Caches at Full Resolution
**File:** [Frontend/lib/features/wardrobe/wardrobe_screen.dart](Frontend/lib/features/wardrobe/wardrobe_screen.dart) — `_ClothingImage`

No `memCacheWidth` / `memCacheHeight` set. The full-resolution processed garment (up to 1024 px) is decoded and cached for every card, even though the card is ~100 px wide.

**Fix:**
```dart
CachedNetworkImage(
  imageUrl: item.processedUrl,
  memCacheWidth: 200,  // 2× card width for HiDPI
  fit: BoxFit.contain,
  ...
)
```

---

## MEDIUM PRIORITY

### 15. Potential Null Crash in Avatar Kind Lookup
**File:** [Frontend/lib/features/try_on/try_on_screen.dart](Frontend/lib/features/try_on/try_on_screen.dart)

```dart
if (profile?.avatarKind != null)
    AvatarKind.values.firstWhere(..., orElse: ...)
```

The null check passes, but `profile!.avatarKind` is then force-unwrapped. If profile is non-null but `avatarKind` is null, this crashes.

**Fix:** `profile?.avatarKind` with a `?? AvatarKind.maleAthletic` fallback — no force unwrap needed.

---

### 16. `TextEditingController.dispose()` Called Immediately After Dialog
**File:** [Frontend/lib/features/wardrobe/wardrobe_screen.dart](Frontend/lib/features/wardrobe/wardrobe_screen.dart) — rename outfit dialog

`ctrl.dispose()` is called right after `await showDialog(...)` returns, but the dialog's TextField may still be animating out (the framework may access the controller during the dismissal animation).

**Fix:** Wrap in `addPostFrameCallback` after dialog close, or use a `StatefulBuilder` inside the dialog so the controller is owned by a widget whose lifecycle matches the dialog.

---

### 17. Platform Detection in Getter Uses `Theme.of(context)` Unsafely
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart) — `_formatGroup` getter

`Theme.of(context)` is called in a getter that can be accessed outside a build frame. Exceptions are silently swallowed, silently defaulting to BGRA on Android (wrong format for ML Kit).

**Fix:** Use `defaultTargetPlatform` from `flutter/foundation.dart` — it's always available without a context.

---

### 18. Broad Exception Catches Mask Programming Errors
**File:** [Backend/app/routers/clothing.py](Backend/app/routers/clothing.py), multiple routers

`except Exception as e:` catches `asyncio.CancelledError`, `KeyboardInterrupt`, and `SystemExit` in Python 3.11 — masking shutdown signals and obscuring bugs.

**Fix:** Catch specific SQLAlchemy exceptions (`SQLAlchemyError`, `IntegrityError`) instead of bare `Exception`. Let unexpected types propagate.

---

### 19. Retry Worker Swallows All Exceptions Silently
**File:** [Backend/app/services/retry_worker.py](Backend/app/services/retry_worker.py)

When `_tick()` raises (e.g. DB down), the worker logs and loops forever. There is no circuit-breaker or alerting, so the admin has no signal the retry system is broken.

**Fix:** Count consecutive failures. After N failures, log a `CRITICAL`-level alert and back off exponentially before retrying the tick.

---

### 20. Outfit Save: `outfitsProvider.fetch()` Not Awaited
**File:** [Frontend/lib/features/try_on/try_on_screen.dart](Frontend/lib/features/try_on/try_on_screen.dart) — `_save()`

`ref.read(outfitsProvider.notifier).fetch()` is fire-and-forget. `_saving` is reset to `false` before the list actually refreshes, so returning to the home screen may briefly show stale outfit data.

**Fix:** `await ref.read(outfitsProvider.notifier).fetch()` inside the try block, before resetting `_saving`.

---

## LOW PRIORITY

### 21. Hardcoded Magic Values Should Be Constants

| Value | File | What it controls |
|---|---|---|
| `Duration(milliseconds: 250)` | `camera_try_on_screen.dart` | Frame throttle |
| `ResolutionPreset.medium` | `camera_try_on_screen.dart` | Camera resolution |
| `const Color(0xFF1A1A2A)` | `try_on_screen.dart` | Canvas background |
| `const Duration(seconds: 2)` | `try_on_screen.dart` | Save toast duration |

**Fix:** Move to a `AppConstants` class or `app_config.dart`.

---

### 22. No Retry on Transient Network Errors in Providers
**File:** [Frontend/lib/core/providers/wardrobe_provider.dart](Frontend/lib/core/providers/wardrobe_provider.dart), [Frontend/lib/core/providers/outfits_provider.dart](Frontend/lib/core/providers/outfits_provider.dart)

Transient timeouts set the provider to error state immediately; the user must manually pull-to-refresh. A `dio_retry` interceptor or manual retry with exponential backoff would reduce friction significantly.

---

### 23. Outfit Name Length Only Enforced in UI
**File:** Frontend wardrobe rename dialog (`maxLength: 100`) vs. backend (no validation)

Pydantic schema should add `Field(max_length=100)` to the outfit name field so the constraint is enforced on the server too, not just in the TextField.

---

### 24. No Toast Dismiss / Full-Text View for Long Error Messages

`AppToast.error()` truncates long messages. Users cannot dismiss early or see the full text. Consider adding a `SnackBar` action ("Details") that opens a dialog with the full message.

---

### 25. Hot-Reload Orphans `PoseDetector` Instance in Dev Mode
**File:** [Frontend/lib/features/camera_try_on/camera_try_on_screen.dart](Frontend/lib/features/camera_try_on/camera_try_on_screen.dart)

On hot reload, the old `PoseDetectionService` is disposed, but ML Kit's native `PoseDetector` may not release immediately. In development this can cause "detector already closed" errors on the next frame.

**Fix:** Not critical for production, but wrapping `_detector.processImage(...)` in a try-catch that checks `_closed` state prevents noisy logs during dev.

---

## Recommended Priority Order

### Immediate (fix before next test round)
- [x] Item 4 — fix `addPostFrameCallback` race in camera tab
- [x] Item 2 — add `.catchError()` to `_onFrame`
- [x] Item 3 — surface error if stream fails to restart after capture
- [x] Item 5 — add timeout to `_decodeNetworkImage`
- [x] Item 9 — move background task scheduling after DB commit

### Next sprint
- [x] Item 6 — fix N+1 outfit query with `selectinload`
- [x] Item 8 — add wardrobe pagination or virtual scroll
- [x] Item 7 — surface partial garment load failures in try-on
- [x] Item 13 — confirm-before-delete dialog
- [x] Item 11 — rate-limit GET endpoints

### Ongoing / housekeeping
- Items 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24

---

*Generated after Phase 3 completion — 2026-04-27*
