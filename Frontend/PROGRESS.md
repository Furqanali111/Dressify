# Dressify Mobile — Frontend Progress

Tracker for the Flutter mobile app build. Source of truth for visual/UX spec is `Dressify_Frontend_Prompt.md`; architecture rules live in `Project_Plan.md` and the Claude memory `architecture_thin_frontend.md`.

## How to run

Runtime config lives in `Frontend/.env` (gitignored). Copy `.env.example` → `.env` on a fresh checkout and edit values per machine. Hot-restart picks up changes; no rebuild needed.

```bash
# Standard run — reads .env
flutter run

# Override a single value per build (still works, takes precedence over .env)
flutter run --dart-define=BYPASS_AUTH=false
flutter run --dart-define=API_BASE_URL=https://api.dressify.app
```

Lookup order for every flag in `lib/core/config/app_flags.dart::AppFlags`:
1. `--dart-define=KEY=value` (compile-time override)
2. `.env` (runtime)
3. Hardcoded fallback

Currently exposed: `BYPASS_AUTH`, `API_BASE_URL`, `SENTRY_DSN`. When `BYPASS_AUTH=true`, splash and sign-in show a visible "AUTH BYPASSED" badge so it can't ship accidentally.

> ⚠️ The `.env` file is bundled as a Flutter asset and ships inside the app. Never put secrets there (OAuth client secrets, signing keys, etc.) — secrets stay on the backend.

---

## Status: all 10 spec screens built end-to-end + onboarding + interactivity polish

`flutter analyze` is clean. The full happy path is navigable on a device:

> Splash → (first launch only: Onboarding) → Sign-In → Profile Setup → Avatar Selection → Home (with bottom nav: Home / Wardrobe / Profile) → Upload → Try-On → AI Feedback (bottom sheet) → save → back to Home/Wardrobe.

Every API call site is marked with `TODO(api):` so it's grep-able when the backend is ready.

> 📐 **Backend plan for Phase 1:** see [Backend/PHASE1_PLAN.md](../Backend/PHASE1_PLAN.md) — schema, RLS, auth flow, endpoint contracts, and the build order that unblocks `BYPASS_AUTH=false` and lets us delete the mock data layer.

---

## Done

### Foundation
- **Design system** — `lib/core/theme/`
  - `app_colors.dart` — light + dark `AppColors` as a `ThemeExtension`, `context.colors` accessor
  - `app_typography.dart` — DM Sans via `google_fonts`
  - `app_spacing.dart` — `AppSpacing` (4/8/12/16/24/32/48/64) and `AppRadius` tokens
  - `app_theme.dart` — `AppTheme.light()` / `AppTheme.dark()` with input/appbar/divider themes
- **Routing** — `lib/core/router/`
  - `app_routes.dart` — `AppRoute` enum
  - `app_router.dart` — `StatefulShellRoute.indexedStack` for the bottom-nav (Home / Wardrobe / Profile); Upload, Try-On, AI Feedback push on top of the shell via the root navigator
- **Runtime config** — `lib/core/config/app_flags.dart` reads from `.env` (via `flutter_dotenv`) with `--dart-define` override + hardcoded fallback. Schema documented in `Frontend/.env.example`. Loaded in `main.dart` before `runApp`.
- **Mock data** — `lib/core/mock/mock_data.dart` (`AvatarKind`, `ClothingType`, `MockClothingItem`, `MockOutfit`) — the placeholder data layer to be replaced by Riverpod providers + dio API client
- **App shell** — `app.dart` is a `ConsumerWidget` wiring `MaterialApp.router` + light/dark theme
- **Widget test** — smoke test boots `DressifyApp`

### Shared widgets — `lib/core/widgets/`
- `primary_button.dart` — full-width 52dp filled button, loading state
- `secondary_button.dart` — outlined variant
- `app_card.dart` — surface card with shadow + optional tap
- `app_chip.dart` — pill chip (filter / selection)
- `app_text_field.dart` — labeled input with error state
- `unit_toggle.dart` — generic `UnitToggle<T>` segmented control
- `dashed_border.dart` — `CustomPainter` for dashed RRect (upload zone)
- `app_toast.dart` — `AppToast.success(ctx, msg)` / `.error()` / `.info()` floating snackbar with colored accent bar
- `core/utils/motion.dart` — `context.reduceMotion` honors OS Reduce-Motion; `context.motion(duration)` returns `Duration.zero` when set

### Screens (per `Dressify_Frontend_Prompt.md` build order)

| # | Screen | File | Notes |
|---|---|---|---|
| 0 | Onboarding | `lib/features/onboarding/onboarding_screen.dart` | 3-slide PageView with animated dot indicator, Skip / Next / Get Started, gated by `onboarding_seen_v1` in `SharedPreferences`. Splash routes here on first launch. |
| 1 | Splash | `lib/features/splash/splash_screen.dart` | Gradient + animated wordmark, 1.5s delay, reads onboarding flag, branches on BYPASS_AUTH, shows DEV badge when bypassing |
| 2 | Sign-In | `lib/features/auth/sign_in_screen.dart` | Google-branded button, error/loading states, bypass hint banner |
| 3 | Profile Setup | `lib/features/profile_setup/profile_setup_screen.dart` | Step 1/2 header, name + height (cm OR ft·in dual) + weight (kg/lbs) + body-type chips, full validation, Continue gated on name + ≥1 valid measurement |
| 4 | Avatar Selection | `lib/features/avatar/avatar_selection_screen.dart` | Horizontal scroll of 5 avatars (Slim / Athletic / Average / Curvy / Plus), select state with primary border + checkmark + 1.04 scale animation, Use This Avatar CTA |
| 5 | Home | `lib/features/home/home_screen.dart` + `home_shell.dart` | Top bar (greeting + bell + avatar), 4 Quick Action tiles, Recent Outfits horizontal scroll with rating badges, See All link, empty state. **Bottom nav** is the `HomeShell` with active-tab dot indicator. **Pull-to-refresh** wired. |
| 6 | Upload | `lib/features/upload/upload_screen.dart` | Dashed upload zone, source bottom sheet (Camera / Gallery via `image_picker`), preview, mocked auto-detection chip + override dropdown, mocked processing progress bar, success state with type chip + Try On / Save to Wardrobe |
| 7 | Try-On Preview | `lib/features/try_on/try_on_screen.dart` | Dark-canvas 65% panel with avatar + mocked clothing overlay, pinch-zoom + drag, floating zoom/reset/visibility/fullscreen controls, bottom panel with item info + avatar selector + AI Feedback / Save Outfit (saving / saved states with auto-revert) |
| 8 | AI Feedback | `lib/features/feedback/ai_feedback_sheet.dart` | DraggableScrollableSheet, animated `CustomPainter` rating arc (0→score over 600ms, color-coded green/amber/red), 4 expandable suggestion cards (Color / Balance / Occasion / Trend), Regenerate (re-mocks score), Save Outfit + Feedback CTA. Plus a stub deep-link route at `lib/features/feedback/ai_feedback_screen.dart`. |
| 9 | Wardrobe | `lib/features/wardrobe/wardrobe_screen.dart` | TabBar (Clothing Items / Saved Outfits), filter chips (All + 7 types), 2-column responsive grid for both tabs, FAB → upload, empty states per tab. **Long-press** on any card opens an action sheet (Try On / Delete) with haptic feedback. **Pull-to-refresh** on both tabs. |
| 10 | Profile & Settings | `lib/features/profile/profile_screen.dart` | Profile header with avatar + Edit link, Body Stats card (3 pills + Edit), grouped settings cards (Units / Notifications / Theme; Privacy / Terms / Version; Sign Out), sign-out confirmation dialog |

---

## Remaining

### Auth & data layer (the next big chunk)
- ✅ **Real Google Sign-In** — `google_sign_in` plugin wired to `_handleGoogleSignIn`. 
- ✅ **`POST /auth/google`** — exchange Google ID token for backend JWT
- ✅ **`flutter_secure_storage`** — persist JWT, read on splash
- ✅ **Auth-gated routing** — `GoRouter.redirect` and `SplashScreen` send unauthenticated users to `signIn`
- ✅ **`dio` API client** — `lib/core/api/api_client.dart` — Dio instance using `AppFlags.apiBaseUrl`, JWT auth interceptor, error mapping (network / 401 / 4xx / 5xx)
- ✅ **Models** — Standard Dart types for `User`, `Profile`, `ClothingItem`, `Outfit`, `AiFeedback`.
- **Riverpod providers** — `authStateProvider`, `currentUserProvider`, `profileProvider`, `wardrobeProvider`, `outfitsProvider`. 
- **Mock data deletion** — `lib/core/mock/mock_data.dart` is referenced by Home, Wardrobe, Try-On, Avatar Selection. When real providers land, remove this file and migrate consumers

### TODO(api) sites — explicit endpoints to wire
- ✅ `splash_screen.dart` — read JWT from secure storage, verify
- ✅ `sign_in_screen.dart` — `POST /auth/google`
- `profile_setup_screen.dart` — `POST /profile` (convert ft·in → cm, lbs → kg before sending)
- `avatar_selection_screen.dart` — persist avatar choice
- `upload_screen.dart` — `POST /upload` with multipart image, stream progress; on success swap real processed image into preview
- `upload_screen.dart` (Save to Wardrobe) — `POST /clothing` (or whatever the wardrobe endpoint becomes)
- `try_on_screen.dart` (Save Outfit) — `POST /outfits`
- `ai_feedback_sheet.dart` — `POST /feedback` (initial + regenerate)
- ✅ `profile_screen.dart` (Sign Out) — clear JWT + cached profile

### Cross-cutting polish (now done)
- ✅ **Onboarding carousel** — `lib/features/onboarding/`, gated by `onboarding_seen_v1` in `SharedPreferences`
- ✅ **Reduced motion utility** — `context.reduceMotion` and `context.motion(duration)` available; not yet wired into every animation site
- ✅ **Toast helper** — `AppToast.success/error/info`, used by Try-On Save, Profile Sign-Out, Upload Save-to-Wardrobe, Wardrobe Delete
- ✅ **Pull-to-refresh** — `RefreshIndicator` on Home + both Wardrobe tabs (currently `Future.delayed` stubs awaiting real fetches)
- ✅ **Long-press context menu** on Wardrobe items (Try On / Delete) with haptic
- ✅ **Haptic feedback** — Try-On Save (medium → light on success), Upload start/finish, Wardrobe long-press, Profile sign-out, Onboarding Next button

### Cross-cutting polish (still to do)
- **Apply `context.motion()` to existing `flutter_animate` calls** — utility is built, individual call sites still hard-code durations
- ✅ **Skeleton loaders** — `shimmer` is implemented for `processing_status == 'processing'`
- **Localization** — spec says no hardcoded strings; everything is currently inline. Set up `flutter_localizations` + ARB files
- **Dark-mode pass** — themes exist; only splash + sign-in have been visually checked. Every other screen needs a manual review on dark
- ✅ **Real avatar images** — `_AvatarIllustration` now loads the 10 specific gendered PNGs from `assets/avatars/`
- **Real Google glyph** — `_GoogleGlyph` in sign-in is a placeholder "G" disc. Replace with `assets/icons/google.svg`
- ✅ **App Icons & Illustrations** — Replaced empty states and bell with custom assets.
- **Logo asset** — `assets/logo/` is empty; splash uses Text wordmark
- **Style Tips quick action** — present but routes nowhere (Phase 2?)
- **Manual adjustment fallback in Try-On** — when auto-fit confidence < 0.7 the spec calls for amber banner + 8 drag handles + pinch-resize. Pinch + drag work on the whole canvas; per-item drag handles aren't wired
- **Try-On clothing overlay** — currently a static colored rectangle approximating a top. Needs to consume real `processed_image_url` + `anchor_points` from backend and render via `CustomPainter` (escalation: `flame`)
- **Body stats display on Profile** — pills show `—`. They should read from `profileProvider` once it exists
- **Edit profile** flow — Profile header has an "Edit Profile" link with no handler

### Tests
- Only one widget smoke test exists. Add: profile-setup form validation, wardrobe filter, AI feedback arc rendering at score boundaries
