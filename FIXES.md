# Dressify — Issue Fix Tracker

## P0 — Security

- [x] **#1** Missing rate limit on `update_outfit` — every other mutation endpoint has `@limiter.limit`, this one doesn't (`routers/outfits.py`)
- [x] **#2** No lat/lon bounds validation — `GenerateOutfitRequest.lat/lon` are raw floats with no `-90..90` / `-180..180` check (`routers/outfits.py`)
- [x] **#3** CORS allows credentials with a configurable origins list — no CSRF protection on state-changing endpoints (`main.py`) *(N/A — app uses JWT Bearer tokens, not cookies; CSRF only applies to cookie-based auth)*

## P1 — Functional / Data Integrity

- [x] **#4** Missing DB indexes on `(user_id, created_at)` — pagination queries do full table scans; affects clothing, outfits, wear logs (`models/*.py`)
- [x] **#5** FK columns have no index — `DELETE FROM users` cascades trigger full table scans on all child tables (`models/*.py`)
- [x] **#6** Outfit update is non-atomic — fetch → modify in Python → commit; concurrent writes silently lose one change (`routers/outfits.py`)
- [x] **#7** Rembg global session is not thread-safe — two concurrent uploads can double-initialize the session (`services/image_processing.py:37-45`)
- [x] **#8** `pollUntilComplete` silently swallows all errors — if polling fails, the card shows "processing" forever with no user feedback (`providers/wardrobe_provider.dart:107-138`)
- [x] **#9** Malformed pagination cursor silently resets to page 1 — can cause duplicate items across pages (`routers/wear_logs.py:104-108`)

## P2 — Performance & Quality

- [x] **#10** Outfit feedback: `outfit_image_paths` list is unbounded — fetches all item images before passing to AI (`routers/feedback.py`)
- [x] **#11** Try-on API key only validated at request time — service appears healthy at startup, every request fails with 503 if keys are missing (`routers/tryon.py:188-192`)
- [x] **#12** Tryon cache timestamp can be bypassed with a future-dated file — corrupted timestamps cause either miss or permanent skip (`routers/tryon.py:147-153`)
- [x] **#13** `detect_type_and_anchors()` and `analyze_garment_complete()` appear to be dead code — only `detect_and_analyze_garments()` is called (`services/image_processing.py`)
- [x] **#14** `avatar_kind` defaults to `"maleAverage"` hardcoded — ignores user's saved profile (`routers/outfits.py:290`)
- [x] **#15** `OutfitItemSchema.position` is `dict` — no structure validation; malformed coordinates could crash the renderer (`schemas/outfit.py`)
- [x] **#16** `size_label` validated in service but not at API schema boundary — can be bypassed (`schemas/clothing.py`)
- [x] **#17** Background style-preference update on feedback is fire-and-forget with no error path (`routers/feedback.py:159-167`) *(already has try/except + logger.error in style_preferences.py:54)*
- [x] **#18** Flutter: Multiple screens may not dispose `TextEditingController`s — memory leak on repeated sheet open/close (various `*_sheet.dart`) *(verified — all controllers are properly disposed; outfit_card.dart uses addPostFrameCallback)*
