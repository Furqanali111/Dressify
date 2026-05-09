# Dressify — Virtual Try-On App

## Overview
Dressify is a mobile application that allows users to:
- Create / select body-type avatars
- Upload clothing photos — individual garments are automatically extracted
- Visualize outfits via an intelligent 2D anchor-based overlay on their avatar
- Generate AI-curated outfits from their wardrobe (weather-aware)
- Receive AI styling feedback with a score, verdict, and actionable suggestions

---

# Product Vision (MVP)

Deliver a fast and intuitive **2D virtual try-on experience** where users can:
> Upload clothing → garments extracted automatically → auto-fit on avatar → preview instantly → save outfit

Focus: Speed · Simplicity · "Good enough" realism (not perfect)

---

# Technology Stack

## Frontend (Mobile)
- **Flutter + Dart** — single codebase for Android & iOS
- **Riverpod** — reactive state management (providers, notifiers, `AsyncValue`)
- **GoRouter** — declarative navigation with auth-redirect guards
- **Custom Painter** — pixel-level 2D canvas for garment overlay; `paintImage` with anchor alignment
- **dio** — HTTP client with JWT interceptor and 401 → sign-out callback
- **flutter_secure_storage** — JWT stored securely on device
- **cached_network_image / shimmer** — smooth image loading + skeleton loaders

## Backend
- **FastAPI** (async, Python 3.11) — all business logic lives here; frontend never touches Supabase directly
- **SQLAlchemy async** (psycopg3 driver) + **Alembic** migrations
- **Supabase** — managed Postgres + Storage (S3-compatible) + Google OAuth verification
- **slowapi** — per-endpoint rate limiting
- **rembg** (`u2net_cloth_seg` model) — clothing-specific background removal per extracted garment
- **Ollama / Llama 3.2-vision** — local, free vision model for garment bounding-box detection and metadata extraction
- **OpenAI-compatible client** — used for AI outfit generation and styling feedback (switchable between Ollama and OpenAI GPT based on env key)

## Architecture Rule: Thin Frontend, Heavy Backend
- Frontend: UI, input capture, JWT storage, display results
- Backend: auth, image segmentation, garment detection, AI, Supabase persistence
- All Supabase calls (DB + Storage) go through FastAPI — never from the Flutter app directly

---

# Development Phases

---

## Phase 1: Core MVP ✅ Complete

**Goal:** Working end-to-end try-on experience with AI features.

### Authentication & User Management
- **Google Sign-In (OAuth 2.0)** — Flutter triggers Google sign-in, sends `id_token` to `/auth/google`; Supabase verifies it and the backend issues its own JWT (168 h TTL).
- **JWT session management** — stored in `flutter_secure_storage`; a Dio interceptor attaches it to every request and clears it on 401.
- **Bypass auth for development** — `BYPASS_AUTH_FURQAN_54321` flag accepted only when `ENVIRONMENT != production` on the backend and `kDebugMode == true` on the frontend; a visible badge prevents accidental shipping.
- **Splash / init sequence** — splash screen awaits `authStateProvider.init()` before routing, preventing race conditions between JWT restore and GoRouter redirect.

### Profile & Avatar
- **Profile setup** — users enter name, height (cm), weight (kg), body type, and gender; stored in a `profiles` table linked to the user.
- **10-avatar system** — Slim / Athletic / Average / Curvy / Plus × Female / Male; each avatar has a unique accent colour and asset path defined in `AvatarKindX` extension.
- **Profile → avatar kind linkage** — `avatar_kind` stored on the profile and passed to outfit generation and the try-on screen automatically.

### Clothing Upload & Multi-Garment Extraction
- **Multi-garment detection** — Llama 3.2-vision (via local Ollama) analyses the uploaded photo and returns normalised bounding boxes for every visible garment (up to 6).
- **Per-garment extraction + bg removal** — each bounding box is cropped with padding, resized to ≤ 1024 px, then passed through `rembg` with the `u2net_cloth_seg` model; result is a clean PNG on a transparent background.
- **AI metadata extraction (background task)** — after upload, a `BackgroundTask` calls Llama again per garment to extract colour, pattern, style, and sub-type, then writes them to the DB asynchronously.
- **No raw image storage** — only the extracted, background-removed garment is stored in Supabase (`clothing-processed` bucket); the original user photo is never persisted.
- **Upload returns a list** — endpoint returns `list[ClothingItemResponse]`; frontend handles single-item (show image + Try On) and multi-item (summary card + item chips) responses differently.

### Upload Retry Queue *(added during Phase 1 hardening)*
- **Silent-fallback removed** — `detect_garments_in_image` now raises on model/network error instead of falling back to a full-image dummy; only returns `[]` when the model genuinely finds no clothing (→ immediate 422).
- **Retry queue table** — `upload_retry_queue` stores the raw image path, attempt count, and `next_retry_at`; linked to a placeholder `ClothingItem` (status `processing`) shown immediately in the user's wardrobe.
- **Async retry worker** — `run_retry_worker()` runs as an `asyncio` task in the FastAPI lifespan; polls the queue every `RETRY_INTERVAL_SECONDS` (default 300 s, env-configurable), re-runs detection + extraction + classification, updates the placeholder on success, marks it `failed` after `UPLOAD_MAX_RETRIES` attempts.
- **Failed state in UI** — wardrobe cards with `processing_status == failed` show an error icon and "Detection failed — hold to delete" subtitle; long-press shows Delete-only menu.

### Auto-Overlay Engine (Try-On Screen)
- **Anchor-based positioning** — backend classifies each garment's type and returns anchor points (shoulder, chest, waist, hip, feet); the `_ClothingPainter` aligns the garment's internal anchor to the avatar's corresponding anchor point.
- **Per-garment manual offset** — users can drag individual garments; offsets are stored per garment in `_GarmentData.offset` and persisted to `OutfitItem.position` on save.
- **Depth ordering** — garments are painted in type-depth order (shoes → bottoms → dress → tops/jackets) so layering looks natural.
- **Avatar switcher** — try-on screen reads the user's profile `avatar_kind` on load; a horizontal picker lets the user change avatar mid-session.
- **Fullscreen mode** — toolbar button calls `SystemChrome.setEnabledSystemUIMode(immersiveSticky)` to hide OS chrome.

### AI Outfit Generation
- **Occasion-based generation** — user picks an occasion (Casual, Work, Party, etc.); the backend queries the wardrobe and asks the LLM to select a coherent outfit.
- **Weather-aware** — if the user grants location, lat/lon are passed to the generation endpoint; the LLM incorporates local weather into its outfit choice.
- **Avatar kind forwarded** — `avatar_kind` from the user's profile is included in the generation request so the LLM can account for body proportions.

### AI Styling Feedback
- **Structured response** — feedback endpoint returns a `score` (1–10), a `verdict` string, and a `suggestions` list; validated server-side before returning.
- **Outfit or ad-hoc** — feedback can be requested for a saved outfit ID or for an arbitrary list of clothing item IDs.
- **Feedback history** — `GET /outfits/{id}/feedback` retrieves the most recent feedback for a saved outfit.

### Wardrobe Management
- **Clothing CRUD** — `GET`, `DELETE`, and `PATCH /clothing/{id}` (update name, type, colour, pattern, style, sub_type).
- **Outfit CRUD** — `GET`, `DELETE`, and `PATCH /outfits/{id}` (rename); `GET /outfits/{id}` fetches a single outfit with its items.
- **Position persistence** — garment offsets (`dx`, `dy`) are saved to `OutfitItem.position` (JSONB) on first save; restored when the outfit is loaded in try-on.
- **Timestamped outfit names** — new outfits saved from the try-on screen are named `Outfit M/D HH:mm` instead of the hardcoded "My Outfit".
- **Processing status polling** — after upload, the frontend polls `GET /clothing/{id}` every 3 s (up to 30 s) and updates the wardrobe card as items transition from `processing` → `completed`.

### Wardrobe Screen Polish
- **Rename outfit** — long-press → "Rename" → `AlertDialog` with text field → `PATCH /outfits/{id}`; optimistic state update in provider.
- **Edit clothing metadata** — long-press → "Edit Details" → bottom sheet (name + colour fields) → `PATCH /clothing/{id}`; state replaced with server response.
- **Outfit cards pass outfit to try-on** — fixed a bug where tapping/long-pressing an outfit card navigated to an empty try-on canvas; now passes `extra: outfit` correctly via GoRouter.
- **Centralised avatar accent colours** — `AvatarKindX.accentForKind(String, {required Color fallback})` static helper added; duplicate `_accentForAvatar()` free functions removed from screen files.

### Backend Infrastructure
- **Input validation** — Pydantic `Field(min_length, max_length)` on all name/occasion fields; `avatar_kind` validated as a `Literal[…]` enum across schemas.
- **Rate limiting** — `slowapi` decorators on all mutating endpoints (upload: 5/min, profile patch: 10/min, clothing patch: 20/min, etc.).
- **Structured error handling** — all routers distinguish `AuthApiError` (401), `IntegrityError` (409/500 with rollback), network errors (503), and generic exceptions (500 with logging).
- **Auth bypass gating** — backend reads `ENVIRONMENT` env var; bypass token only accepted when `ENVIRONMENT != production`. Frontend guards with `kDebugMode`.

---

## Phase 2: Polish, Hardening & Production Readiness ✅ Complete

**Goal:** Close gaps between prototype and shippable product — real data everywhere, no hardcoded strings, security gates, resilient upload pipeline.

> All items in this phase were tracked in `PROGRESS.md` and are now complete except for the manual secret-rotation step and the backend test suite.

### Completed
- All missing CRUD endpoints implemented (`PATCH /clothing/{id}`, `GET /outfits/{id}`, `PATCH /outfits/{id}`, `GET /outfits/{id}/feedback`)
- Profile screen wired to real auth + profile data (no more hardcoded display names or stats)
- Schema validation hardened across all request bodies
- Rate limits added to remaining mutating endpoints
- Upload retry queue + async worker (see Phase 1 section above — implemented mid-phase)
- Wardrobe screen: rename outfit, edit clothing metadata, failed-item state
- Try-on screen: garment position save/restore, timestamped outfit name, fullscreen button
- Avatar accent colour centralised into `AvatarKindX.accentForKind`
- Bypass auth gated to debug builds on both backend and frontend
- `.env.example` aligned with actual `config.py` keys

### Remaining
- **Secret rotation** (manual) — rotate Supabase keys and add `.env` to `.gitignore`.
- **`clothing-raw-temp` bucket** (manual) — create in Supabase dashboard for the retry worker.
- **Backend test suite** — `Backend/tests/` exists but has no real assertions yet; needs pytest fixtures, DB fixtures, auth fixtures, and CI integration (~3 days).

---

## Phase 3: Camera & Real-Time Try-On ✅ Complete

**Goal:** Let users see outfits overlaid on a live camera feed.

- **Real-time camera feed** — `camera` package (`CameraController`, `ResolutionPreset.medium`); front/back flip; lifecycle-aware pause/resume.
- **On-device pose detection** — `google_mlkit_pose_detection` analyses camera image stream frames (NV21 on Android, BGRA8888 on iOS); ML Kit keypoints normalised to display coordinates; throttled to one detection per 250 ms.
- **Live garment overlay** — `CameraOverlayPainter` (`CustomPainter`) aligns garment images to pose anchors (shoulder, chest, waist, hip, feet); shoulder-span-proportional sizing; same depth ordering (shoes → bottom → dress → top/jacket) as the avatar try-on.
- **"See on Me" per clothing item** — each wardrobe card has a camera icon button; tapping it sets `cameraGarmentsProvider` and switches to the Camera tab with the item pre-loaded; also available in the long-press action sheet.
- **Camera tab in bottom nav** — replaced Wardrobe tab; `CameraTryOnScreen(tabMode: true)` watches `cameraGarmentsProvider` and shows an empty-state guide ("Open any item and tap See on Me") until items are selected.
- **Capture & share** — `RepaintBoundary.toImage()` composites the live preview and garment overlay into a PNG; preview dialog with Retake / Share (`share_plus`).
- **Garment chip bar** — in camera tab, active garments shown as dismissible chips with a "clear all" ×; modal mode shows read-only name chips.

---

## Phase 4: Personalization & Advanced Fitting ✅ Complete

**Goal:** Make the fit feel personal and accurate — measurements inform garment scaling, AI learns taste over time, and analytics surface wardrobe insights.

### 4.1 Body Measurements & Real-Time Garment Scaling
- **Profile measurement fields** — `chest_cm`, `waist_cm`, `hip_cm`, `shoulder_cm` added to `profiles` via Alembic migration; profile PATCH/GET endpoints and `ProfileResponse` schema updated.
- **Fit scale helper** — `compute_fit_scales()` derives per-garment-type scale factors (top/bottom/dress) by comparing user measurements against per-avatar baseline tables; exposed as `fit_scale_top/bottom/dress` on `ProfileResponse` via `@model_validator`.
- **Optional measurement step** — profile setup gains an expandable "Body Measurements" section (skippable); profile screen gains a `_MeasurementsCard` showing cm pills and a "Fit personalised ✓" row; dedicated edit sheet with inline validation.
- **`FitScalesProvider`** — Riverpod provider reads `profileProvider`, derives `{top, bottom, dress}` scale factors; falls back to 1.0 when measurements are absent.
- **Try-on canvas scaling** — `_ClothingPainter` multiplies garment dimensions by the relevant scale factor; "Fit personalised" chip shown when active.
- **Camera overlay scaling** — `CameraOverlayPainter` applies the same scale factor to shoulder-span-proportional garment sizing.

### 4.2 Size-Aware Fitting
- **Garment size metadata** — `size_label` (XS/S/M/L/XL/XXL/One Size) and `fit_notes` columns added to `clothing_items` via Alembic migration; Llama vision prompt updated to extract `size_label` automatically on upload.
- **Size badge in wardrobe** — clothing cards show a small size chip in the top-right corner; edit-details sheet exposes a `size_label` dropdown.
- **Fit rating service** — `compute_fit_rating(size_label, garment_type, measurements)` uses a size-range lookup table to return `fit_rating: "perfect"|"may_be_snug"|"runs_large"|"unknown"` with a `confidence` float.
- **`GET /clothing/{id}/fit`** — authenticated endpoint (rate-limited 30/min) backed by the fit rating service.
- **Fit indicator in try-on** — "Check Fit" icon button in the top bar triggers `FitRatingProvider` (family provider) for all loaded garments; coloured pills rendered on canvas (✅ green / ⚠️ amber / 🔵 blue) and as floating labels in the camera overlay.

### 4.3 Style Preference Learning
- **Database tables** — `user_style_preferences` (JSONB `liked_colors`, `liked_styles`, `liked_patterns`, `disliked_styles`) and `outfit_interactions` (action enum: viewed/tried/saved/dismissed/shared) created via Alembic migration.
- **`POST /interactions`** — logs an outfit interaction event and upserts the `user_style_preferences` summary in the same request.
- **`GET /users/me/style-profile`** and **`PATCH /users/me/style-profile`** — fetch and manually override preference fields.
- **Background preference update** — `update_style_preferences_from_feedback()` runs as a FastAPI `BackgroundTask` after every feedback `POST`; increments liked/disliked fields based on score and suggestion keywords.
- **AI-aware generation** — outfit generation prompt includes a "User style profile" block when preferences exist; `OutfitGenerationResponse` adds a `personalized: bool` flag.
- **Style Profile UI** — profile screen "My Style DNA" section shows colour swatches and style/pattern chips; `StyleDnaSheet` provides chip-based multi-select with `PATCH` save; "✨ Personalised for you" banner shown in the Style Me sheet and AI tips result card.
- **Interaction logging in app** — `POST /interactions` fired automatically on outfit try-on open (`tried`), outfit save (`saved`), and AI suggestion dismiss (`dismissed`).

### 4.4 Wardrobe Analytics & Style Tips Screen
- **Wear logging** — `wear_logs` table (`user_id`, `outfit_id` nullable, `clothing_item_ids[]`, `logged_at`); `POST /wear-logs` (rate-limited 60/min); auto-logged silently whenever a user opens the try-on screen for an existing outfit.
- **Analytics endpoint** — `GET /analytics/wardrobe` (rate-limited 10/min) returns: `most_worn` (top 5 by log count), `underutilised` (no wear in 30 days), `color_distribution` map, `style_breakdown` map, `outfit_frequency` (ISO-week counts, 4-week window), `total_items`, `total_outfits`.
- **Style Tips screen** — dedicated `/style-tips` route (modal, pushed above shell); sections: stats header cards, colour palette donut chart (`CustomPainter`, no new dep), most-worn horizontal scroll, underutilised item chips, style breakdown horizontal bar chart, AI Style Suggestions (occasion chips + generate button → outfit result card with "Try It").
- **Home Quick Actions wired** — "Style Tips" tile navigates to `/style-tips` via `context.pushNamed`; replaced the former `StyleMeSheet` modal shortcut.
- **`WardrobeAnalyticsProvider`** — `AsyncNotifier`; fetches and caches analytics with pull-to-refresh support.

---

## Phase 5: Social + Commerce (Planned)

**Goal:** Community and discovery layer.

- Post outfits to a social feed; like, comment, follow other users
- Brand / store upload portal — retailers can upload their catalogue for users to try on
- Purchase integration — tap a garment in the try-on screen to buy it
- Shared outfit links — deep-linkable outfit previews

---

## Phase 6: 3D Upgrade (Planned)

**Goal:** Photorealistic fitting.

- 3D avatars (parametric body model, e.g. SMPL)
- Cloth simulation (drape, wrinkle, gravity)
- Realistic material rendering
- GPU-accelerated rendering pipeline

---

# MVP Success Criteria

| Criterion | Status |
|---|---|
| User can upload clothing and garments are extracted automatically | ✅ |
| Clothing auto-fits correctly on avatar (~80% accuracy) | ✅ |
| Smooth wardrobe and try-on preview experience | ✅ |
| User can save outfits and reload them with correct positioning | ✅ |
| AI provides structured, useful styling feedback | ✅ |
| AI generates outfit suggestions from wardrobe | ✅ |
| Transient upload failures are retried automatically | ✅ |
| Auth bypass cannot reach production | ✅ |
| Garment scaling personalised to body measurements | ✅ |
| Size-aware fit rating shown per garment in try-on | ✅ |
| AI outfit generation learns from user style preferences | ✅ |
| Wardrobe analytics and Style Tips screen available | ✅ |

---

# Key Constraints

- No full 3D modeling in MVP (2D overlay only)
- No complex cloth physics
- No perfect garment fitting required — anchor-based positioning targets ~80% accuracy
- Llama 3.2-vision used locally via Ollama (free, no API cost for detection/metadata)
- Frontend never calls Supabase directly — all DB/storage access through FastAPI

---

# Open Action Items
