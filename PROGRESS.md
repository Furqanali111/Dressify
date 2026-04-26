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
| 2.3 | Poll `GET /clothing/{id}` after upload until `completed` | ⬜ Pending | `GET /clothing/{id}` already returns `processing_status`. Need frontend polling loop in `upload_screen.dart` after multi-item upload. |

---

## 2.4 Outfit Position Persistence

| # | Item | Status | Notes |
|---|------|--------|-------|
| 2.4 | Save/restore garment offsets via `OutfitItem.position` | ⬜ Pending | `OutfitItem.position` already persisted in DB. Need try-on screen to write `{dx, dy, scale}` on save and read on load. |

---

## 2.5 Wardrobe & Profile Screen Polish

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 2.5.1 | Rename outfit via long-press in wardrobe | ⬜ Pending | `wardrobe_screen.dart` |
| 2.5.2 | Edit clothing item metadata via long-press | ⬜ Pending | `wardrobe_screen.dart` |
| 2.5.3 | Centralise avatar accent colours in `app_enums.dart` | ⬜ Pending | `app_enums.dart`, `home_screen.dart`, `wardrobe_screen.dart` |
| 2.5.4 | Fullscreen button in try-on (was empty `onPressed`) | ✅ Done — now calls `SystemChrome.setEnabledSystemUIMode(immersiveSticky)` | `try_on_screen.dart` |
| 2.5.5 | Edit Profile button (was empty `onTap`) | ✅ Done — navigates to `AppRoute.profileSetup` | `profile_screen.dart` |

---

## 2.6 Security Fixes

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 2.6.1 | Remove secrets from repo (rotate keys, add `.env` to `.gitignore`) | ⬜ Manual action required | `.env`, `.gitignore` |
| 2.6.2 | Gate `BYPASS_AUTH` to debug/dev builds only | ⬜ Pending | `config.py`, `app_flags.dart` |
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
| ✅ Done | 15 |
| ⬜ Pending | 7 |
| ⬜ Manual | 1 |

### Remaining items (in recommended order)
1. **2.3** — Processing status polling (frontend, ~2h)
2. **2.4** — Outfit position persistence (frontend, ~3h)
3. **2.5.1** — Rename outfit in wardrobe (frontend, ~2h)
4. **2.5.2** — Edit clothing metadata in wardrobe (frontend, ~3h)
5. **2.5.3** — Centralise avatar accent colours (refactor, ~1h)
6. **2.6.1** — Rotate secrets, add `.env` to `.gitignore` (manual)
7. **2.6.2** — Gate bypass auth to debug builds (backend + frontend, ~1h)
8. **2.7** — Backend test suite with real assertions + CI (3 days)

---

## Notes

- Backend error handling for all routers and services was completed in a prior session.
- Multi-garment upload and raw image removal completed in this session (see `implementation_plan.md`).
- Phase 3 items (notifications, settings, social, AI, infra) tracked in `PHASE2_3_PLAN.md`.
