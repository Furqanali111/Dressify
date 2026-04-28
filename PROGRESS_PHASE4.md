# Dressify — Phase 4 Progress: Personalization & Advanced Fitting

> Tracks implementation status for all Phase 4 items.
> Mark each item ✅ Done the moment it is complete — not at the end of the sub-phase.

---

## 4.1 Body Measurements & Real-Time Garment Scaling

### 4.1.1 Backend — Schema & Migration

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.1.1.1 | Alembic migration: add `chest_cm`, `waist_cm`, `hip_cm`, `shoulder_cm` (nullable float) to `profiles` | ✅ Done | `Backend/alembic/versions/e6f7a8b9c0d1_add_body_measurements_to_profiles.py` |
| 4.1.1.2 | SQLAlchemy `Profile` model: add four measurement columns | ✅ Done | `Backend/app/models/profile.py` |
| 4.1.1.3 | `ProfileResponse` schema: expose measurement fields | ✅ Done | `Backend/app/schemas/profile.py` |
| 4.1.1.4 | `ProfilePatch` schema: accept measurement fields (all optional) | ✅ Done | `Backend/app/schemas/profile.py` |
| 4.1.1.5 | Profile PATCH endpoint: persist measurements | ✅ Done | `Backend/app/routers/profile.py` (no change needed — generic `model_dump(exclude_unset=True)`) |

### 4.1.2 Backend — Fit Scale Helper

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.1.2.1 | `compute_fit_scales(avatar_kind, chest_cm, waist_cm, hip_cm, shoulder_cm) → tuple[float,float,float]` | ✅ Done | `Backend/app/services/fit_scale.py` |
| 4.1.2.2 | Avatar baseline measurements table — chest/waist/hip/shoulder defaults per `avatar_kind` | ✅ Done | `Backend/app/services/fit_scale.py` |
| 4.1.2.3 | Expose `fit_scale_top`, `fit_scale_bottom`, `fit_scale_dress` in `ProfileResponse` via `@model_validator` | ✅ Done | `Backend/app/schemas/profile.py` |

### 4.1.3 Frontend — Measurement UI

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.1.3.1 | `BodyMeasurements` Dart model (merged into `Profile` directly — no separate model needed) | ✅ Done | `Frontend/lib/core/models/profile.dart` |
| 4.1.3.2 | `Profile` model: add `chestCm`, `waistCm`, `hipCm`, `shoulderCm`, fit scale fields, `hasMeasurements`, `isFitPersonalized` | ✅ Done | `Frontend/lib/core/models/profile.dart` |
| 4.1.3.3 | Profile setup: optional expandable "Body Measurements" section with 4 cm input fields | ✅ Done | `Frontend/lib/features/profile_setup/profile_setup_screen.dart` |
| 4.1.3.4 | Profile screen: `_MeasurementsCard` showing chest/waist/hip/shoulder pills; "Fit personalised ✓" row | ✅ Done | `Frontend/lib/features/profile/profile_screen.dart` |
| 4.1.3.5 | Measurements edit sheet: 4 text fields with cm suffix, inline validation, Save / Cancel | ✅ Done | `Frontend/lib/features/profile/measurements_sheet.dart` |
| 4.1.3.6 | `PATCH /profile` call from edit sheet; `profileProvider` updated on success | ✅ Done | `Frontend/lib/features/profile/measurements_sheet.dart` |

### 4.1.4 Frontend — Garment Scaling

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.1.4.1 | `FitScalesProvider` — reads `profileProvider`, derives `{top, bottom, dress}` scale factors; falls back to 1.0 when measurements absent | ✅ Done | `Frontend/lib/core/providers/fit_scale_provider.dart` |
| 4.1.4.2 | Try-on canvas (`_ClothingPainter`): multiply garment render size by fit scale factor for the garment's type | ✅ Done | `Frontend/lib/features/try_on/try_on_screen.dart` |
| 4.1.4.3 | Camera overlay (`_CameraOverlayPainter`): apply same scale factor to shoulder-span-proportional garment width | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| 4.1.4.4 | Try-on screen: show "Fit personalised" chip when `fitScales.isPersonalized` | ✅ Done | `Frontend/lib/features/try_on/try_on_screen.dart` |

---

## 4.2 Size-Aware Fitting

### 4.2.1 Backend — Schema & Metadata

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.2.1.1 | Alembic migration: add `size_label` VARCHAR(10) and `fit_notes` TEXT (both nullable) to `clothing_items` | ⬜ Todo | `Backend/alembic/versions/` |
| 4.2.1.2 | `ClothingItem` model: add `size_label`, `fit_notes` columns | ⬜ Todo | `Backend/app/models/clothing.py` |
| 4.2.1.3 | `ClothingItemResponse` schema: expose `size_label`, `fit_notes` | ⬜ Todo | `Backend/app/schemas/clothing.py` |
| 4.2.1.4 | Llama metadata extraction: extend prompt to extract `size_label` (XS/S/M/L/XL/XXL/One Size/Unknown) | ⬜ Todo | `Backend/app/services/clothing_metadata.py` |
| 4.2.1.5 | `ClothingPatch` schema: expose `size_label`, `fit_notes` for manual edit | ⬜ Todo | `Backend/app/schemas/clothing.py` |

### 4.2.2 Backend — Fit Rating Endpoint

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.2.2.1 | `fit_rating_service.py`: `compute_fit_rating(size_label, garment_type, measurements) → {fit_rating, confidence}` using size-range lookup table | ⬜ Todo | `Backend/app/services/fit_rating.py` |
| 4.2.2.2 | `GET /clothing/{id}/fit` endpoint — requires auth; returns `FitRatingResponse` | ⬜ Todo | `Backend/app/routers/clothing.py` |
| 4.2.2.3 | `FitRatingResponse` Pydantic schema: `fit_rating: Literal["perfect","may_be_snug","runs_large","unknown"]`, `confidence: float` | ⬜ Todo | `Backend/app/schemas/clothing.py` |
| 4.2.2.4 | Rate limit `GET /clothing/{id}/fit` at 30/minute | ⬜ Todo | `Backend/app/routers/clothing.py` |

### 4.2.3 Frontend — Size UI

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.2.3.1 | Wardrobe `_ClothingCard`: show `size_label` chip in top-right corner of card | ⬜ Todo | `Frontend/lib/features/wardrobe/wardrobe_screen.dart` |
| 4.2.3.2 | Edit-details bottom sheet: add `size_label` dropdown (XS/S/M/L/XL/XXL/One Size) | ⬜ Todo | `Frontend/lib/features/wardrobe/wardrobe_screen.dart` |
| 4.2.3.3 | `FitRatingProvider(clothingItemId)` — family provider; fetches `GET /clothing/{id}/fit` lazily | ⬜ Todo | `Frontend/lib/core/providers/fit_rating_provider.dart` |
| 4.2.3.4 | Try-on screen: "Check Fit" icon button in top bar; triggers `FitRatingProvider` for all loaded garments | ⬜ Todo | `Frontend/lib/features/try_on/try_on_screen.dart` |
| 4.2.3.5 | Fit badge widget: small coloured pill (✅ green / ⚠️ amber / 🔵 blue) painted over each garment in the canvas | ⬜ Todo | `Frontend/lib/features/try_on/try_on_screen.dart` |
| 4.2.3.6 | Fit badge in camera overlay — shown as floating label near each garment | ⬜ Todo | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |

---

## 4.3 Style Preference Learning

### 4.3.1 Backend — Schema & Tables

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.3.1.1 | Alembic migration: create `user_style_preferences` table (user_id PK FK, liked_colors JSONB, liked_styles JSONB, liked_patterns JSONB, disliked_styles JSONB, updated_at) | ⬜ Todo | `Backend/alembic/versions/` |
| 4.3.1.2 | Alembic migration: create `outfit_interactions` table (id UUID PK, user_id FK, action ENUM[viewed/tried/saved/dismissed/shared], clothing_item_ids JSONB, outfit_id UUID nullable FK, created_at) | ⬜ Todo | `Backend/alembic/versions/` |
| 4.3.1.3 | SQLAlchemy models: `UserStylePreference`, `OutfitInteraction` | ⬜ Todo | `Backend/app/models/` |

### 4.3.2 Backend — Endpoints & Background Tasks

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.3.2.1 | `GET /users/me/style-profile` — returns preferences + interaction counts | ⬜ Todo | `Backend/app/routers/users.py` |
| 4.3.2.2 | `PATCH /users/me/style-profile` — manual override of any preference field | ⬜ Todo | `Backend/app/routers/users.py` |
| 4.3.2.3 | `POST /interactions` — log an outfit interaction event; upserts `user_style_preferences` summary | ⬜ Todo | `Backend/app/routers/interactions.py` |
| 4.3.2.4 | Background task `update_style_preferences_from_feedback(user_id, feedback)` — runs after feedback POST; increments liked/disliked fields based on score and suggestions | ⬜ Todo | `Backend/app/services/style_preferences.py` |
| 4.3.2.5 | Wire background task into feedback POST endpoint | ⬜ Todo | `Backend/app/routers/outfits.py` |
| 4.3.2.6 | Outfit generation: inject "User style profile" block into system prompt when preferences exist | ⬜ Todo | `Backend/app/services/outfit_generator.py` |
| 4.3.2.7 | `OutfitGenerationResponse`: add `personalized: bool` flag | ⬜ Todo | `Backend/app/schemas/outfits.py` |

### 4.3.3 Frontend — Style Profile UI

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.3.3.1 | `StyleProfile` Dart model (likedColors, likedStyles, likedPatterns, dislikedStyles) | ⬜ Todo | `Frontend/lib/core/models/style_profile.dart` |
| 4.3.3.2 | `styleProfileProvider` — fetches `GET /users/me/style-profile`; `AsyncNotifier` | ⬜ Todo | `Frontend/lib/core/providers/style_profile_provider.dart` |
| 4.3.3.3 | Profile screen: "My Style DNA" section — colour swatches row + style/pattern tag chips | ⬜ Todo | `Frontend/lib/features/profile/profile_screen.dart` |
| 4.3.3.4 | Style DNA edit sheet — chip-based multi-select for colors, styles, patterns; calls `PATCH /users/me/style-profile` | ⬜ Todo | `Frontend/lib/features/profile/style_dna_sheet.dart` |
| 4.3.3.5 | Interaction logging: `POST /interactions` called on outfit try-on open (`tried`), outfit save (`saved`), AI suggestion dismiss (`dismissed`) | ⬜ Todo | Multiple screens |
| 4.3.3.6 | Outfit generation result: show "✨ Personalized for you" banner when `personalized == true` | ⬜ Todo | `Frontend/lib/features/wardrobe/style_me_sheet.dart` |

---

## 4.4 Wardrobe Analytics & Style Tips Screen

### 4.4.1 Backend — Wear Logging

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.4.1.1 | Alembic migration: create `wear_logs` table (id UUID PK, user_id FK, outfit_id UUID nullable FK, clothing_item_ids JSONB, logged_at timestamp) | ⬜ Todo | `Backend/alembic/versions/` |
| 4.4.1.2 | `WearLog` SQLAlchemy model | ⬜ Todo | `Backend/app/models/wear_log.py` |
| 4.4.1.3 | `POST /wear-logs` endpoint — log a wear event; rate limited 60/minute | ⬜ Todo | `Backend/app/routers/wear_logs.py` |

### 4.4.2 Backend — Analytics Endpoint

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.4.2.1 | `GET /analytics/wardrobe` — returns `WardrobeAnalyticsResponse` | ⬜ Todo | `Backend/app/routers/analytics.py` |
| 4.4.2.2 | `WardrobeAnalyticsResponse` schema: `most_worn` list, `underutilised` list, `color_distribution` dict, `style_breakdown` dict, `outfit_frequency` list (weekly), `total_items` int, `total_outfits` int | ⬜ Todo | `Backend/app/schemas/analytics.py` |
| 4.4.2.3 | Analytics query: `most_worn` — join `wear_logs` ↔ `clothing_items`, top 5 by log count | ⬜ Todo | `Backend/app/routers/analytics.py` |
| 4.4.2.4 | Analytics query: `underutilised` — items with no `wear_logs` entry in the last 30 days | ⬜ Todo | `Backend/app/routers/analytics.py` |
| 4.4.2.5 | Analytics query: `color_distribution` — group clothing items by `color` field | ⬜ Todo | `Backend/app/routers/analytics.py` |
| 4.4.2.6 | Analytics query: `outfit_frequency` — wear log counts grouped by ISO week, last 4 weeks | ⬜ Todo | `Backend/app/routers/analytics.py` |
| 4.4.2.7 | Rate limit `GET /analytics/wardrobe` at 10/minute | ⬜ Todo | `Backend/app/routers/analytics.py` |
| 4.4.2.8 | Register analytics router in `app/main.py` | ⬜ Todo | `Backend/app/main.py` |

### 4.4.3 Frontend — Style Tips Screen

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 4.4.3.1 | `WardrobeAnalytics` Dart model | ⬜ Todo | `Frontend/lib/core/models/wardrobe_analytics.dart` |
| 4.4.3.2 | `wardrobeAnalyticsProvider` — `AsyncNotifier`; fetches `GET /analytics/wardrobe` | ⬜ Todo | `Frontend/lib/core/providers/wardrobe_analytics_provider.dart` |
| 4.4.3.3 | `AppRoute.styleTips('/style-tips')` added to `app_routes.dart` | ⬜ Todo | `Frontend/lib/core/router/app_routes.dart` |
| 4.4.3.4 | `styleTips` route added to `app_router.dart` (modal, `parentNavigatorKey: _rootNavigatorKey`) | ⬜ Todo | `Frontend/lib/core/router/app_router.dart` |
| 4.4.3.5 | `StyleTipsScreen` scaffold — `RefreshIndicator` + `SingleChildScrollView`; loading/error/data states | ⬜ Todo | `Frontend/lib/features/style_tips/style_tips_screen.dart` |
| 4.4.3.6 | Stats header section: "X items · Y outfits" summary cards with icons | ⬜ Todo | `Frontend/lib/features/style_tips/style_tips_screen.dart` |
| 4.4.3.7 | Colour palette section: `ColorPiePainter` (`CustomPainter`) drawing wedges from `color_distribution`; legend below | ⬜ Todo | `Frontend/lib/features/style_tips/style_tips_screen.dart` |
| 4.4.3.8 | Most-worn section: horizontal `ListView` of up to 5 clothing cards with wear-count badge | ⬜ Todo | `Frontend/lib/features/style_tips/style_tips_screen.dart` |
| 4.4.3.9 | Underutilised section: "These haven't been worn in 30 days" with dismissible item chips; tap navigates to wardrobe | ⬜ Todo | `Frontend/lib/features/style_tips/style_tips_screen.dart` |
| 4.4.3.10 | Style breakdown section: horizontal bar chart (CustomPainter) of top styles | ⬜ Todo | `Frontend/lib/features/style_tips/style_tips_screen.dart` |
| 4.4.3.11 | AI Style Tips section: embed existing `StyleMeSheet` content inline (LLM seasonal advice, occasion suggestions) | ⬜ Todo | `Frontend/lib/features/style_tips/style_tips_screen.dart` |
| 4.4.3.12 | Home screen Quick Actions: "Style Tips" tile → `context.pushNamed(AppRoute.styleTips.name)` instead of `showModalBottomSheet` | ⬜ Todo | `Frontend/lib/features/home/home_screen.dart` |
| 4.4.3.13 | Auto-log wear on try-on screen open for existing outfit (`POST /wear-logs` with `outfit_id`) | ⬜ Todo | `Frontend/lib/features/try_on/try_on_screen.dart` |

---

## Summary

| Status | Count |
|--------|-------|
| ✅ Done | 18 |
| ⬜ Todo | 37 |

---

## Sub-Phase Completion Checklist

| Sub-Phase | Items | Done | Status |
|---|---|---|---|
| 4.1 Body Measurements & Scaling | 18 | 18 | ✅ Complete |
| 4.2 Size-Aware Fitting | 11 | 0 | ⬜ Not started |
| 4.3 Style Preference Learning | 13 | 0 | ⬜ Not started |
| 4.4 Analytics & Style Tips | 16 | 0 | ⬜ Not started |
| **Total** | **58** | **17** | |
