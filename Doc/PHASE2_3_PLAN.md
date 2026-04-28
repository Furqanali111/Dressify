# Dressify — Phase 2 & Phase 3 Roadmap

> Created: 2026-04-26. Based on full codebase audit after Phase 1 completion.
> Phase 1 delivered: auth, upload, wardrobe, AI outfit generation, AI feedback, try-on overlay, and all core screens.

---

## Phase 2 — Core Completeness & Polish

Goal: Every screen works correctly end-to-end with real data. No placeholders, no broken wiring, no silent failures. App is ready for internal (dog-food) testing.

Estimated scope: 3–4 weeks.

---

### 2.0 Blockers (Fix First — These Break Existing Features)

#### 2.0.1 ~~Add `raw_image_path` to ClothingItem model~~ — resolved
Raw image storage was removed entirely as part of the multi-garment upload rework (see `implementation_plan.md`). The column was never in the SQLAlchemy model; `inject_urls()` in `clothing.py` has been updated accordingly. No migration needed.

#### 2.0.2 Wire profile screen to real data
**Files:** `Frontend/lib/features/profile/profile_screen.dart`, `Frontend/lib/core/providers/profile_provider.dart`
- Profile screen shows hardcoded `"—"` for height, weight, and body type. `profileProvider` is defined but not consumed.
- **Steps:**
  1. Watch `profileProvider` in `profile_screen.dart`.
  2. Render actual `height_cm`, `weight_kg`, `body_type`, `gender`, `avatar_kind`.
  3. Show "Add" CTA if field is null.
  4. Wire "Edit Profile" button (`onTap: () {}` on line 156) to navigate to `AppRoute.profileSetup`.

#### 2.0.3 Pass avatar kind to outfit generation
**Files:** `Frontend/lib/features/wardrobe/style_me_sheet.dart`
- `generateOutfit()` is called without `avatar_kind`, so the backend defaults to `null` and the try-on screen always initialises on the wrong avatar.
- **Steps:**
  1. Read `profileProvider` inside `StyleMeSheet`.
  2. Pass `avatarKind: profile?.avatarKind` to the `generateOutfit` call.
  3. Ensure `AvatarKind.values.byName()` handles unknown strings gracefully.

#### 2.0.4 Fix auth init race condition on splash screen
**Files:** `Frontend/lib/core/providers/auth_provider.dart`, `Frontend/lib/features/splash/splash_screen.dart`
- `init()` fetches `/me` asynchronously; the router can redirect to sign-in before the fetch completes, causing a flash.
- **Steps:**
  1. Add an `initialising` boolean to `AuthStateNotifier`.
  2. Splash screen watches it and stays until `initialising == false`.
  3. Only then does the router redirect.

---

### 2.1 Missing CRUD Endpoints (Backend)

#### 2.1.1 PATCH /clothing/{id} — update clothing item metadata
**File:** `Backend/app/routers/clothing.py`
- Users need to correct AI-detected name, type, color, pattern, style.
- **Schema to add** (`Backend/app/schemas/clothing.py`):
  ```python
  class ClothingItemUpdate(BaseModel):
      name: str | None = None
      type: str | None = None
      color: str | None = None
      pattern: str | None = None
      style: str | None = None
      sub_type: str | None = None
  ```
- **Steps:**
  1. Add `ClothingItemUpdate` schema.
  2. Add `PATCH /clothing/{id}` route: fetch item, apply `model_dump(exclude_unset=True)`, commit.
  3. Return updated `ClothingItemResponse`.

#### 2.1.2 GET /outfits/{id} — fetch single outfit
**File:** `Backend/app/routers/outfits.py`
- The frontend needs this for deep-linking and refreshing a specific outfit without refetching the whole list.
- **Steps:**
  1. Add `GET /outfits/{outfit_id}` scoped to `current_user.id`.
  2. Load `OutfitItem` rows the same way as the list endpoint.
  3. Return `OutfitResponse`.

#### 2.1.3 PATCH /outfits/{id} — rename outfit
**File:** `Backend/app/routers/outfits.py`
- **Schema to add:**
  ```python
  class OutfitUpdate(BaseModel):
      name: str | None = None
  ```
- **Steps:**
  1. Add `OutfitUpdate` schema.
  2. Add `PATCH /outfits/{id}` route: fetch, update name, commit.
  3. Return `OutfitResponse`.

#### 2.1.4 GET /feedback — list past feedback for a user
**File:** `Backend/app/routers/feedback.py`
- Currently only `POST /feedback` (generate). Users can't retrieve stored feedback.
- **Steps:**
  1. Add `GET /outfits/{outfit_id}/feedback` — returns latest `AiFeedback` for an outfit.
  2. Optionally: `GET /feedback?limit=20` for all user feedback history.

---

### 2.2 Input Validation & Schema Hardening (Backend)

#### 2.2.1 Validate occasion as an enum
**Files:** `Backend/app/schemas/outfit.py`, `Backend/app/schemas/feedback.py`
- `occasion: str` is free-form; AI prompts assume specific values.
- **Steps:**
  1. Define `Occasion = Literal['casual', 'work', 'party', 'date', 'sport', 'formal', 'travel']`.
  2. Use it in `GenerateOutfitRequest` and `FeedbackRequest`.
  3. Add `OCCASION_CHOICES` constant importable by frontend for the dropdown.

#### 2.2.2 Validate avatar_kind as an enum
**Files:** `Backend/app/schemas/outfit.py`
- `avatar_kind: str` can be any value; mismatch crashes try-on.
- **Steps:**
  1. Define `AvatarKind = Literal['maleSlim', 'maleAthletic', 'maleAverage', 'maleCurvy', 'malePlus', 'femaleSlim', 'femaleAthletic', 'femaleAverage', 'femaleCurvy', 'femalePlus']`.
  2. Apply to `OutfitCreate`, `GenerateOutfitRequest`, `ProfileUpdate`.

#### 2.2.3 Add length constraints on name fields
**Files:** `Backend/app/schemas/outfit.py`, `Backend/app/schemas/clothing.py`
- `name` fields have no max length; a 10,000-char name is accepted.
- **Steps:**
  1. `name: str = Field(default='Unnamed Item', max_length=100)` on clothing schemas.
  2. `name: str = Field(..., min_length=1, max_length=100)` on outfit schemas.

#### 2.2.4 Add rate limit to PATCH /profile
**File:** `Backend/app/routers/profile.py`
- All endpoints have rate limiting except profile PATCH.
- **Steps:**
  1. Add `@limiter.limit("10/minute")` decorator.
  2. Add `request: Request` parameter.

---

### 2.3 Upload Flow — Processing Status Polling

**Files:** `Frontend/lib/features/upload/upload_screen.dart`, `Backend/app/routers/clothing.py`

After upload the backend extracts AI metadata asynchronously (color, pattern, style). The frontend shows "Analyzing with AI…" but never updates because it doesn't poll.

**Steps (simpler polling approach — no WebSocket needed):**
1. **Backend:** `GET /clothing/{id}` already returns `processing_status`. No changes needed.
2. **Frontend:** After upload completes and the user lands on the success state, start a poll:
   - Call `GET /clothing/{item_id}` every 3 seconds.
   - Stop when `processingStatus == 'completed'` or after 30 seconds (timeout).
   - On completion, invalidate `wardrobeProvider` so the wardrobe list refreshes.
3. Show a progress indicator while polling; show the extracted metadata (color, style) when done.

---

### 2.4 Outfit Position Persistence

**Files:** `Frontend/lib/features/try_on/try_on_screen.dart`, `Backend/app/routers/outfits.py`

`OutfitItem.position` is defined in the DB but never written or read. User adjustments are lost on every re-open.

**Steps:**
1. **Frontend:** When saving, include `position: {'dx': offset.dx, 'dy': offset.dy, 'scale': scale}` per garment in the POST /outfits body.
2. **Backend:** `OutfitCreate.items` already has `position: dict | None` — just ensure it's persisted (it currently is via the OutfitItem model). No backend change needed.
3. **Frontend try-on load:** When loading an existing outfit, read `item.position` (if non-null) and initialise `_offset` and `_scale` from it instead of defaults.
4. Rename the hardcoded outfit name `"My Outfit"` to include a timestamp: `"Outfit – ${DateFormat.MMMd().format(DateTime.now())}"`, or prompt the user.

---

### 2.5 Wardrobe & Profile Screen Polish

#### 2.5.1 Rename outfit in wardrobe
**Files:** `Frontend/lib/features/wardrobe/wardrobe_screen.dart`
- Long-press on an outfit card → rename dialog → PATCH /outfits/{id}.

#### 2.5.2 Edit clothing item metadata
**Files:** `Frontend/lib/features/wardrobe/wardrobe_screen.dart`
- Long-press on a clothing card → edit bottom sheet → PATCH /clothing/{id}.
- Fields: name, type (dropdown), color, pattern, style.

#### 2.5.3 Centralise avatar accent colors
**Files:** `Frontend/lib/features/home/home_screen.dart`, `Frontend/lib/features/wardrobe/wardrobe_screen.dart`, `Frontend/lib/core/enums/app_enums.dart`
- The same avatar → color mapping is duplicated in two screen files.
- Move it to `AvatarKindX.accentColor` extension in `app_enums.dart` and delete the duplicates.

#### 2.5.4 Fix fullscreen button in try-on
**File:** `Frontend/lib/features/try_on/try_on_screen.dart` (empty `onPressed: () {}`)
- Either implement fullscreen mode (hide app bar, expand canvas) or remove the button.

#### 2.5.5 Occasion picker in Style Me sheet
**File:** `Frontend/lib/features/wardrobe/style_me_sheet.dart`
- Currently `occasion` is a free-form text field. Replace with a chip-selector using the validated `Occasion` enum values from 2.2.1.

---

### 2.6 Security Fixes

#### 2.6.1 Remove secrets from repository
**Immediate action (outside this plan):**
- Rotate all Supabase keys visible in `.env`.
- Add `.env` to `.gitignore` if not already.
- Create `.env.example` with placeholder values only.

#### 2.6.2 Restrict bypass auth to debug builds
**File:** `Backend/app/config.py`, `Frontend/lib/core/config/app_flags.dart`
- `BYPASS_AUTH_FURQAN_54321` must be rejected at startup if `ENV=production`.
- Frontend `BYPASS_AUTH` flag must only compile the bypass code path in `kDebugMode` builds.

#### 2.6.3 Align .env.example with config.py
**File:** `Backend/.env.example`
- Replace `ANTHROPIC_API_KEY` with `OPENAI_API_KEY`.
- Add `OLLAMA_BASE_URL=http://localhost:11434/v1`.
- Add correct `DATABASE_URL` format (must use `postgresql+asyncpg://`).

---


## Phase 3 — Growth Features

Goal: App is ready for public beta / TestFlight. Adds real notifications, user-facing settings, social sharing, and analytics.

Estimated scope: 4–6 weeks after Phase 2.

---

### 3.1 In-App Notifications System

**Approach: Option A (server-side events, no FCM required)**

#### 3.1.1 Backend — notifications table & API
**Files:** New `Backend/app/models/notification.py`, `Backend/app/routers/notifications.py`
- **DB model:**
  ```
  notifications(id, user_id, type, title, body, is_read, related_id, created_at)
  ```
  `type` values: `upload_complete`, `metadata_ready`, `outfit_generated`, `feedback_saved`
- **Endpoints:**
  - `GET /notifications` — list unread + last 30 read, paginated.
  - `PATCH /notifications/{id}/read` — mark as read.
  - `PATCH /notifications/read-all` — mark all read.
- **Event triggers:**
  - `ai_vision.py` — after metadata extraction completes, insert a `metadata_ready` notification.
  - `outfits.py` — after `POST /outfits/generate`, insert `outfit_generated`.
  - `feedback.py` — after persisting feedback, insert `feedback_saved`.

#### 3.1.2 Frontend — notifications provider & live sheet
**Files:** `Frontend/lib/core/providers/notifications_provider.dart`, `Frontend/lib/features/home/notifications_sheet.dart`
- Provider fetches `GET /notifications` on mount and on pull-to-refresh.
- `NotificationsSheet` renders real notification tiles with icon, title, time-ago, and read/unread state.
- Bell icon on home screen shows a red dot badge when `unread_count > 0`.
- Tapping a notification navigates to the relevant screen (e.g., `metadata_ready` → wardrobe item detail).

#### 3.1.3 (Optional) Push notifications via FCM
- Register device token on login → store in `device_tokens(user_id, token, platform, created_at)`.
- Use Firebase Admin SDK on the backend to send push on the same events.
- Only implement if Option A (polling) is not responsive enough.

---

### 3.2 Settings Screen (Units, Theme, Privacy)

**Files:** `Frontend/lib/features/profile/profile_screen.dart`

Currently all settings rows have empty `onTap`. Wire them up:

#### 3.2.1 Units (metric / imperial)
- Store in `SharedPreferences` (`units_preference`).
- Create a `unitsProvider` (StateProvider<UnitSystem>).
- `profile_screen.dart` shows current unit; tap → toggle.
- Profile setup height/weight fields respect the preference and display cm↔in and kg↔lb.

#### 3.2.2 Dark / Light theme toggle
- Add `ThemeMode` to app's root `MaterialApp`.
- Store preference in `SharedPreferences`.
- Create `themeProvider` (StateProvider<ThemeMode>).
- Settings row cycles: System → Light → Dark.

#### 3.2.3 Privacy Policy & Terms of Service
- Use `url_launcher` package.
- Wire both rows to open the respective URLs in the device browser.

#### 3.2.4 Delete Account (GDPR)
- **Backend:** `DELETE /me` — cascade-delete user + profile + all clothing + outfits + feedback + notifications + device tokens. Use a DB transaction.
- **Frontend:** Confirmation dialog (type "DELETE" to confirm) → call `DELETE /me` → clear JWT → navigate to onboarding.

---

### 3.3 Auth Improvements

#### 3.3.1 Longer JWT TTL + refresh token
**Files:** `Backend/app/security.py`, `Backend/app/routers/auth.py`, `Frontend/lib/core/api/auth_interceptor.dart`
- Current TTL: 24 hours. Users log out every day.
- **Plan:**
  - Issue a long-lived refresh token (30 days) alongside the access token (15 minutes or 7 days).
  - `AuthInterceptor.onError` on 401: try `POST /auth/refresh` with refresh token before clearing session.
  - If refresh fails, then clear session and redirect to sign-in.
- **Minimum viable:** Simply increase `JWT_TTL_HOURS` to 168 (7 days) if refresh token complexity is out of scope for Phase 3.

#### 3.3.2 Apple Sign-In
- Add Apple OAuth as a second provider alongside Google.
- Supabase already supports it; requires Apple Developer account configuration.
- Frontend: add Apple sign-in button below Google on `sign_in_screen.dart`.

---

### 3.4 Social & Sharing

#### 3.4.1 Share an outfit as an image
**Files:** `Frontend/lib/features/try_on/try_on_screen.dart`
- Add a "Share" button that renders the try-on canvas to a PNG using `RenderRepaintBoundary`.
- Use `share_plus` package to open the native share sheet.
- No backend changes required.

#### 3.4.2 Outfit links (deep linking)
- Enable Flutter deep links for `dressify://outfits/{id}`.
- Backend `GET /outfits/{id}` (added in 2.1.2) serves the data.
- Frontend router handles the deep link, fetches the outfit, and pushes try-on.

#### 3.4.3 "Inspire me" — public outfit feed (stretch goal)
- Opt-in: users can mark outfits as public.
- `GET /explore` endpoint returns a paginated feed of public outfits (no personal data).
- Frontend: new "Explore" tab in bottom nav.
- Requires: `is_public` flag on `outfits` table, moderation strategy.

---

### 3.5 AI Improvements

#### 3.5.1 Occasion-aware outfit generation UI
- Replace the free-text occasion field in `StyleMeSheet` with a chip grid (Casual, Work, Party, Date, Sport, Formal, Travel).
- Feed the selected `Occasion` enum value to `POST /outfits/generate`.

#### 3.5.2 Clothing-only background removal (rembg u2net_cloth_seg)
**File:** `Backend/app/services/image_processing.py`
- Currently using generic rembg which may keep the person in the foreground.
- Switch to `rembg` with `u2net_cloth_seg` model to extract only the garment.
- This requires more VRAM / compute; profile on the server before enabling.
- Add a fallback: if cloth-seg confidence is low, fall back to the current model.

#### 3.5.3 Feedback history screen
- Show all past `AiFeedback` records for the user.
- `GET /outfits/{id}/feedback` (added in 2.1.4) serves the data.
- In `ai_feedback_screen.dart`, add a tab: "Recent Reports" alongside "Your Outfits".

#### 3.5.4 Upvote / downvote feedback
- Add `is_useful: bool | null` to `ai_feedback` table.
- `PATCH /feedback/{id}` — set `is_useful`.
- Frontend: thumbs up / thumbs down buttons on each feedback card.
- Use this signal to improve prompts over time.

---

### 3.6 Performance & Infrastructure

#### 3.6.1 Pagination on clothing and outfit lists
**Files:** `Backend/app/routers/clothing.py`, `Backend/app/routers/outfits.py`
- Add cursor-based pagination: `GET /clothing?cursor=<uuid>&limit=20`.
- `ClothingListResponse.next_cursor` is already defined — just populate it.
- Frontend providers: implement infinite scroll with `ref.read(wardrobeProvider.notifier).fetchMore()`.

#### 3.6.2 Image CDN / signed URL caching
**File:** `Backend/app/services/storage.py`
- Supabase signed URLs expire; if TTL is short, images load then break.
- Cache signed URLs client-side with an expiry; re-fetch before expiry.
- Or switch to public bucket + CDN for processed images (already not sensitive after background removal).

#### 3.6.3 Sentry error monitoring
**Files:** `Frontend/lib/main.dart`, `Backend/app/main.py`
- Frontend: add `sentry_flutter` SDK, wrap `runApp` in `SentryFlutter.init`.
- Backend: add `sentry-sdk[fastapi]`, wrap with `sentry_sdk.init` and FastAPI integration.
- `SENTRY_DSN` is already in `app_flags.dart` as a config key — just wire it up.

#### 3.6.4 CI/CD pipeline
- GitHub Actions:
  - Backend: `pytest` (after Phase 2.7) on every push.
  - Frontend: `flutter analyze` + `flutter test` on every push.
  - Deploy backend to Railway / Render / Fly.io on merge to `main`.
  - Build and upload Flutter app to TestFlight / Play Store internal track.

---

## Summary Table

| # | Feature | Phase | Priority | Effort |
|---|---------|-------|----------|--------|
| 2.0.1 | Add raw_image_path to ClothingItem model | 2 | 🔴 Blocker | 0.5 day |
| 2.0.2 | Wire profile screen to real data | 2 | 🔴 Blocker | 1 day |
| 2.0.3 | Pass avatar kind to outfit generation | 2 | 🔴 Blocker | 0.5 day |
| 2.0.4 | Fix auth init race condition | 2 | 🔴 Blocker | 0.5 day |
| 2.1.1 | PATCH /clothing/{id} | 2 | 🟠 High | 1 day |
| 2.1.2 | GET /outfits/{id} | 2 | 🟠 High | 0.5 day |
| 2.1.3 | PATCH /outfits/{id} | 2 | 🟠 High | 0.5 day |
| 2.1.4 | GET feedback history | 2 | 🟠 High | 1 day |
| 2.2 | Input validation & schema hardening | 2 | 🟠 High | 1 day |
| 2.3 | Processing status polling | 2 | 🟠 High | 1 day |
| 2.4 | Outfit position persistence | 2 | 🟡 Medium | 1.5 days |
| 2.5 | Wardrobe & profile screen polish | 2 | 🟡 Medium | 2 days |
| 2.6 | Security fixes | 2 | 🔴 Blocker | 1 day |
| 2.7 | Backend test suite | 2 | 🟠 High | 3 days |
| 3.1 | In-app notifications | 3 | 🟠 High | 3 days |
| 3.2 | Settings screen | 3 | 🟡 Medium | 2 days |
| 3.3 | Auth improvements (TTL / Apple) | 3 | 🟡 Medium | 2 days |
| 3.4 | Social & sharing | 3 | 🟢 Nice | 3 days |
| 3.5 | AI improvements | 3 | 🟡 Medium | 3 days |
| 3.6 | Performance & infrastructure | 3 | 🟠 High | 3 days |

---

## What Phase 2 Does NOT Include

- Push notifications (FCM) — deferred to Phase 3.3.
- Social / explore feed — Phase 3.4.
- Apple Sign-In — Phase 3.3.
- Soft-delete / recycle bin — can be added to Phase 2 if time allows.
- WebSocket real-time sync — polling (2.3) is sufficient for Phase 2.
