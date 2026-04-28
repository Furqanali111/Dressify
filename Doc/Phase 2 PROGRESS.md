# Dressify — Phase 2 Progress

> Tracks implementation status for all Phase 2 items from PHASE2_3_PLAN.md.
> Updated as each item is completed.

---

## 2.0 Blockers

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 2.0.1 | Remove raw image storage + multi-garment upload | ✅ Done | `image_processing.py`, `upload.py`, `upload_screen.dart` |
| 2.0.2 | Wire profile screen to real data | ✅ Done | `profile_screen.dart` |
| 2.0.3 | Pass avatar kind to outfit generation | ✅ Done | `style_me_sheet.dart`, `ai_provider.dart` |
| 2.0.4 | Auth init race condition | ✅ N/A — splash already awaits `init()` before routing; `/splash` is in public paths so GoRouter redirect cannot fire during init | — |

---

## 2.1 Missing CRUD Endpoints

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 2.1.1 | `PATCH /clothing/{id}` — update metadata | ✅ Done | `clothing.py`, `schemas/clothing.py` |
| 2.1.2 | `GET /outfits/{id}` — fetch single outfit | ✅ Done | `outfits.py` |
| 2.1.3 | `PATCH /outfits/{id}` — rename outfit | ✅ Done | `outfits.py`, `schemas/outfit.py` |
| 2.1.4 | `GET /outfits/{id}/feedback` — fetch past feedback | ✅ Done | `feedback.py` |

---

## 2.2 Input Validation & Schema Hardening

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 2.2.1 | Occasion validated (non-empty, max 50 chars) | ✅ Done | `schemas/outfit.py` |
| 2.2.2 | `avatar_kind` validated as `Literal[...]` enum | ✅ Done | `schemas/outfit.py` |
| 2.2.3 | Name length constraints (`min=1, max=100`) | ✅ Done | `schemas/outfit.py`, `schemas/clothing.py` |
| 2.2.4 | Rate limit on `PATCH /profile` (`10/minute`) | ✅ Done | `profile.py` |

---

## 2.3 Upload Flow — Processing Status Polling

| # | Item | Status | Notes |
|---|------|--------|-------|
| 2.3 | Poll `GET /clothing/{id}` after upload until `completed` | ✅ Done | `wardrobe_provider.dart` (`pollUntilComplete`), `upload_screen.dart` — polls every 3 s, times out after 30 s. |

---

## 2.4 Outfit Position Persistence

| # | Item | Status | Notes |
|---|------|--------|-------|
| 2.4 | Save/restore garment offsets via `OutfitItem.position` | ✅ Done | `try_on_screen.dart` — writes `{dx, dy}` per garment on first save (POST); reads and restores on load. Outfit name is now timestamped (`Outfit M/D HH:mm`) instead of hardcoded `"My Outfit"`. |

---

## 2.5 Wardrobe & Profile Screen Polish

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 2.5.1 | Rename outfit via long-press in wardrobe | ✅ Done | `wardrobe_screen.dart`, `outfits_provider.dart` — long-press → Rename → inline dialog → `PATCH /outfits/{id}`, optimistic state update. |
| 2.5.2 | Edit clothing item metadata via long-press | ✅ Done | `wardrobe_screen.dart`, `wardrobe_provider.dart` — long-press → Edit Details → bottom sheet (name + color) → `PATCH /clothing/{id}`. |
| 2.5.3 | Centralise avatar accent colours in `app_enums.dart` | ✅ Done | `app_enums.dart` (`AvatarKindX.accentForKind` static helper), `wardrobe_screen.dart` (removed `_accentForAvatar` free function). |
| 2.5.4 | Fullscreen button in try-on (was empty `onPressed`) | ✅ Done — now calls `SystemChrome.setEnabledSystemUIMode(immersiveSticky)` | `try_on_screen.dart` |
| 2.5.5 | Edit Profile button (was empty `onTap`) | ✅ Done — navigates to `AppRoute.profileSetup` | `profile_screen.dart` |

---

## 2.6 Security Fixes

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 2.6.1 | Remove secrets from repo (rotate keys, add `.env` to `.gitignore`) | ⬜ Manual action required | `.env`, `.gitignore` |
| 2.6.2 | Gate `BYPASS_AUTH` to debug/dev builds only | ✅ Done | `config.py` (`ENVIRONMENT` + `bypass_auth_enabled` property), `auth.py` (uses `bypass_auth_enabled`), `app_flags.dart` (`kDebugMode &&` guard). |
| 2.6.3 | Align `.env.example` with actual `config.py` keys | ✅ Done | `.env.example` |

---

## 2.7 Backend Test Suite

| # | Item | Status | Notes |
|---|------|--------|-------|
| 2.7 | Real assertions, fixtures, CI integration | ⬜ Pending | `Backend/tests/` — test files exist but have no real assertions yet |

---

## Summary

| Status | Count |
|--------|-------|
| ✅ Done | 21 |
| ⬜ Pending | 1 |
| ⬜ Manual | 1 |

---

## 2.8 Upload Retry Queue

| # | Item | Status | Notes |
|---|------|--------|-------|
| 2.8.1 | `upload_retry_queue` DB model + Alembic migration | ✅ Done | `models/upload_retry_queue.py`, `alembic/versions/d5e6f7a8b9c0_add_upload_retry_queue.py` |
| 2.8.2 | `download_file` + `delete_file` helpers in storage.py | ✅ Done | `services/storage.py` |
| 2.8.3 | Remove silent fallback from `detect_garments_in_image` | ✅ Done | `services/image_processing.py` — raises on model error, returns `[]` when model finds no clothing |
| 2.8.4 | `upload.py` — enqueue retry on detection failure | ✅ Done | `routers/upload.py` — transient failure → `_enqueue_retry()` → 200 + placeholder item; empty detection → 422 immediately |
| 2.8.5 | `retry_worker.py` — async cron that processes the queue | ✅ Done | `services/retry_worker.py` — runs every `RETRY_INTERVAL_SECONDS`, retries up to `UPLOAD_MAX_RETRIES` times, marks `failed` permanently after exhaustion |
| 2.8.6 | Wire worker into FastAPI lifespan | ✅ Done | `main.py` — `asyncio.create_task(run_retry_worker())` in `@asynccontextmanager lifespan` |
| 2.8.7 | `RETRY_INTERVAL_SECONDS` + `UPLOAD_MAX_RETRIES` env vars | ✅ Done | `config.py` — defaults 300 s / 3 attempts |
| 2.8.8 | Frontend failed-state card in wardrobe | ✅ Done | `wardrobe_screen.dart` — `_FailedPlaceholder` widget + error icon; long-press shows Delete-only menu |
| 2.8.9 | Create `clothing-raw-temp` bucket in Supabase | ⬜ Manual | Create via Supabase dashboard — private bucket, no public access |

---

### Remaining items
1. **2.6.1** — Rotate secrets, add `.env` to `.gitignore` (manual — do outside this repo)
2. **2.7** — Backend test suite with real assertions + CI (~3 days dev effort)
3. **2.8.9** — Create `clothing-raw-temp` Supabase bucket (manual, 1 min)

---

## Notes

- Backend error handling for all routers and services was completed in a prior session.
- Multi-garment upload and raw image removal completed in a prior session (see `implementation_plan.md`).
- All Phase 2 dev items are complete. Only the manual secret rotation and the test suite remain.
- Phase 3 items (notifications, settings, social, AI, infra) tracked in `PHASE2_3_PLAN.md`.
- Also fixed two long-standing bugs in `wardrobe_screen.dart`: outfit cards now pass the `Outfit` object to the try-on route (was passing null), and `_accentForAvatar` duplication was consolidated into `AvatarKindX.accentForKind`.
