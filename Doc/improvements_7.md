# Dressify — Improvements, Bugs & Warnings (Round 7)

> Full line-by-line static-analysis audit — all Backend + Frontend files scanned.  
> Severity: **[H]** High · **[M]** Medium · **[L]** Low

---

## Backend

### Bugs

| # | File | Line | Description | Severity |
|---|------|------|-------------|----------|
| B-BE-1 | `routers/outfits.py` | — | `GET /outfits` returns `{items, next_cursor}` but `outfits_provider.dart` still parses it as a flat list — runtime cast failure on every outfit load. | **[H]** |
| B-BE-2 | `routers/notifications.py` | — | `PATCH /notifications/{id}/read` endpoint missing from the router. `notifications_provider.dart` calls it, optimistic UI update works locally but state is never persisted — notification reappears unread on next launch. | **[H]** |
| B-BE-3 | `routers/clothing.py` | ~81 | `ClothingItemResponse.model_validate(item)` is called on a 6-column partial query result. Fields like `anchor_points`, `color`, `pattern`, `style`, `fit_notes` are absent — `AttributeError` on every clothing list request. | **[H]** |
| B-BE-4 | `routers/auth.py` | ~77 | `await db.delete(item)` is not a valid SQLAlchemy async session method. Should be `await db.execute(delete(...).where(...))`. Account cleanup on sign-up failure always raises `AttributeError`. | **[H]** |
| B-BE-5 | `routers/users.py` | ~122 | Same broken `await db.delete(current_user)` pattern — account-deletion endpoint always crashes. Users can never delete their accounts. | **[H]** |
| B-BE-6 | `routers/outfits.py` | — | Race condition: items validated to exist, outfit inserted in a separate step. Concurrent DELETE between those steps causes `IntegrityError` on commit after the client believes the outfit was saved. | **[H]** |
| B-BE-7 | `routers/feedback.py` | ~149 | `.style`, `.color`, `.pattern` accessed as attributes on ORM `Row` tuples (partial select). Raises `AttributeError` on every outfit-feedback POST that reads clothing item attributes. | **[H]** |
| B-BE-8 | `routers/feedback.py` | ~82 | No ownership check on clothing items inside a provided `outfit_id`. A user can reference items they don't own — data-leakage / authorization bypass. | **[H]** |
| B-BE-9 | `routers/upload.py` | ~104 | DB record created even when `upload_file()` returns `False`. Creates orphaned rows with no processed image path. | **[M]** |
| B-BE-10 | `routers/auth.py` | ~55 | `sb_user.user_metadata.get("full_name")` called without null-checking `user_metadata` first. If Supabase returns a user without metadata, raises `AttributeError`. | **[M]** |
| B-BE-11 | `services/ai_vision.py` | ~156 | Response-format logic for Ollama is inverted — `response_format` is excluded precisely when `vision_blocks` are present, which is the only time structured JSON output is needed. | **[M]** |
| B-BE-12 | `services/ai_vision.py` | ~164 | Markdown-fence stripping assumes closing ` ``` ` always exists. If the model truncates mid-output, `split("```")[1]` raises `IndexError`. | **[M]** |
| B-BE-13 | `services/fit_rating.py` | ~81 | `diff_ratio = (lo - measurement) / span` — if `span` is near zero (extremely narrow garment range), causes numerical instability / near-infinity result. No guard for `span == 0`. | **[M]** |
| B-BE-14 | `services/storage.py` | ~41 | `get_signed_url()` returns either a string, a dict, or `False` depending on the code path. Caller receives unexpected type silently — a `False` return is treated as a URL and sent to the client. | **[M]** |
| B-BE-15 | `routers/outfits.py` | ~10 | `position` field always set to `None` in `OutfitResponse` because schema objects are constructed manually without reading back stored DB values. Anchor-point data lost on every create. | **[M]** |
| B-BE-16 | `routers/wear_logs.py` | — | `safe_item_ids = [str(row) for row in owned.scalars().all()]` stringifies ORM Row proxy objects instead of scalar UUID values. Works coincidentally; silently breaks if the query changes. | **[M]** |
| B-BE-17 | `services/retry_worker.py` | ~218 | `asyncio.create_task(_run_metadata(...))` fire-and-forget with no reference stored. On process restart in-flight tasks are dropped and items stay in `processing` state permanently. | **[M]** |
| B-BE-18 | `routers/outfits.py` | — | Malformed ISO datetime cursor silently ignored — pagination resets to page 1 with no 400 response. Client gets wrong results with no indication of the error. | **[L]** |

---

### Improvements

| # | File | Line | Description | Priority |
|---|------|------|-------------|----------|
| I-BE-1 | `routers/auth.py` | — | No rate limiting on `POST /auth/google`. Auth endpoint entirely unprotected from flooding. Add `@limiter.limit("5/minute")`. | **[H]** |
| I-BE-2 | `routers/outfits.py` | — | `POST /outfits` is the only mutating outfit endpoint without `@limiter.limit(...)`. Add before production. | **[H]** |
| I-BE-3 | `routers/notifications.py` | — | Add `PATCH /notifications/{id}/read` and `DELETE /notifications` to complete the notifications CRUD surface. | **[H]** |
| I-BE-4 | Multiple models | — | Missing database indexes on high-traffic filter columns: `WearLog.user_id`, `WearLog.logged_at`, `ClothingItem.user_id`, `ClothingItem.created_at`, `Outfit.user_id`, `Outfit.created_at`. These will cause full-table scans as data grows. | **[H]** |
| I-BE-5 | `routers/analytics.py` | — | Loads every wear-log for the user with no date-range filter or pagination — degrades badly for active users. Add `since` / `until` query params and a hard row cap. | **[M]** |
| I-BE-6 | `schemas/outfit.py` | ~9 | `OutfitResponse.avatar_kind` typed as `str` instead of the `AvatarKind` Literal. Loses type-checking benefit and allows invalid values through. | **[M]** |
| I-BE-7 | `schemas/outfit.py` | — | Add `Field(..., min_length=1)` to `OutfitCreate.items` so Pydantic rejects empty outfits before they reach the DB. | **[M]** |
| I-BE-8 | `services/storage.py` | — | All three storage operations catch bare `Exception` — too broad and hides real errors. Catch specific Supabase/network exceptions. | **[M]** |
| I-BE-9 | `services/style_preferences.py` | — | No rollback on exception mid-function. Wrap the operation in explicit `try/except/rollback` or use a context manager. | **[M]** |
| I-BE-10 | `core/limiter.py` | — | Rate limiter uses in-memory store — resets on restart and doesn't work across multiple workers. Configure a Redis backend for any multi-worker deployment. | **[M]** |
| I-BE-11 | `services/notifications.py` | — | `push_notification()` only calls `db.add()` and trusts the caller to commit. Document the contract explicitly or commit inline. | **[M]** |
| I-BE-12 | `services/retry_worker.py` | — | Stale `failed` queue entries never pruned. Add a cleanup job deleting entries older than 30 days. | **[M]** |
| I-BE-13 | `routers/clothing.py` | ~64 | Invalid cursor silently ignored — pagination resets without informing the caller. Return HTTP 400 for malformed cursors. | **[M]** |
| I-BE-14 | `routers/users.py` | ~122 | `storage.delete_file()` is called synchronously inside an async route. Wrap with `run_in_threadpool()` to avoid blocking the event loop on bulk deletions. | **[M]** |
| I-BE-15 | `main.py` | ~68 | Global exception handler calls `logger.error(msg)` without `exc_info=True` — full traceback is lost in logs. Add `exc_info=True`. | **[M]** |
| I-BE-16 | `db.py` | ~12 | URL conversion replaces `postgresql://` prefix even if the URL already contains a driver spec (e.g. `postgresql+asyncpg://`), creating an invalid double-driver URL. | **[M]** |
| I-BE-17 | `services/fit_scale.py` | ~49 | Silent fallback to `(1.0, 1.0, 1.0)` when `avatar_kind` not found in `_BASELINES`. Should log a warning so missing configurations are caught. | **[L]** |
| I-BE-18 | `services/retry_worker.py` | ~56 | Backoff constants (`60`, `600`, `5`) are magic numbers. Move to `config.py` as `RETRY_BACKOFF_BASE`, `RETRY_MAX_BACKOFF`, `RETRY_INTERVAL_SECS`. | **[L]** |
| I-BE-19 | `models/clothing_item.py` | — | Add soft-delete (`is_deleted` + `deleted_at`) so removed garments don't break outfit history that still references them. | **[L]** |
| I-BE-20 | `routers/outfits.py` | — | Add a max-items-per-outfit guard (e.g. 20) at the router level before inserting. | **[L]** |
| I-BE-21 | `services/ai_vision.py` | ~74 | Bucket name `"clothing-processed"` hardcoded. Move to `settings.PROCESSED_BUCKET`. | **[L]** |
| I-BE-22 | `services/weather.py` | — | Cache TTL uses `time.monotonic()` — not wall-clock time. System suspend/resume can make the cache appear perpetually fresh. Switch to `time.time()`. | **[L]** |
| I-BE-23 | `security.py` | — | `JWT_TTL_HOURS` never validated to be a positive integer. `0` or `-1` silently produces expired tokens on every request. Add a `model_validator` in `Settings`. | **[L]** |
| I-BE-24 | `main.py` | — | CORS uses `allow_methods=["*"]` and `allow_headers=["*"]`. Restrict to specific methods and headers in production. | **[L]** |

---

### Warnings

| # | File | Line | Description |
|---|------|------|-------------|
| W-BE-1 | `config.py` + `auth_provider.dart` | 17 | Hardcoded bypass-auth token `"BYPASS_AUTH_FURQAN_54321"` in source control. Move to a gitignored `.env` entry and rotate immediately. |
| W-BE-2 | `routers/feedback.py` | ~149 | List comprehensions over ORM Row tuples — attribute access (`.style`, `.color`, `.pattern`) raises `AttributeError` at runtime (also listed as B-BE-7). Refactor to use full ORM objects or column-index access. |
| W-BE-3 | `services/weather.py` | — | Outfit generation reads weather context without a null-guard. If `get_current_weather()` returns `None`, the AI prompt builder may crash. |
| W-BE-4 | `routers/upload.py` | — | Per-file size limit enforced (10 MB) but no global request-body limit middleware. Other endpoints accept arbitrarily large bodies. |
| W-BE-5 | `alembic/versions/` | — | Migration `c3d4e5f6a7b8_add_is_starred_to_outfits.py` is untracked in git. Fresh `alembic upgrade head` fails because the file is not in the repository. |
| W-BE-6 | `services/image_processing.py` | ~136 | `Image.LANCZOS` deprecated since Pillow 10.0. Replace with `Image.Resampling.LANCZOS`. |
| W-BE-7 | `deps.py` | ~34 | Commented-out dead RLS code. Remove it or implement it — dead blocks mislead contributors. |
| W-BE-8 | `routers/users.py` | ~22 | `logger` defined at module level but never used. Remove the unused import and instantiation. |
| W-BE-9 | `services/ai_vision.py` | ~160 | `.choices[0].message.content` accessed without null-check. Empty choices list or `content=None` raises `IndexError` / `AttributeError`. |
| W-BE-10 | `services/style_preferences.py` | ~22 | `score: int` type hint should be `score: float` — the surrounding boundary checks (`>= 4`, `<= 2`) imply continuous decimal values. |
| W-BE-11 | Throughout routers | — | Several error-log calls include raw exception strings that may expose internal DB schema details or user IDs. Use structured logging and strip sensitive fields. |

---

## Frontend

### Bugs

| # | File | Line | Description | Severity |
|---|------|------|-------------|----------|
| B-FE-1 | `core/providers/outfits_provider.dart` | — | Parses `GET /outfits` as a flat `List<dynamic>` but backend returns `{"items":[...], "next_cursor":"..."}`. Every load crashes with a type cast error. | **[H]** |
| B-FE-2 | `core/providers/notifications_provider.dart` | — | `markAsRead(id)` calls `PATCH /notifications/$id/read` which does not exist. Optimistic UI update works locally but state never persists — notification reappears unread on next launch. | **[H]** |
| B-FE-3 | `features/try_on/try_on_screen.dart` | — | Garments disposed and cleared inside `RefreshIndicator.onRefresh()`. Navigate-away mid-refresh leaves `_garments` partially cleared; subsequent builds access disposed `ui.Image` objects. | **[H]** |
| B-FE-4 | `features/feedback/ai_feedback_sheet.dart` | ~77 | Condition `outfitId == null && outfit?.items.isNotEmpty` is logically inverted — outfit-level feedback path never executes. Additionally, if `outfit` is `null`, accessing `.items` crashes. | **[H]** |
| B-FE-5 | `features/style_tips/wardrobe_analytics_screen.dart` | ~159 | `asyncLogs.loading` is accessed but `WearLogsState` has no `loading` field — compile-time or runtime error that crashes the analytics screen. | **[H]** |
| B-FE-6 | `features/upload/upload_screen.dart` | ~130 | `unawaited()` used without `import 'dart:async' show unawaited;` — **compilation error** that prevents the upload screen from building entirely. | **[H]** |
| B-FE-7 | `features/auth/sign_in_screen.dart` | ~56 | `googleUser.authentication.idToken` accessed without null-checking `.authentication`. Returns `null` on some Google sign-in failure modes → crash. | **[H]** |
| B-FE-8 | `features/try_on/try_on_screen.dart` | ~289 | `AvatarKind.values.firstWhere((a) => a.name == kind)` throws `StateError` if the backend returns an unrecognised avatar kind. No fallback. | **[M]** |
| B-FE-9 | `core/api/auth_interceptor.dart` | ~33 | `_storage.delete(_tokenKey)` called without `await`. Fire-and-forget deletion means a stale token can persist if the app crashes immediately after. | **[M]** |
| B-FE-10 | `core/services/pose_detection_service.dart` | ~140 | `InputImageRotationValue.fromRawValue(rotation)` is nullable but result used without null check — camera try-on crashes on devices with missing rotation metadata. | **[M]** |
| B-FE-11 | `core/models/clothing_item.dart` | ~52 | `DateTime.parse(created_at)` without try-catch. Any malformed date string from the backend causes an unhandled crash. | **[M]** |
| B-FE-12 | `core/models/wear_log.dart` | ~26 | `DateTime.parse(started_at).toLocal()` — if the backend sends local time (not UTC), calling `.toLocal()` applies an incorrect double-offset. | **[M]** |
| B-FE-13 | `features/wardrobe/style_me_sheet.dart` | — | If outfit generation throws an exception bypassing the `catch` block, `_cancelToken` is left cancelled. Next generation attempt immediately fails without hitting the network. | **[M]** |
| B-FE-14 | `features/camera_try_on/camera_try_on_screen.dart` | — | `_GarmentPickerSheet` shows empty list with no loading indicator when `wardrobeProvider` is still `AsyncLoading`. Looks like an empty wardrobe. | **[M]** |
| B-FE-15 | `features/try_on/try_on_screen.dart` | — | Error response body cast to `Map<String, dynamic>` and `['detail']` accessed without null check. Non-JSON proxy error (e.g. 502) causes a second crash inside the error handler. | **[M]** |
| B-FE-16 | `features/splash/splash_screen.dart` | ~57 | `AppPermissions.requestStartupPermissions(context)` called without `await` before navigation. Permission dialog can appear after screen is disposed → `setState after dispose`. | **[M]** |
| B-FE-17 | `features/upload/upload_screen.dart` | ~89 | `filename.substring(0, filename.lastIndexOf('.'))` — if filename has no `.`, `lastIndexOf` returns `-1` and `substring(-1)` throws `RangeError`. | **[M]** |
| B-FE-18 | `core/providers/auth_provider.dart` | ~31 | `response.data['user']` cast to `Map<String, dynamic>` without null check. Missing `'user'` key throws `TypeError`. | **[M]** |

---

### Improvements

| # | File | Line | Description | Priority |
|---|------|------|-------------|----------|
| I-FE-1 | `core/providers/outfits_provider.dart` | — | Update `_parse()` to unwrap the `OutfitListResponse` envelope — read `data['items']` as the list and store `data['next_cursor']` for pagination. | **[H]** |
| I-FE-2 | `core/providers/wear_logs_provider.dart` | — | `catch (_) {}` swallows all errors with no logging or state update. User gets no feedback when request fails. At minimum call `state = state.copyWith(loading: false)`. | **[M]** |
| I-FE-3 | `core/providers/wardrobe_provider.dart` | ~71 | `fetchMore()` has no in-flight guard — rapid scrolling fires duplicate concurrent requests. Add `_loading` flag and return early if already fetching. | **[M]** |
| I-FE-4 | `features/upload/upload_screen.dart` | — | Upload has no timeout. Stalled connection leaves progress bar frozen forever. Add `sendTimeout` / `receiveTimeout` to Dio options or tie a `CancelToken` to a timer. | **[M]** |
| I-FE-5 | `features/profile_setup/profile_setup_screen.dart` | ~155 | `double.tryParse(...) ?? 0` silently converts invalid height/weight input to zero. Validate input and show an inline error instead. | **[M]** |
| I-FE-6 | `features/profile_setup/profile_setup_screen.dart` | ~191 | `updateProfile()` failure caught and ignored — navigation proceeds anyway. Show a toast so the user knows the save failed. | **[M]** |
| I-FE-7 | `features/wardrobe/edit_clothing_sheet.dart` | ~59 | `AppToast.success()` called after `Navigator.pop()`. Toast may not render on a disposed context. Show the toast before popping. | **[M]** |
| I-FE-8 | `core/providers/fit_rating_provider.dart` | ~26 | `response.data!` non-null assertion without guard. `Null check operator used on a null value` if API returns null body. Use `response.data ?? {}`. | **[M]** |
| I-FE-9 | `features/try_on/try_on_screen.dart` | — | Fit-rating requests repeated every time badge overlay is toggled. Cache results in a local `Map<String, FitRating>` to eliminate redundant API calls. | **[M]** |
| I-FE-10 | `core/providers/wardrobe_provider.dart` | — | `pollUntilComplete()` fired unawaited. Pending items stay in `processing` state with no recovery UI if the app is killed mid-poll. | **[M]** |
| I-FE-11 | `features/style_tips/wardrobe_analytics_screen.dart` | ~421 | `_UnderutilisedList` tile `onTap` calls `Navigator.maybePop()` then has a TODO with no navigation. Dead code — implement or remove. | **[M]** |
| I-FE-12 | `features/wardrobe/style_me_sheet.dart` | — | Failed outfit generation produces no analytics event or structured log. Add a failure event for traceability. | **[M]** |
| I-FE-13 | `features/wardrobe/clothing_card.dart` | ~135 | `onLongPress` still active when `isProcessing` is `true`. User can trigger the action sheet on a garment that hasn't finished processing. Also disable `onLongPress` during processing. | **[M]** |
| I-FE-14 | `camera_try_on_screen.dart` | ~256 | `_lastLoadedIds.join(',') == ids.join(',')` builds strings just for equality. Use `Set` comparison instead: `_lastLoadedIds.toSet().containsAll(ids) && ids.toSet().containsAll(_lastLoadedIds)`. | **[L]** |
| I-FE-15 | `features/profile_setup/profile_setup_screen.dart` | ~305 | Gender stored as raw string literals (`'Female'`, `'Male'`, `'Other'`) scattered across code. Replace with a Dart enum for type safety. | **[L]** |
| I-FE-16 | `core/router/app_router.dart` | ~27 | `_publicPaths` is a hardcoded `Set<String>` that must be manually kept in sync when routes change. Derive from `AppRoute` enum instead. | **[L]** |
| I-FE-17 | `features/camera_try_on/camera_try_on_screen.dart` | — | `_GarmentPickerSheet` has no distinct empty-state vs loading-state UI. Add both branches. | **[L]** |
| I-FE-18 | Multiple screens | — | Icon-only `IconButton`s (bell, wardrobe, profile avatar) have no `tooltip` or `Semantics` label — inaccessible to screen readers. | **[L]** |
| I-FE-19 | `core/api/auth_interceptor.dart` | — | `_cachedToken` never cleared on sign-out. On a shared device, a failed sign-out leaves a stale token in memory for the next user. Clear in the sign-out path. | **[L]** |
| I-FE-20 | `app.dart` | — | No global `ErrorWidget.builder` override. Unhandled widget build exceptions show Flutter's default red error screen in release builds. Replace with a branded fallback. | **[L]** |
| I-FE-21 | `features/profile_setup/profile_setup_screen.dart` | ~156 | Magic constants `30.48` (ft→cm) and `0.453592` (lb→kg) used without comments. Name them as `const double _kFtToCm = 30.48;` etc. | **[L]** |

---

### Warnings

| # | File | Line | Description |
|---|------|------|-------------|
| W-FE-1 | `pubspec.yaml` | — | `url_launcher` still listed as a dependency but all call sites were removed. Remove it from `pubspec.yaml` and run `flutter pub get` to shrink the binary. |
| W-FE-2 | `pubspec.yaml` | — | `google_mlkit_pose_detection: ^0.14.0` is several minor versions behind. Newer releases include ARM64 performance improvements. |
| W-FE-3 | `features/try_on/try_on_screen.dart` | ~289 | `outfit` constructor param is nullable but multiple paths access it without an explicit null check. Either add guards everywhere or make the param non-nullable. |
| W-FE-4 | Multiple providers | — | Several `ref.watch()` call sites access `.value` or `.data` directly on `AsyncValue` without `.when()`, bypassing the loading/error branches and risking `LateInitializationError`. |
| W-FE-5 | Multiple files | — | Mixed use of `.withValues(alpha:)` (modern) and `.withOpacity()` (deprecated). Standardise on `.withValues(alpha:)` throughout. |
| W-FE-6 | `features/style_tips/wardrobe_analytics_screen.dart` | ~89 | List children generated in a loop without `Key` values. Flutter cannot reconcile state correctly when the list reorders. |
| W-FE-7 | `features/wardrobe/wardrobe_screen.dart` | ~378 | `type == widget.filter!.name` — fragile string-based enum matching. If backend renames a type, the filter silently stops working. |
| W-FE-8 | `core/services/pose_detection_service.dart` | ~169 | `clamp(0.0, 1.0)` called immediately after `normalize()`. Normalize already bounds to `[0, 1]` — the clamp is redundant but harmless. |
| W-FE-9 | `macos/Flutter/GeneratedPluginRegistrant.swift` | — | Auto-generated file marked as modified in git. Verify no accidental manual edits; if none, revert it. |
| W-FE-10 | Entire codebase | — | No widget or unit tests found. Core business logic (outfit parsing, wardrobe polling, AI response handling, fit-rating) is entirely untested — any refactor carries hidden regression risk. |

---

## Priority Action Plan

### Fix now — active crashes / compilation failures
1. **B-FE-6** — Add `import 'dart:async' show unawaited;` to `upload_screen.dart` (compilation error).
2. **B-BE-3 (clothing.py)** — Fix partial-column query / `model_validate` mismatch — crashes clothing list.
3. **B-BE-4 / B-BE-5** — Replace `await db.delete(...)` with `await db.execute(delete(...).where(...))` in `auth.py` and `users.py`.
4. **B-FE-1 / B-BE-1** — Align `outfits_provider.dart` with paginated `OutfitListResponse`.
5. **B-FE-4** — Fix inverted condition in `ai_feedback_sheet.dart`.
6. **B-FE-5** — Fix `asyncLogs.loading` reference on `WearLogsState` — crashes analytics screen.

### Fix soon — data integrity, security, silent failures
7. **B-BE-7 / B-BE-8** — Fix `feedback.py` Row tuple attribute access and add item ownership validation.
8. **B-BE-9** — Don't insert DB record until file upload succeeds in `upload.py`.
9. **B-BE-2 / B-FE-2** — Add `PATCH /notifications/{id}/read` to the backend router.
10. **B-BE-6** — Wrap outfit creation in a DB transaction to prevent race-condition `IntegrityError`.
11. **B-FE-7** — Null-check `googleUser.authentication` before accessing `.idToken`.
12. **W-BE-1** — Rotate bypass-auth token and move out of source control immediately.

### Improve — stability & polish
13. **I-BE-1** — Rate-limit the auth endpoint.
14. **I-BE-4** — Add missing DB indexes on `user_id` / `created_at` columns.
15. **B-FE-9 / B-FE-16** — Fix unawaited token deletion and fragile filename parsing.
16. **I-FE-2** — Replace empty `catch (_) {}` in `wear_logs_provider.dart`.
17. **I-FE-7** — Show toast before `Navigator.pop()` in `edit_clothing_sheet.dart`.
18. **W-BE-6** — Replace `Image.LANCZOS` with `Image.Resampling.LANCZOS`.
19. **W-FE-1** — Remove unused `url_launcher` dependency.
