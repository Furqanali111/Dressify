# Dressify Mobile — Frontend Progress

Tracker for the Flutter mobile app build. Source of truth for visual/UX spec is `Dressify_Frontend_Prompt.md`; architecture rules live in `Project_Plan.md` and the Claude memory `architecture_thin_frontend.md`.

## How to run

```bash
# Standard run (real auth — once /auth/google is wired)
flutter run

# Local UI work — skip Google sign-in (splash routes straight to profile setup)
flutter run --dart-define=BYPASS_AUTH=true

# Override backend base URL
flutter run --dart-define=API_BASE_URL=https://api.dressify.app
```

Flags are declared in `lib/core/config/app_flags.dart`. When `BYPASS_AUTH=true`, splash and sign-in show a visible "AUTH BYPASSED" badge so it can't ship accidentally.

---

## Status: all 10 spec screens built end-to-end

`flutter analyze` is clean. The full happy path is navigable on a device:

> Splash → Sign-In → Profile Setup → Avatar Selection → Home (with bottom nav: Home / Wardrobe / Profile) → Upload → Try-On → AI Feedback (bottom sheet) → save → back to Home/Wardrobe.

Every API call site is marked with `TODO(api):` so it's grep-able when the backend is ready.

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
- **Build flags** — `lib/core/config/app_flags.dart` (`bypassAuth`, `apiBaseUrl`)
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

### Screens (per `Dressify_Frontend_Prompt.md` build order)

| # | Screen | File | Notes |
|---|---|---|---|
| 1 | Splash | `lib/features/splash/splash_screen.dart` | Gradient + animated wordmark, 1.5s delay, branches on BYPASS_AUTH, shows DEV badge when bypassing |
| 2 | Sign-In | `lib/features/auth/sign_in_screen.dart` | Google-branded button, error/loading states, bypass hint banner |
| 3 | Profile Setup | `lib/features/profile_setup/profile_setup_screen.dart` | Step 1/2 header, name + height (cm OR ft·in dual) + weight (kg/lbs) + body-type chips, full validation, Continue gated on name + ≥1 valid measurement |
| 4 | Avatar Selection | `lib/features/avatar/avatar_selection_screen.dart` | Horizontal scroll of 5 avatars (Slim / Athletic / Average / Curvy / Plus), select state with primary border + checkmark + 1.04 scale animation, Use This Avatar CTA |
| 5 | Home | `lib/features/home/home_screen.dart` + `home_shell.dart` | Top bar (greeting + bell + avatar), 4 Quick Action tiles, Recent Outfits horizontal scroll with rating badges, See All link, empty state. **Bottom nav** is the `HomeShell` with active-tab dot indicator. |
| 6 | Upload | `lib/features/upload/upload_screen.dart` | Dashed upload zone, source bottom sheet (Camera / Gallery via `image_picker`), preview, mocked auto-detection chip + override dropdown, mocked processing progress bar, success state with type chip + Try On / Save to Wardrobe |
| 7 | Try-On Preview | `lib/features/try_on/try_on_screen.dart` | Dark-canvas 65% panel with avatar + mocked clothing overlay, pinch-zoom + drag, floating zoom/reset/visibility/fullscreen controls, bottom panel with item info + avatar selector + AI Feedback / Save Outfit (saving / saved states with auto-revert) |
| 8 | AI Feedback | `lib/features/feedback/ai_feedback_sheet.dart` | DraggableScrollableSheet, animated `CustomPainter` rating arc (0→score over 600ms, color-coded green/amber/red), 4 expandable suggestion cards (Color / Balance / Occasion / Trend), Regenerate (re-mocks score), Save Outfit + Feedback CTA. Plus a stub deep-link route at `lib/features/feedback/ai_feedback_screen.dart`. |
| 9 | Wardrobe | `lib/features/wardrobe/wardrobe_screen.dart` | TabBar (Clothing Items / Saved Outfits), filter chips (All + 7 types), 2-column responsive grid for both tabs, FAB → upload, empty states per tab |
| 10 | Profile & Settings | `lib/features/profile/profile_screen.dart` | Profile header with avatar + Edit link, Body Stats card (3 pills + Edit), grouped settings cards (Units / Notifications / Theme; Privacy / Terms / Version; Sign Out), sign-out confirmation dialog |

---

## Remaining

### Auth & data layer (the next big chunk)
- **Real Google Sign-In** — `google_sign_in` plugin wired to `_handleGoogleSignIn`. Currently both splash and sign-in route forward without ever calling the backend.
- **`POST /auth/google`** — exchange Google ID token for backend JWT
- **`flutter_secure_storage`** — persist JWT, read on splash
- **Auth-gated routing** — `GoRouter.redirect` should send unauthenticated users to `signIn`; currently every route is publicly reachable
- **`dio` API client** — `lib/core/api/api_client.dart` — Dio instance using `AppFlags.apiBaseUrl`, JWT auth interceptor, error mapping (network / 401 / 4xx / 5xx)
- **Models** — Freezed types for `User`, `Profile`, `ClothingItem`, `Outfit`, `AiFeedback`. `freezed` + `json_serializable` are in `pubspec.yaml`; nothing generated yet (need `build_runner`)
- **Riverpod providers** — `authStateProvider`, `currentUserProvider`, `profileProvider`, `wardrobeProvider`, `outfitsProvider`. Currently only `appRouterProvider` exists
- **Mock data deletion** — `lib/core/mock/mock_data.dart` is referenced by Home, Wardrobe, Try-On, Avatar Selection. When real providers land, remove this file and migrate consumers

### TODO(api) sites — explicit endpoints to wire
- `splash_screen.dart` — read JWT from secure storage, verify
- `sign_in_screen.dart` — `POST /auth/google`
- `profile_setup_screen.dart` — `POST /profile` (convert ft·in → cm, lbs → kg before sending)
- `avatar_selection_screen.dart` — persist avatar choice
- `upload_screen.dart` — `POST /upload` with multipart image, stream progress; on success swap real processed image into preview
- `upload_screen.dart` (Save to Wardrobe) — `POST /clothing` (or whatever the wardrobe endpoint becomes)
- `try_on_screen.dart` (Save Outfit) — `POST /outfits`
- `ai_feedback_sheet.dart` — `POST /feedback` (initial + regenerate)
- `profile_screen.dart` (Sign Out) — clear JWT + cached profile

### Cross-cutting polish
- **Onboarding carousel** — first-launch 3-slide swipeable; needs a `shared_preferences`-backed "has seen onboarding" flag. Currently splash routes straight through to sign-in or profile setup
- **Reduced motion** — wrap `flutter_animate` calls so `MediaQuery.disableAnimations` collapses durations
- **Toast / snackbar** — success / error / info variants, 3s auto-dismiss; consume from `ScaffoldMessenger` so any screen can fire one
- **Skeleton loaders** — `shimmer` is in `pubspec.yaml` but unused; needed once real data fetching lands (Home recent outfits, Wardrobe grids, AI feedback regenerate)
- **Localization** — spec says no hardcoded strings; everything is currently inline. Set up `flutter_localizations` + ARB files
- **Dark-mode pass** — themes exist; only splash + sign-in have been visually checked. Every other screen needs a manual review on dark
- **Real avatar SVGs** — `_AvatarIllustration` is a person icon over a colored gradient. Drop SVGs into `assets/avatars/` and load via `flutter_svg`
- **Real Google glyph** — `_GoogleGlyph` in sign-in is a placeholder "G" disc. Replace with `assets/icons/google.svg`
- **Logo asset** — `assets/logo/` is empty; splash uses Text wordmark
- **Empty-state illustrations** — Home / Wardrobe currently use icons; spec calls for illustrations (`assets/images/`)
- **Notification bell** — icon present on home top bar but does nothing
- **Style Tips quick action** — present but routes nowhere (Phase 2?)
- **Manual adjustment fallback in Try-On** — when auto-fit confidence < 0.7 the spec calls for amber banner + 8 drag handles + pinch-resize. Pinch + drag work on the whole canvas; per-item drag handles aren't wired
- **Try-On clothing overlay** — currently a static colored rectangle approximating a top. Needs to consume real `processed_image_url` + `anchor_points` from backend and render via `CustomPainter` (escalation: `flame`)
- **Body stats display on Profile** — pills show `—`. They should read from `profileProvider` once it exists
- **Edit profile** flow — Profile header has an "Edit Profile" link with no handler

### Tests
- Only one widget smoke test exists. Add: profile-setup form validation, wardrobe filter, AI feedback arc rendering at score boundaries
