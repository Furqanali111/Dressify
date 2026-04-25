# 🎨 Dressify — Complete Frontend Development Prompt

---

## 📌 Project Context

You are building the **frontend (UI layer) of Dressify**, a 2D virtual try-on mobile app. The primary platform is **Flutter** using **UI Toolkit / Canvas** for rendering. The frontend communicates with a **FastAPI backend** (REST) and directly with **Firebase** via Flutter SDK for auth and storage. This prompt covers every screen, component, interaction, state, animation, and design rule you need to implement.

---

## 🎯 Core UX Philosophy

- **Minimal steps, maximum clarity** — every action must require ≤ 3 taps to reach
- **Feedback on every action** — loading spinners, success toasts, error banners, progress bars for uploads
- **Mobile-first** — designed for portrait orientation on mid-range Android phones (1080×2340 baseline); secondary iOS support
- **Performance first** — UI response must be < 100ms; never block the main thread with image processing
- **Optimistic UI** — show results instantly where possible; rollback on failure

---

## 🎨 Design System

### Typography

| Role | Font | Size | Weight |
|---|---|---|---|
| Display heading | Custom / bold | 28sp | 700 |
| Section title | Regular | 20sp | 600 |
| Body | Regular | 16sp | 400 |
| Caption / label | Regular | 13sp | 400 |
| Button text | Medium | 15sp | 600 |

### Color Palette

| Token | Light | Dark | Usage |
|---|---|---|---|
| `primary` | `#6C63FF` | `#A89CFF` | CTAs, active states |
| `primary-dark` | `#4B44CC` | `#7B70EE` | Button press states |
| `surface` | `#FFFFFF` | `#1C1C2E` | Cards, panels |
| `background` | `#F5F4FF` | `#0D0D1A` | Page background |
| `text-primary` | `#1A1A2E` | `#F0EFFF` | Body text |
| `text-secondary` | `#6B6B8A` | `#9999BB` | Labels, hints |
| `success` | `#22C97A` | `#1FA865` | Saved states |
| `error` | `#FF5C5C` | `#FF7070` | Errors, warnings |
| `overlay` | `rgba(0,0,0,0.55)` | — | Modal backdrops |

### Spacing Scale

`4 / 8 / 12 / 16 / 24 / 32 / 48 / 64` dp — never use arbitrary values outside this scale.

### Corner Radius

| Component | Radius |
|---|---|
| Cards / panels | 20dp |
| Buttons (full) | 14dp |
| Buttons (icon) | 50% (circle) |
| Input fields | 12dp |
| Bottom sheets | 24dp top corners only |
| Avatar thumbnails | 50% (circle) |
| Clothing thumbnails | 16dp |

### Elevation / Shadow

- **Level 1** (cards): soft shadow, 0 4dp 12dp rgba(0,0,0,0.08)
- **Level 2** (floating buttons, modals): 0 8dp 24dp rgba(0,0,0,0.14)
- **Level 3** (bottom sheets): 0 -4dp 20dp rgba(0,0,0,0.18)

### Iconography

Use a **single outlined icon set** (e.g. Material Symbols Outlined). Icon size: 24dp standard, 20dp in dense lists, 32dp in hero actions. All icons must have a visible label or tooltip.

---

## 📱 Screen Inventory & Specifications

---

### Screen 1 — Splash / Onboarding

**Purpose:** App entry point while Firebase auth state is resolved.

**Layout:**
- Full-screen background: animated gradient using `primary` → `#C4B5FD` (soft lavender)
- Centered logo: Dressify wordmark + icon (a mirror with a clothing silhouette)
- Tagline below: *"Your wardrobe. Reimagined."* — 18sp, white, opacity 80%
- Animated shimmer effect across logo on load

**States:**
1. `loading` — spinner below logo, 3s max wait
2. `new_user` → navigate to **Onboarding Carousel**
3. `returning_user` → navigate to **Home**

**Onboarding Carousel (first launch only):**
- 3 swipeable slides with illustration, title, description
- Slide 1: "Upload any clothing" — icon of a camera + t-shirt
- Slide 2: "See it on you instantly" — avatar with overlaid outfit
- Slide 3: "Get AI styling advice" — star rating graphic
- Progress dots at bottom (3 dots, active dot = primary color)
- "Get Started" CTA on final slide — large, full-width primary button
- Skip button top-right on slides 1–2

---

### Screen 2 — Google Sign-In

**Purpose:** Authenticate user via OAuth 2.0 Google Sign-In.

**Layout:**
- White card centered vertically (top 40%, bottom 60% split)
- Top area: large app icon / illustration
- Bottom card:
  - Title: "Welcome to Dressify" — 24sp bold
  - Subtitle: "Sign in to save your outfits and style profile" — 15sp secondary color
  - **Google Sign-In Button**: follows official Google branding guidelines
    - White background, Google logo left-aligned, "Sign in with Google" centered text
    - Full width, 52dp height, 8dp radius, 1dp border `#DADCE0`
    - Ripple effect on tap
  - Terms text below: "By continuing, you agree to our Terms & Privacy Policy" — 12sp, secondary color, hyperlinks underlined

**States:**
- `idle` → button enabled
- `loading` → button shows spinner, disabled
- `error` → red banner at top: "Sign-in failed. Please try again."
- `success` → navigate to Avatar Selection (first time) or Home (returning)

---

### Screen 3 — Profile Setup

**Purpose:** Collect user body attributes to enable avatar scaling.

**Layout:**
- Top: progress indicator "Step 1 of 2" or skip option (skip goes to avatar selection with defaults)
- Title: "Tell us about yourself" — 22sp bold
- Subtitle: "This helps us fit clothing more accurately" — 15sp secondary
- Form fields (each with label above, input below):
  - **Name** — text input, placeholder "Your name"
  - **Height** — numeric input with unit toggle (cm / ft·in)
  - **Weight** — numeric input with unit toggle (kg / lbs)
  - **Body Type** — horizontal chip selector: `Slim` / `Athletic` / `Average` / `Curvy` / `Plus`
    - Each chip: pill shape, 40dp height, outlined when inactive, filled primary when selected
- "Continue" button — full width, primary color, disabled until name + at least one measurement is filled
- "Skip for now" text link below button

**Validation:**
- Height: must be 100–250 cm or 3'3"–8'2"
- Weight: must be 30–300 kg or 66–660 lbs
- Show inline error in red below the field on blur if invalid

---

### Screen 4 — Avatar Selection

**Purpose:** Let the user choose a predefined 2D avatar.

**Layout:**
- Header: back arrow + "Choose Your Avatar" title
- Subtitle: "Pick the avatar closest to your body shape"
- Horizontal scrollable row of **3–5 avatar cards**:
  - Each card: 140×240dp, white card, 20dp radius, subtle shadow
  - Avatar illustration fills 80% of card height
  - Avatar name below (e.g. "Slim", "Athletic", "Curvy") — 13sp, centered
  - Selected state: purple border 2.5dp + checkmark badge top-right
  - Tap to select (no double-tap confirm needed)
- "Use This Avatar" CTA button — full width, primary, fixed at bottom
  - Disabled until one avatar is selected

**Animation:**
- On select: card scales up to 1.04, border fades in with 180ms ease-out
- On deselect: previous card scales back to 1.0

**Note:** Avatar illustrations must be SVG/vector assets — scalable for all screen densities.

---

### Screen 5 — Home / Wardrobe Hub

**Purpose:** Main dashboard. Central navigation hub.

**Layout:**

**Top Bar:**
- Left: Dressify logo (small) + greeting text "Hello, [Name] 👋" — 18sp
- Right: circular avatar thumbnail (user's selected avatar, 40dp) + notification bell icon

**Quick Actions Row** (4 icon buttons in a 2×2 grid or horizontal row):
- "New Outfit" — camera/plus icon
- "My Wardrobe" — grid icon
- "Saved Looks" — bookmark icon
- "Style Tips" — sparkle/AI icon

Each button: 80×80dp card, icon centered (32dp), label below (12sp), primary color icon on white card.

**Recent Outfits Section:**
- Section header: "Recent Outfits" + "See All" link
- Horizontal scroll row of outfit cards (140×180dp each):
  - Avatar thumbnail with outfit overlaid
  - Outfit name below (truncated to 1 line)
  - AI rating badge top-right: star icon + score "8.2"
  - Tap → navigate to Outfit Preview screen

**Empty State (no outfits yet):**
- Centered illustration of an empty wardrobe hanger
- Text: "No outfits yet. Upload your first clothing item!"
- "Get Started" button → Upload screen

**Bottom Navigation Bar** (persistent across Home, Wardrobe, Profile):
- 3 tabs: Home (house icon), Wardrobe (shirt icon), Profile (person icon)
- Active tab: primary color icon + small dot indicator below
- Inactive: gray icon

---

### Screen 6 — Clothing Upload

**Purpose:** Upload a clothing image and initiate background removal.

**Layout:**

**Upload Area (top 55% of screen):**
- Large dashed-border rectangle (rounded 20dp), centered
- Inside: upload icon (48dp) + "Tap to upload or drag here" text
- Subtext: "Supports JPG, PNG up to 10MB"
- On tap: opens system image picker (gallery + camera options as bottom sheet)

**Bottom Sheet — Image Source Picker:**
- Two tall icon buttons side by side:
  - "Camera" — takes new photo
  - "Gallery" — picks from phone storage
- Cancel button at bottom

**After Image Selected:**
- Image preview fills the upload area (cropped to fit, maintain aspect ratio)
- "Change Image" text link below
- Clothing type auto-detection result badge appears: `"Top detected ✓"` or `"Bottom detected ✓"` — green pill badge
- If detection confidence is low: yellow badge "Uncertain — please confirm" + dropdown to manually select: Top / Bottom / Dress / Jacket / Other
- "Remove Background" button — primary, full width
  - On tap: shows inline progress bar inside the button "Removing background… 0%→100%"

**Processing State:**
- Upload area shows the original image with a shimmer overlay
- Progress percentage text below image
- Cancel button available

**Success State:**
- Processed image (PNG with transparent background) shown in upload area
- Green check badge "Background removed"
- Two action buttons:
  - "Try On" — primary button → navigates to Try-On Preview
  - "Save to Wardrobe" — secondary outlined button

**Error State:**
- Red banner: "Processing failed. Please try a clearer image."
- Retry button

---

### Screen 7 — Try-On Preview (Core Screen)

**Purpose:** Display the avatar wearing the uploaded clothing via the auto-overlay engine.

**Layout:**

**Preview Canvas (top 65% of screen):**
- Full-width canvas/panel showing the 2D avatar
- Clothing asset is auto-overlaid at correct anchor points (shoulders/chest/waist)
- Canvas background: subtle gradient or neutral color (not white — avoid blending with clothing)
- The avatar + outfit must be clearly visible at a glance

**Overlay Controls (floating, bottom-right of canvas):**
- Small icon button row (vertical stack):
  - Zoom in / zoom out
  - Reset position
  - Toggle avatar visibility (to see clothing alone)
- Each button: 44×44dp, white circular card, shadow level 1

**Manual Adjustment (optional fallback — shown if auto-fit confidence < 70%):**
- Yellow info banner at top of canvas: "Auto-fit may need adjustment — drag to reposition"
- Drag handles visible on corners of the clothing item
- User can drag to reposition, pinch to resize

**Bottom Panel (scrollable, bottom 35%):**
- Clothing name + detected type (e.g. "Blue T-Shirt — Top")
- Color swatch row: if multiple colors are detected or user wants to see alternates (future phase, show disabled with "Coming soon" chip)
- Two buttons side by side:
  - "Get AI Feedback" — secondary outlined button with sparkle icon
  - "Save Outfit" — primary button with bookmark icon

**States:**
- `rendering` — skeleton placeholder on canvas + "Fitting your look…" text
- `success` — outfit rendered, controls visible
- `auto_fit_low_confidence` — yellow banner + drag handles
- `saved` — Save button changes to "Saved ✓" (green) for 2 seconds then returns to normal

---

### Screen 8 — AI Styling Feedback

**Purpose:** Display AI-generated outfit analysis, rating, and suggestions.

**Can be a bottom sheet** that slides up from Screen 7 (overlay) or a full screen — implement as a **tall bottom sheet** (covers ~75% of screen height).

**Header:**
- Drag handle at top (standard bottom sheet indicator)
- Title: "Your Style Report" — 20sp bold
- Subtitle: outfit name

**Rating Section:**
- Large circular rating badge: shows score e.g. "8.5 / 10"
  - Outer ring: animated arc that fills clockwise when sheet opens (0 → score, 600ms ease-out)
  - Color: green if ≥7, amber if 4–6, red if <4
- Below: one-line overall verdict: "Great casual look! ✨"

**Suggestion Cards (scrollable vertical list):**

Each card (white, 16dp radius, shadow level 1):
- Left: colored category icon (e.g. color wheel for color, balance scale for proportion)
- Right: suggestion text — max 2 lines (truncated with "read more")
- Tap to expand full suggestion

Suggestion categories to display:
- Color harmony
- Style balance (top vs bottom proportion)
- Occasion fit
- Trend note (if applicable)

**Regenerate Button:**
- "Regenerate Feedback" — text button with refresh icon
- Re-calls AI API, shows spinner inside the rating badge while loading

**CTA at bottom of sheet:**
- "Save Outfit + Feedback" — full-width primary button
- "Close" — text link

---

### Screen 9 — Wardrobe

**Purpose:** Browse and manage all saved clothing items and outfits.

**Layout:**

**Tab Bar (top):**
- Two tabs: "Clothing Items" | "Saved Outfits"
- Underline indicator style, primary color

**Clothing Items Tab:**
- Filter chips row (horizontal scroll): All / Tops / Bottoms / Dresses / Jackets
- Grid: 2 columns, each cell 160dp wide, 200dp tall
  - Clothing image (transparent BG, on light gray card)
  - Item name below (1 line)
  - Long press → context menu: "Try On", "Rename", "Delete"
  - Tap → full-screen item view with "Try On" CTA

**Saved Outfits Tab:**
- Grid: 2 columns, each cell 160×220dp
  - Avatar thumbnail with outfit overlaid
  - Outfit name (1 line)
  - AI rating badge (if available)
  - Long press → context menu: "View", "Share", "Delete"

**Empty States (per tab):**
- Illustrated empty state with relevant icon
- Prompt to add clothing / create outfit

**FAB (Floating Action Button):**
- Bottom-right: purple circle, "+" icon, 56dp
- Tap → Upload screen

---

### Screen 10 — Profile & Settings

**Purpose:** View user profile, manage preferences.

**Layout:**

**Profile Header:**
- Large avatar thumbnail (80dp circle)
- User name — 20sp bold
- "Edit Profile" text link

**Body Stats Section (card):**
- Three data pills in a row: Height / Weight / Body Type
- "Edit" button — opens profile setup flow again

**Settings List:**
- Standard list items with chevron:
  - Units (cm/kg or ft/lbs)
  - Notifications (toggle)
  - Theme (Light / Dark / System)
  - Privacy Policy
  - Terms of Service
  - App version
  - Sign Out — red text, destructive action

**Sign Out Confirmation:**
- Alert dialog (not full screen): "Sign out of Dressify? Your saved outfits will remain." — "Cancel" + "Sign Out" buttons

---

## ⚙️ Component Library

These reusable components must be built once and used across all screens.

### Primary Button
- Full width or fixed 200dp min
- 52dp height, 14dp radius
- Background: `primary`, text: white
- Pressed state: scale 0.97 + darken to `primary-dark`
- Disabled: opacity 0.4, not tappable
- Loading state: spinner replaces text, same size

### Secondary Button (Outlined)
- Same size as primary
- Background: transparent, border 1.5dp `primary` color, text `primary` color
- Pressed: light primary background fill

### Icon Button (Circular)
- 44dp or 56dp (FAB variant)
- Circle shape, primary or white background
- Ripple effect on tap

### Input Field
- 52dp height, 12dp radius
- Border 1dp gray on idle, primary on focus, error red on error
- Label floats above on focus (animated)
- Error message appears below with red color

### Chip (Filter / Selection)
- Pill shape, 36dp height
- Outlined when inactive, filled `primary` when active
- Horizontal scroll row with 8dp gap between chips

### Card
- White background, 20dp radius, shadow level 1
- 16dp internal padding

### Bottom Sheet
- 24dp radius top corners only
- Drag handle: 40dp wide, 4dp tall, gray, centered at top with 12dp margin
- Background: surface color
- Scrim (overlay) behind: `rgba(0,0,0,0.55)`

### Toast / Snackbar
- Appears at bottom, 16dp margin from edges
- Dark background, white text, optional action button
- Auto-dismiss after 3 seconds
- Types: success (green left border), error (red left border), info (blue left border)

### Loading Skeleton
- Gray animated shimmer shapes that match the layout of the content being loaded
- Used for outfit cards, avatar preview, AI feedback

### Progress Bar (Upload/Processing)
- Full width inside its container
- Animated fill from 0% to 100%
- Shows percentage text below
- Primary color fill, light gray track

---

## 🔄 Navigation Architecture

```
Root
├── Splash Screen
├── Auth Flow
│   ├── Google Sign-In Screen
│   └── Profile Setup Screen
├── Avatar Selection Screen (first time only)
└── Main App (Bottom Nav)
    ├── Home Tab
    │   ├── Upload Screen (modal/push)
    │   ├── Try-On Preview Screen (push)
    │   │   └── AI Feedback (bottom sheet overlay)
    │   └── Outfit Preview Screen (push)
    ├── Wardrobe Tab
    │   ├── Clothing Item Detail (push)
    │   └── Upload Screen (modal/push)
    └── Profile Tab
        └── Profile Edit Screen (push)
```

**Transition animations:**
- Push (forward): slide from right (300ms ease-in-out)
- Pop (back): slide to right
- Modal (bottom sheet): slide up from bottom
- Tab switch: fade crossfade (200ms)

---

## ⚡ State Management Requirements

Each screen must handle these states explicitly:

| State | UI Behavior |
|---|---|
| `loading` | Skeleton or spinner shown, interactive elements disabled |
| `success` | Content shown, all interactions enabled |
| `error` | Error banner/toast shown, retry button visible |
| `empty` | Empty state illustration + CTA |
| `uploading` | Progress bar shown, cancel available |
| `processing` | Processing indicator, no other actions available |
| `saving` | Save button shows spinner, disabled |

---

## 🎞️ Animations & Micro-interactions

| Trigger | Animation |
|---|---|
| App launch | Logo fade-in + scale-up (400ms) |
| Button tap | Scale down to 0.97 (100ms) then back |
| Card select (avatar) | Border fade-in + scale 1.04 (180ms ease-out) |
| Rating arc (AI feedback) | Arc fills 0→score over 600ms ease-out |
| Bottom sheet open | Slide up with spring (350ms, slight bounce) |
| Outfit saved | Confetti burst (0.5s) + success badge |
| Upload progress | Progress bar animates smoothly (no jumps) |
| Page load | Skeleton shimmer (continuous loop until data loads) |
| Image processing complete | Crossfade from original to processed image (250ms) |
| Toast appear/dismiss | Slide up in (200ms) + slide down out (200ms) |

Use **Flutter's DOTween** or equivalent tween library. Avoid frame-by-frame manual animations. All animations must respect system `Reduce Motion` accessibility setting — if enabled, replace motion-based transitions with instant cuts or simple fades.

---

## 🔌 API Integration Points (Frontend Responsibilities)

### Firebase Auth
- Initialize Firebase on app start
- Call `GoogleSignIn.DefaultInstance.SignIn()` on button tap
- On success, store Firebase `idToken` and `uid`
- On each app resume, verify token is still valid; refresh if expired
- On sign-out, clear all cached user data and navigate to Auth screen

### Image Upload Flow
1. User selects image → encode to Base64 or multipart form
2. `POST /upload` to FastAPI — attach image + `user_id`
3. Show upload progress (listen to progress events if supported, else poll)
4. On response: receive `processed_image_url`, `clothing_type`, `anchor_points`
5. Store in local state + Firebase Storage reference

### Auto Overlay Engine
1. Receive `anchor_points` (shoulder x/y, chest x/y, waist x/y) from API response
2. Load clothing PNG asset from URL
3. Map clothing to avatar's equivalent anchor points (pre-defined per avatar type)
4. Scale and position clothing using the anchor point deltas
5. Render on canvas
6. If `confidence_score < 0.7`, show manual adjustment UI

### AI Feedback
1. `POST /feedback` with `{ user_id, outfit_id, avatar_type, clothing_type }`
2. Show loading state on AI Feedback sheet while awaiting response
3. On success: animate rating arc, render suggestion cards
4. On error: show "Feedback unavailable. Try again." with retry button
5. Cache feedback result locally so re-opening the sheet doesn't re-call API

### Save Outfit
1. Compile outfit data: `{ user_id, avatar_id, clothing_url, position, scale, ai_feedback }`
2. `POST /save-outfit` to FastAPI or write directly to Firestore
3. On success: show success toast + update wardrobe screen cache
4. On error: show error toast with retry

---

## 🔒 Security Requirements (Frontend)

- **Never** store Google access tokens in PlayerPrefs (use encrypted storage)
- All API requests must include Firebase `idToken` in `Authorization: Bearer <token>` header
- Image URLs from Firebase Storage must use signed URLs (not public)
- No user PII (name, weight, height) should be logged to console in production builds
- Validate all user input client-side before sending to API

---

## ♿ Accessibility Requirements

- All interactive elements must have semantic labels (for TalkBack / VoiceOver)
- Minimum tap target size: 44×44dp on all interactive elements
- Color contrast: all text must meet WCAG AA (4.5:1 for normal text, 3:1 for large text)
- Error messages must not rely on color alone — include an icon
- Animations must be skippable via system Reduce Motion setting
- All images must have descriptive alt text / accessibility labels

---

## 📐 Responsive Considerations

- Design at 1080×2340 (FHD+ portrait) as baseline
- Scale factor must adapt for smaller screens (720×1560) — no content should be cut off
- Scrollable content wherever the list might exceed screen height
- Bottom nav + FAB must not overlap scrollable content (add bottom padding = nav height)
- Safe area insets: respect notch/punch-hole at top and gesture navigation area at bottom

---

## ✅ Definition of Done (Frontend)

A screen is considered complete when:
- All states (loading, success, error, empty) are implemented and visually distinct
- All navigation transitions are wired
- All API calls are connected (even if mocked for testing)
- Animations match the spec above
- Layout renders correctly on 720p and 1080p portrait screens
- Accessibility labels are present on all interactive elements
- No hardcoded strings (all text must come from a localization/string table, even if only English for MVP)

---

*Start with the Design System and Component Library first, then build screens in order: Auth → Avatar Selection → Upload → Try-On Preview → AI Feedback → Home → Wardrobe → Profile.*
