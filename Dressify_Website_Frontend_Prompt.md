# 🌐 Dressify — Website Frontend Development Prompt
### Stack: React · Next.js 14 (App Router) · Tailwind CSS · Framer Motion

---

## 📌 Project Overview

You are building the **official Dressify website** — a dual-purpose platform that serves as both a **marketing landing page** and a **fully functional browser-based web app** where users can virtually try on clothing. The site is built with **Next.js 14 (App Router)**, styled with **Tailwind CSS**, animated with **Framer Motion**, and connected to a **FastAPI backend** and **Firebase** for auth, storage, and data.

The website has two distinct zones:

| Zone | Route | Purpose |
|---|---|---|
| **Marketing Site** | `/` `/features` `/pricing` `/about` | Attract visitors, explain the product, convert to sign-ups |
| **Web App** | `/app/upload` `/app/try-on` `/app/wardrobe` `/app/profile` | Let authenticated users try on clothing in the browser |

---

## 🎯 Core Goals

- Let visitors **understand Dressify in under 10 seconds**
- Let users **upload clothing and try it on without downloading anything**
- Deliver a **fast, polished, memorable experience** on desktop and mobile browsers
- Convert visitors → sign-ups → active users

---

## 🎨 Design System

### Aesthetic Direction
**Refined editorial meets modern tech.** Think high-fashion magazine layout fused with a clean SaaS product. The site should feel premium, confident, and intentional — not generic.

### Fonts

| Role | Font | Source |
|---|---|---|
| Display / Hero | `Playfair Display` | Google Fonts |
| UI / Body | `DM Sans` | Google Fonts |
| Monospace (code/labels) | `DM Mono` | Google Fonts |

Load via `next/font/google`. Never use Inter, Roboto, or system-ui as primary fonts.

### Color Tokens (CSS Variables)

```css
:root {
  --color-primary:       #6C63FF;
  --color-primary-dark:  #4B44CC;
  --color-primary-light: #EDE9FF;
  --color-accent:        #FF6B9D;       /* pink accent for highlights */
  --color-surface:       #FFFFFF;
  --color-surface-2:     #F7F6FF;       /* off-white tinted background */
  --color-background:    #FAFAFA;
  --color-text-primary:  #111118;
  --color-text-secondary:#6B6B8A;
  --color-border:        #E8E6F0;
  --color-success:       #22C97A;
  --color-error:         #FF5C5C;
  --color-warning:       #F5A623;

  /* Dark mode overrides */
  --color-surface-dark:  #1A1A2E;
  --color-background-dark: #0D0D1A;
  --color-text-dark:     #F0EFFF;
}
```

### Spacing Scale
Use Tailwind's default spacing (4px base unit). Stick to: `1 / 2 / 3 / 4 / 6 / 8 / 10 / 12 / 16 / 20 / 24`. No arbitrary values.

### Border Radius

| Element | Class |
|---|---|
| Cards | `rounded-2xl` (16px) |
| Buttons (full) | `rounded-xl` (12px) |
| Inputs | `rounded-lg` (8px) |
| Chips/badges | `rounded-full` |
| Avatars | `rounded-full` |
| Modals | `rounded-3xl` (24px) |
| Image thumbnails | `rounded-2xl` |

### Shadows

```css
.shadow-card   { box-shadow: 0 4px 16px rgba(108,99,255,0.08); }
.shadow-float  { box-shadow: 0 8px 32px rgba(108,99,255,0.14); }
.shadow-modal  { box-shadow: 0 24px 64px rgba(0,0,0,0.18); }
```

### Motion Principles (Framer Motion)

- **Page enter**: `opacity: 0 → 1`, `y: 20 → 0`, duration `0.4s`, `ease: [0.25, 0.46, 0.45, 0.94]`
- **Stagger children**: `staggerChildren: 0.07`
- **Hover lift**: `y: -4`, `shadow` increase, duration `0.2s`
- **Button press**: `scale: 0.97`, duration `0.1s`
- **Modal open**: slide up from bottom + fade, `scale: 0.96 → 1`
- **Section reveal**: use `useInView` hook — animate when 20% of element enters viewport
- Respect `prefers-reduced-motion` — wrap all motion in a hook that disables animation when set

---

## 🗂️ Project Structure

```
/app
  /                        → Landing page (public)
  /features                → Features detail page (public)
  /pricing                 → Pricing page (public)
  /about                   → About/team page (public)
  /auth
    /login                 → Sign-in page
    /callback              → OAuth callback handler
  /app
    /layout.tsx            → Authenticated shell (sidebar + topbar)
    /upload                → Clothing upload screen
    /try-on/[id]           → Try-on preview screen
    /wardrobe              → Saved wardrobe
    /profile               → User profile & settings
    /feedback/[outfitId]   → AI styling feedback

/components
  /marketing               → Landing page components
  /ui                      → Shared UI components (Button, Input, Card, etc.)
  /app                     → App-specific components (Canvas, UploadZone, etc.)
  /layout                  → Navbar, Footer, Sidebar, TopBar

/lib
  /firebase.ts             → Firebase client init
  /api.ts                  → FastAPI client (fetch wrappers)
  /auth.ts                 → Auth helpers
  /hooks                   → Custom React hooks

/types
  index.ts                 → Global TypeScript types

/public
  /fonts                   → Self-hosted font fallbacks
  /images                  → Static marketing assets
  /avatars                 → Predefined avatar SVGs
```

---

## 🌐 PART 1 — MARKETING SITE

---

### Page: `/` — Homepage / Landing

#### Section 1 — Navbar (Sticky)

**Behavior:**
- Transparent on scroll position 0, transitions to white/blur background after 80px scroll
- Use `backdrop-filter: blur(12px)` + `background: rgba(255,255,255,0.85)` when scrolled
- Transition: 300ms ease

**Layout (desktop):**
```
[Logo]  [Nav links: Features · Pricing · About]  [Sign In]  [Try Free →]
```

**Layout (mobile):**
```
[Logo]  [Hamburger menu icon]
```

**Logo:** Dressify wordmark in `Playfair Display`, bold, `--color-primary` color.

**Nav Links:** `DM Sans`, 15px, `--color-text-secondary`. Hover: color shifts to `--color-primary`, underline slides in from left (CSS pseudo-element, 2px, 200ms).

**"Sign In" Button:** Ghost style — no background, border `1.5px solid --color-border`, `--color-text-primary`.

**"Try Free →" Button:** Primary filled, `--color-primary` background, white text, arrow icon animates right on hover (translateX 3px, 200ms).

**Mobile Menu:** Full-screen overlay slides in from right. Links stacked vertically. Close button top-right.

---

#### Section 2 — Hero

**Layout:**
- Two-column on desktop (50/50): left = text + CTAs, right = product visual
- Single column on mobile: text first, visual below

**Left Column:**
- Pre-headline badge: `✨ Now available in your browser` — pill shape, light purple background, primary text
- H1: `"Try on any outfit before you wear it."` — `Playfair Display`, 64px desktop / 40px mobile, `--color-text-primary`, line-height 1.1
- Subheading: `"Upload a clothing photo. See it on your avatar instantly. No app download needed."` — `DM Sans`, 18px, `--color-text-secondary`
- CTA buttons (row):
  - Primary: `"Start Trying On →"` — links to `/auth/login`
  - Secondary: `"Watch Demo"` — ghost button, plays modal video on click
- Social proof row: `"Loved by 10,000+ fashion enthusiasts"` + 5 star icons + avatar stack (5 circular user photos overlapping)

**Right Column:**
- **Hero Product Visual** — animated mockup of the app:
  - Browser frame (rounded corners, macOS-style traffic light dots)
  - Inside: the Try-On Preview screen showing an avatar wearing an outfit
  - Floating badges around the frame (Framer Motion, `y` oscillation loop):
    - `"AI Rating: 9.1 ⭐"` — top right
    - `"Background removed ✓"` — bottom left
    - `"Auto-fitted in 2.3s"` — top left
  - Subtle drop shadow under the browser frame

**Background:**
- Soft radial gradient mesh behind the hero — lavender top-left, warm pink bottom-right, opacity 30%
- No hard lines — purely atmospheric

**Animation on Load:**
- Left column: staggered fade-up (badge → h1 → sub → buttons → social proof), 70ms stagger
- Right column: fade in + slight scale from 0.95 → 1, 600ms, 200ms delay
- Floating badges: oscillate continuously (y: -8 to 8, 3s infinite ease-in-out, each with different delay)

---

#### Section 3 — Social Proof / Logos

**Layout:** Full-width strip, gray background, centered.

**Content:**
- Label: `"Trusted by style-forward teams at"` — 13px, uppercase, letter-spacing 0.1em, secondary color
- Logo row (6 brand logos, grayscale, 40px height each, 48px gap):
  - Logos fade from gray → color on hover

**Animation:** Logos scroll horizontally in a continuous marquee loop on mobile.

---

#### Section 4 — How It Works

**Layout:** Full-width section, light purple-tinted background (`--color-surface-2`).

**Header:**
- Eyebrow: `"Simple by design"` — 12px, uppercase, primary color, letter-spacing
- H2: `"From upload to outfit in 3 steps"` — `Playfair Display`, 48px
- Subtext: single sentence description

**Steps (3-column grid on desktop, vertical stack on mobile):**

Each step card:
- Step number — large (`Playfair Display`, 96px, opacity 10%, absolute positioned behind card as decorative element)
- Icon — 48px, custom SVG, primary color
- Title — `DM Sans`, 20px, bold
- Description — `DM Sans`, 15px, secondary color
- Connector line between cards (desktop only): dashed horizontal line with arrow, primary color

Step 1: **Upload** — "Take a photo or upload any clothing image from your device."
Step 2: **Auto-fit** — "Our AI detects the clothing type and fits it to your avatar automatically."
Step 3: **Preview & Save** — "See the result instantly. Get AI styling tips and save your outfit."

**Animation:** Each card fades up with stagger (0.15s) when section enters viewport.

---

#### Section 5 — Feature Highlights

**Layout:** Alternating two-column rows (text left / visual right, then text right / visual left).

**Feature 1 — Smart Background Removal**
- Visual: Before/after slider (drag handle in center) showing original clothing photo → clean transparent PNG
- Title: `"Clean clothing, zero effort"`
- Body: "Upload any photo — messy background, bad lighting, whatever. Our AI removes it instantly."
- Badge: `"< 3 seconds"`

**Feature 2 — Auto-Fit Overlay Engine**
- Visual: Animated GIF / video of clothing snapping onto avatar anchor points
- Title: `"It just fits."`
- Body: "Clothing auto-scales and positions to your avatar's shoulders, chest, and waist. No manual dragging needed."
- Badge: `"~80% accuracy"`

**Feature 3 — AI Styling Feedback**
- Visual: Screenshot of the AI feedback panel showing rating + suggestion cards
- Title: `"Your personal AI stylist"`
- Body: "Get a 1–10 rating plus tailored suggestions on color harmony, balance, and occasion fit."
- Badge: `"Powered by LLM"`

**Feature 4 — Wardrobe Management**
- Visual: Grid view of saved clothing items
- Title: `"Your entire wardrobe, organized"`
- Body: "Save outfits, browse your clothing collection, and rebuild looks anytime."

**Animation:** Each row slides in from alternating sides (left/right) as it enters the viewport.

---

#### Section 6 — Interactive Demo (Key Section)

**Purpose:** Let visitors experience a lite version of try-on without signing up.

**Layout:** Full-width section, dark background (`--color-background-dark`), light text.

**Header:**
- H2: `"Try it right now"` — white, `Playfair Display`, 52px
- Subtext: `"No sign-up needed. Upload any clothing image below."` — secondary color

**Demo Widget:**
- Clothing Upload Zone:
  - Dashed border rectangle (20px radius), 400×300px centered
  - Dark surface background
  - Upload icon + `"Drop a clothing image here"` text
  - Subtext: `"JPG or PNG, max 5MB"`
  - On upload → shows processing spinner → shows result
- Avatar Selector: 3 small avatar thumbnails in a row below upload zone — click to switch
- Output Preview: Shows selected avatar with clothing overlaid (uses `/demo` API endpoint — no auth required)
- Below result: `"Like what you see? Create a free account to save this outfit →"` CTA

**Constraints:**
- Demo is limited: 1 item, no save, no AI feedback (shows blurred feedback teaser)
- Rate limited per IP: 3 tries per hour

---

#### Section 7 — Testimonials

**Layout:** 3-column card grid on desktop, horizontal scroll on mobile.

Each card:
- Quote text — `Playfair Display`, italic, 18px
- User name + title below
- User avatar (circular, 44px)
- 5-star rating row
- Card: white, `rounded-2xl`, shadow-card

**Background:** Subtle diagonal stripe pattern using CSS (thin lines, primary color at 4% opacity).

**Animation:** Cards fade up with stagger on scroll into view.

---

#### Section 8 — Pricing

**Layout:** 3 pricing cards centered.

| Plan | Free | Pro | Team |
|---|---|---|---|
| Price | $0 | $12/mo | $29/mo |
| Uploads/mo | 5 | Unlimited | Unlimited |
| AI Feedback | 3/mo | Unlimited | Unlimited |
| Wardrobe | 10 items | Unlimited | Shared team wardrobe |
| Avatars | 3 | 5 | Custom |

**Pro card:** Visually elevated — primary background, white text, `"Most Popular"` badge top-right, slightly taller than others.

Each card:
- Plan name — 13px, uppercase, letter-spacing
- Price — `Playfair Display`, 48px + `/month` in 16px secondary
- Feature list with checkmark icons (green)
- CTA button — full width

**Toggle:** Annual / Monthly billing toggle at top — annual shows `"Save 20%"` badge in green.

**Animation:** Cards scale up from 0.95 on scroll-in.

---

#### Section 9 — CTA Banner

**Layout:** Full-width, primary gradient background (`--color-primary` → `--color-primary-dark`).

**Content:**
- H2: `"Your wardrobe. Reimagined."` — white, `Playfair Display`, 52px, centered
- Subtext — white 70% opacity
- CTA button: white background, primary text — `"Get Started Free →"`

**Background decoration:** Subtle abstract clothing silhouettes pattern in white at 5% opacity.

---

#### Section 10 — Footer

**Layout:** 4-column grid on desktop, stacked on mobile.

Column 1: Logo + tagline + social icons (Instagram, Twitter/X, TikTok)
Column 2: Product links — Features, Pricing, Try Demo, Download App
Column 3: Company — About, Blog, Careers, Press
Column 4: Legal — Privacy Policy, Terms, Cookie Settings

Bottom bar: `© 2025 Dressify. All rights reserved.` + `Made with ❤️ for fashion lovers.`

---

### Page: `/features` — Features Detail

- Full deep-dive on each feature
- Each feature gets a dedicated section with large visuals, technical details, and use-case examples
- Sticky side navigation (desktop): highlights the current feature section as user scrolls

---

### Page: `/pricing` — Pricing

- Expanded pricing page with full feature comparison table
- FAQ section below cards
- Enterprise contact form at bottom

---

### Page: `/about` — About

- Mission statement section
- Team member cards (photo, name, role, LinkedIn link)
- Company timeline / milestones
- Investor/press logos

---

### Page: `/auth/login` — Sign In

**Layout:** Split screen — left: marketing panel, right: auth form.

**Left Panel (40%):**
- Dark background (`--color-background-dark`)
- Dressify logo top-left (white)
- Large quote + attribution (rotating, changes every 6s with fade transition)
- Bottom: 3 feature bullet points

**Right Panel (60%):**
- White background, centered vertically
- Title: `"Welcome to Dressify"` — `Playfair Display`, 32px
- Subtitle: "Sign in to access your virtual wardrobe"
- Google Sign-In button (full Google branding spec)
- Divider: `"or continue with email"` — gray line both sides
- Email input + Password input + "Forgot password?" link
- Sign In button (primary)
- "Don't have an account? Sign up free" link at bottom

**States:**
- `idle` — default form
- `loading` — button spinner, inputs disabled
- `error` — red banner above form: specific error message
- `success` — brief success state → redirect to `/app/upload`

---

## 📱 PART 2 — WEB APP (`/app/*`)

---

### App Shell Layout

All `/app/*` routes share a persistent shell layout.

**Top Navigation Bar (desktop + mobile):**
- Height: 64px
- Left: Dressify logo (small)
- Center (desktop only): breadcrumb or page title
- Right: `[Notifications bell]` `[User avatar dropdown]`

**User Avatar Dropdown:**
- User name + email at top
- Links: My Profile, Settings, Sign Out
- `rounded-2xl`, shadow-modal, 240px wide

**Sidebar (desktop, 240px wide, fixed left):**

```
[Avatar thumbnail + user name]

Navigation:
  🏠 Home
  ⬆️  Upload Clothing
  👕 Try On
  🗂️  My Wardrobe
  🤖 AI Feedback
  ⚙️  Profile

[Upgrade to Pro CTA at bottom]
```

- Active item: primary light background (`--color-primary-light`), primary text color, left border 3px primary
- Inactive: secondary text color
- Collapsed to icon-only on medium screens (hover tooltip shows label)

**Bottom Nav Bar (mobile only, fixed):**
- 4 tabs: Home · Upload · Wardrobe · Profile
- Active: primary color icon + label, dot indicator

**Content Area:**
- Left: `240px` (sidebar) + right: remaining width
- Max content width: `1200px`, centered
- Padding: `24px` desktop, `16px` mobile

---

### App Page: `/app/upload` — Clothing Upload

**Purpose:** Upload a clothing image and process it (background removal + detection).

#### Layout

**Page Header:**
- Title: "Upload Clothing" — `DM Sans`, 24px, bold
- Subtitle: "Add a new item to your virtual wardrobe"

**Main Upload Panel (card, centered, max-width 640px):**

**Step Indicator (top of card):**
```
① Upload  →  ② Process  →  ③ Preview
```
- Active step: primary color circle, bold label
- Completed step: green checkmark circle
- Upcoming: gray circle, secondary text

**Upload Zone:**
- Large dashed-border area, `rounded-2xl`, 320px tall
- Center content:
  - Upload cloud icon (48px, primary color)
  - Primary text: `"Drop your clothing photo here"`
  - Secondary text: `"or click to browse files"`
  - Accepted formats badge: `JPG · PNG · WebP · Max 10MB`
- Drag-over state: border becomes solid primary, background becomes `--color-primary-light`, icon animates (bounce)
- Uses HTML5 drag-and-drop API + `<input type="file" accept="image/*">` click trigger

**After File Selected (Step 1 complete):**
- Image preview shown inside the upload zone (cover-fit, rounded)
- File name + size shown below
- `"Change file"` text button
- Clothing type detection result badge:
  - `"👕 Top detected"` — green pill
  - `"👖 Bottom detected"` — green pill
  - `"⚠️ Uncertain — select type"` — amber pill + dropdown selector below:
    - Options: Top / Bottom / Dress / Jacket / Shoes / Accessory / Other

**Processing Button:**
- `"Remove Background & Continue →"` — full width, primary, 52px height
- Disabled until file selected + type confirmed

**Processing State (Step 2):**
- Upload zone replaced by a processing panel:
  - Original image on left (40%), processed result on right (40%), animated divider between
  - Result side: shimmer skeleton while processing
  - Progress bar below with percentage
  - Stage label: `"Removing background…"` → `"Detecting clothing type…"` → `"Done!"`
  - Cancel button (ghost, bottom)

**Success State (Step 3):**
- Processed PNG shown (transparent background rendered on checkered pattern)
- Green success badge: `"✓ Background removed"`
- Detected type confirmation: `"Detected as: Top"`
- Item name input (editable, pre-filled with filename)
- Two CTA buttons:
  - `"Try On Now →"` — primary → navigates to `/app/try-on/[newItemId]`
  - `"Save to Wardrobe"` — secondary outlined → saves and stays on page

**Error State:**
- Red banner above upload zone with specific error
- `"Try Again"` button resets to Step 1

---

### App Page: `/app/try-on/[id]` — Try-On Preview

**Purpose:** The core feature. Display the avatar wearing the uploaded clothing.

#### Layout (Desktop — Two Column)

**Left Panel (55% width) — Preview Canvas:**
- Dark neutral background (`#1A1A2A`) — prevents clothing from blending
- Avatar rendered centered, full height of panel
- Clothing overlaid at correct anchor points
- Canvas toolbar (top-right of panel, vertical stack of circular icon buttons):
  - Zoom in / Zoom out (changes canvas scale)
  - Reset view
  - Toggle avatar visibility (eye icon)
  - Fullscreen mode
- Drag handle overlay on clothing item when manual adjustment is active

**Manual Adjustment UI (shown when confidence < 70%):**
- Amber info bar at top of canvas: `"⚠️ Auto-fit is approximate — drag to adjust"`
- 8 drag handles appear on clothing bounding box corners and edges
- Clothing draggable via mouse / touch
- Pinch to resize on touch devices
- Scroll wheel to resize on desktop

**Right Panel (45% width) — Details & Actions:**

```
[Clothing item thumbnail + name]
[Detected type chip]

Avatar Selector:
  [3–5 avatar thumbnails in a row]
  Clicking switches the avatar in the canvas

Color Variants (future — show grayed out):
  [Color swatches row]
  "More colors coming soon" tooltip

──────────────────

[⭐ Get AI Feedback]    ← secondary outlined button
[💾 Save Outfit]         ← primary button

──────────────────

Saved Outfit Details (visible after saving):
  Outfit name (editable inline)
  Date saved
  View in Wardrobe →
```

**States:**
- `rendering` — skeleton placeholder on canvas, spinner, `"Fitting your look…"` label
- `success` — full UI visible
- `low_confidence` — amber banner + drag handles
- `saving` — Save button shows spinner
- `saved` — Save button becomes `"Saved ✓"` (green, 2s) then reverts

#### Layout (Mobile — Stacked)
- Canvas fills top 60% of viewport
- Right panel scrolls below as a bottom panel (always visible, sticky to bottom with scroll)
- Toolbar icons float over canvas bottom-right

---

### App Page: `/app/feedback/[outfitId]` — AI Styling Feedback

**Purpose:** Full-page AI feedback view (also accessible as slide-over panel from Try-On).

#### Layout

**Back navigation:** `← Back to Try-On`

**Outfit Preview (top section):**
- Smaller canvas (400px wide, centered) showing avatar with outfit
- Outfit name + date

**AI Report Card (main section, max-width 680px centered):**

**Rating Widget:**
- Large circular gauge (SVG):
  - Outer track: light gray
  - Filled arc: animates from 0 → score on mount (600ms, ease-out)
  - Color: green ≥7, amber 4–6, red <4
  - Center: score number in `Playfair Display`, 52px
  - Below: `/10` in secondary color, 18px
- Overall verdict line: `"Great casual look! ✨"` — 20px, centered

**Category Breakdown (4 cards):**

Each category card:
- Card: white, `rounded-2xl`, shadow-card, 16px padding
- Left: colored icon (48px) in a rounded square background
- Right:
  - Category name — 13px, uppercase, letter-spacing, secondary color
  - Sub-score — 20px, bold, primary color
  - Suggestion text — 15px, secondary color
  - Expandable (click to expand full suggestion)

Categories:
1. 🎨 **Color Harmony** — "The navy top pairs well with neutral tones. Consider adding a warm accent."
2. ⚖️ **Style Balance** — "Top-heavy silhouette. Balance with slim-fit bottoms."
3. 🎯 **Occasion Fit** — "Perfect for casual daywear or weekend errands."
4. 🔥 **Trend Score** — "Oversized fits are trending — this works."

**Regenerate Button:**
- `"↻ Regenerate Feedback"` — text button with spin animation on click
- Re-calls AI API, shows skeleton loading state on the report card while loading

**Action Buttons:**
- `"Save Outfit + Feedback"` — primary, full width
- `"Share Look"` — secondary, copies shareable link (future feature, shown disabled with "Coming soon" tooltip)

**Slide-Over Variant (used when triggered from Try-On page):**
- Renders as a right-side drawer on desktop (480px wide)
- Full-screen sheet on mobile (slides up from bottom)
- Same content as full page, condensed spacing
- Close button top-right

---

### App Page: `/app/wardrobe` — My Wardrobe

**Purpose:** Browse, filter, and manage all saved clothing and outfits.

#### Layout

**Page Header:**
- Title: "My Wardrobe"
- Right side: `"+ Add Clothing"` primary button → `/app/upload`
- Search bar: full-width below header, `"Search your wardrobe…"`, debounced 300ms

**Tab Bar:**
- Two tabs: `Clothing Items` | `Saved Outfits`
- Underline indicator, animated slide between tabs (Framer Motion `layoutId`)

---

**Clothing Items Tab:**

Filter Bar (sticky below tab bar):
- Chip group (horizontal scroll on mobile): `All` `Tops` `Bottoms` `Dresses` `Jackets` `Shoes` `Other`
- Right side: Sort dropdown (`Newest` / `Oldest` / `A–Z`)

Grid (responsive):
- Desktop: 4 columns
- Tablet: 3 columns
- Mobile: 2 columns

Each clothing card (`rounded-2xl`, shadow-card):
- Top: clothing image on light gray background, `aspect-square`, `object-contain`
- Bottom: item name (1 line, truncated), type chip
- Hover state (desktop): overlay appears with `"Try On"` and `"Delete"` action buttons
- Long press (mobile): context menu with same actions

Empty State:
- Centered illustration of an empty hanger
- `"No clothing items yet"`
- `"Upload your first item →"` CTA button

---

**Saved Outfits Tab:**

Grid (same responsive columns as above):

Each outfit card:
- Top: avatar thumbnail with outfit overlaid (rendered server-side as static image), `aspect-[3/4]`
- Bottom: outfit name, date saved, AI rating badge (star + score)
- Hover: overlay with `"View"`, `"Get Feedback"`, `"Delete"` actions

Empty State:
- `"No saved outfits yet"`
- `"Try on something →"` CTA

---

**Delete Confirmation (Modal):**
- `rounded-3xl` modal, centered, 400px wide
- `"Delete this item?"` — 20px bold
- Warning: `"This action cannot be undone."`
- Buttons: `"Cancel"` (ghost) + `"Delete"` (red destructive)
- Backdrop: `rgba(0,0,0,0.55)` blur

---

### App Page: `/app/profile` — Profile & Settings

**Layout:** Two-column on desktop (sidebar navigation + content area), single column on mobile.

**Left Sidebar (200px):**
- Navigation list:
  - My Profile
  - Body Stats
  - Appearance
  - Notifications
  - Privacy & Security
  - Billing
  - Sign Out

**Content Area (right):**

**My Profile Section:**
- Avatar thumbnail (80px circle) + `"Change photo"` link below
- Full name — editable inline (click to edit, `Enter` to save)
- Email — read-only, shows `"Verified ✓"` badge
- `"Save Changes"` button (appears when any field is dirty)

**Body Stats Section:**
- Form card:
  - Height — number input + unit toggle (cm / ft·in)
  - Weight — number input + unit toggle (kg / lbs)
  - Body Type — chip selector: Slim / Athletic / Average / Curvy / Plus
  - `"Update Stats"` button

**Appearance Section:**
- Theme: Radio group — Light / Dark / System
- Language: Dropdown (English only for MVP, others grayed out with "Coming soon")

**Notifications Section:**
- Toggle list:
  - Email notifications — on/off
  - Style tips newsletter — on/off
  - Product updates — on/off

**Privacy & Security Section:**
- `"Change Password"` → modal form
- `"Connected Accounts"` — shows Google account connected, disconnect button
- `"Delete Account"` — red text link → confirmation modal (type "DELETE" to confirm)

**Billing Section (only for Pro/Team):**
- Current plan badge
- Next billing date
- `"Manage Subscription"` → Stripe portal redirect
- `"Cancel Plan"` text link (red)

**Sign Out:**
- Red `"Sign Out"` button
- Confirmation dialog: `"Sign out of Dressify? Your data will be saved."` — Cancel + Sign Out

---

## ⚙️ Shared Component Library

All components live in `/components/ui/`. Each must be fully typed with TypeScript.

---

### `<Button>`
```tsx
variant: "primary" | "secondary" | "ghost" | "destructive"
size:    "sm" | "md" | "lg"
loading: boolean   // shows spinner, disables
icon?:   ReactNode // left or right icon
```
- Primary: filled `--color-primary`, white text, hover darken 8%
- Secondary: outlined `1.5px border`, primary color text
- Ghost: no border, no background, hover: light primary background
- Destructive: red background, white text
- All: `rounded-xl`, `font-medium`, Framer Motion `whileTap: { scale: 0.97 }`

---

### `<Input>`
```tsx
label?:       string
error?:       string
hint?:        string
leftIcon?:    ReactNode
rightElement?: ReactNode
```
- `rounded-lg`, 48px height
- Border: `--color-border` idle → `--color-primary` focus → `--color-error` error
- Label floats up on focus (Framer Motion `AnimatePresence`)
- Error message fades in below input

---

### `<Card>`
```tsx
padding?: "sm" | "md" | "lg"
hover?:   boolean  // enables hover lift animation
```
- `rounded-2xl`, `shadow-card`, `bg-white`
- Hover: `y: -4`, `shadow-float`, 200ms ease

---

### `<Badge>` / `<Chip>`
```tsx
variant: "success" | "warning" | "error" | "info" | "neutral" | "primary"
size:    "sm" | "md"
dot?:    boolean  // colored dot on left
```
- `rounded-full`, colored background at 15% opacity, colored text

---

### `<Modal>`
```tsx
isOpen:    boolean
onClose:   () => void
title?:    string
size?:     "sm" | "md" | "lg" | "fullscreen"
```
- `rounded-3xl`, `shadow-modal`
- Framer Motion: `scale: 0.96 → 1`, `opacity: 0 → 1`, spring animation
- Backdrop: click to close, `rgba(0,0,0,0.55)`, blur 4px
- Close button top-right (`×`, 32px)
- Trap focus inside modal when open (accessibility)

---

### `<Drawer>` (Slide-over)
```tsx
isOpen:    boolean
onClose:   () => void
side?:     "right" | "bottom"  // right on desktop, bottom on mobile
width?:    number  // default 480px
```
- Right drawer: slides in from right, full height
- Bottom sheet: slides up from bottom, `rounded-t-3xl`
- Drag handle on bottom sheets

---

### `<UploadZone>`
```tsx
onFile:      (file: File) => void
accept?:     string  // default "image/*"
maxSize?:    number  // bytes, default 10MB
disabled?:   boolean
```
- Manages drag-over, drag-leave, drop events
- Validates file type and size client-side
- Shows error state inline if invalid

---

### `<AvatarCanvas>`
```tsx
avatarId:     string
clothingUrl:  string
anchorPoints: AnchorPoints
onAdjust?:    (transform: Transform) => void
interactive?: boolean  // enables drag handles
```
- Renders avatar SVG + clothing PNG overlay
- Handles zoom, pan, drag adjustment
- Exposes imperative handle for reset/zoom controls

---

### `<ProgressBar>`
```tsx
value:   number  // 0–100
label?:  string
size?:   "sm" | "md"
```
- Framer Motion `width` animation
- `--color-primary` fill, light gray track

---

### `<Skeleton>`
```tsx
width?:  string | number
height?: string | number
rounded?: string
```
- CSS shimmer animation (background gradient sweep)
- Used as placeholder during loading states

---

### `<Toast>` (via `useToast` hook)
```tsx
toast.success("Outfit saved!")
toast.error("Upload failed. Try again.")
toast.info("Background removed ✓")
```
- Renders via `<Toaster>` in root layout
- Slides up from bottom-right (desktop) or bottom-center (mobile)
- Auto-dismiss 3s, manual dismiss via `×`
- Stack up to 3 visible at once

---

### `<RatingGauge>`
```tsx
score:    number  // 0–10
animated: boolean
size?:    "sm" | "md" | "lg"
```
- SVG arc gauge
- Framer Motion animates arc fill from 0 → score on mount
- Color: green ≥7, amber 4–6, red <4

---

## 🔄 Routing & Navigation

### Route Protection
Use Next.js middleware (`middleware.ts`) to:
- Redirect `/app/*` to `/auth/login` if no valid Firebase session
- Redirect `/auth/login` to `/app/upload` if already authenticated

### Route Transitions
Wrap all pages in a `<PageTransition>` component:
```tsx
// Fade-up on enter, fade-down on exit
<motion.div
  initial={{ opacity: 0, y: 16 }}
  animate={{ opacity: 1, y: 0 }}
  exit={{ opacity: 0, y: -8 }}
  transition={{ duration: 0.3, ease: [0.25, 0.46, 0.45, 0.94] }}
>
  {children}
</motion.div>
```

### Loading States
Use Next.js `loading.tsx` per segment. Each app route has a skeleton loading screen that mirrors the page layout.

---

## 🔌 API Integration

### Firebase Auth (Client-side)
```ts
// /lib/firebase.ts
import { initializeApp } from "firebase/app";
import { getAuth, GoogleAuthProvider, signInWithPopup } from "firebase/auth";

// Always check auth state on app mount
// Store idToken in memory (not localStorage) — refresh on expiry
// Attach to all API calls as Authorization: Bearer <idToken>
```

### API Client (`/lib/api.ts`)
```ts
// All FastAPI calls go through this wrapper
async function apiRequest<T>(
  endpoint: string,
  options?: RequestInit
): Promise<T> {
  const token = await getFirebaseToken();
  const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}${endpoint}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
      ...options?.headers,
    },
  });
  if (!response.ok) throw new ApiError(response.status, await response.json());
  return response.json();
}
```

### Key Endpoints

| Method | Endpoint | Called From | Description |
|---|---|---|---|
| `POST` | `/upload` | Upload page | Upload image, returns processed URL + type + anchor points |
| `GET` | `/clothing/:id` | Try-On page | Fetch clothing item details |
| `POST` | `/feedback` | Feedback page | Get AI styling feedback for outfit |
| `POST` | `/outfits` | Try-On page | Save outfit to Firestore |
| `GET` | `/outfits` | Wardrobe page | Fetch all user outfits |
| `DELETE` | `/outfits/:id` | Wardrobe page | Delete outfit |
| `GET` | `/clothing` | Wardrobe page | Fetch all user clothing items |
| `DELETE` | `/clothing/:id` | Wardrobe page | Delete clothing item |
| `POST` | `/demo/upload` | Landing demo | Unauthenticated demo upload (rate limited) |

### Upload Progress
Use `XMLHttpRequest` instead of `fetch` for upload to get `progress` events:
```ts
const xhr = new XMLHttpRequest();
xhr.upload.addEventListener("progress", (e) => {
  if (e.lengthComputable) {
    const pct = Math.round((e.loaded / e.total) * 100);
    setUploadProgress(pct);
  }
});
```

---

## ⚡ State Management

Use **Zustand** for global app state. No Redux.

```ts
// stores/useAppStore.ts
interface AppStore {
  user:          User | null;
  currentAvatar: AvatarId;
  wardrobeItems: ClothingItem[];
  savedOutfits:  Outfit[];

  setUser:         (user: User | null) => void;
  setAvatar:       (id: AvatarId) => void;
  addClothingItem: (item: ClothingItem) => void;
  addOutfit:       (outfit: Outfit) => void;
  removeOutfit:    (id: string) => void;
}
```

Use **React Query (TanStack Query)** for all server data fetching:
- Caches wardrobe data, invalidates on mutations
- Handles loading/error states automatically
- `staleTime: 5 * 60 * 1000` (5 minutes) for wardrobe data

---

## 🔒 Security (Frontend)

- Firebase `idToken` stored in memory only (never `localStorage`, never cookies without `httpOnly`)
- All image URLs from Firebase Storage use **signed URLs with expiry** — never public bucket URLs
- Demo endpoint rate-limited per IP on the API side; frontend shows `"Daily limit reached"` gracefully
- No sensitive user data (weight, height) logged to `console` in production builds
- Content Security Policy headers set via `next.config.js`
- Input sanitization on all user-provided text (item names, profile name)

---

## ♿ Accessibility

- All interactive elements: minimum 44×44px tap target
- All images: `alt` attributes required (TypeScript enforces via prop types)
- Color contrast: WCAG AA (4.5:1 body, 3:1 large text) — verify with Tailwind contrast checker
- Focus management: modal open → focus trap inside → close → focus returns to trigger
- `aria-live="polite"` regions for toast notifications and status updates
- Keyboard navigation: full keyboard support for all modals, dropdowns, and upload zone
- Skip-to-content link at top of every page (visually hidden, visible on focus)
- `prefers-reduced-motion`: all Framer Motion animations wrapped in:
  ```ts
  const prefersReducedMotion = useReducedMotion();
  const transition = prefersReducedMotion ? { duration: 0 } : { duration: 0.4 };
  ```

---

## 📱 Responsive Breakpoints

| Name | Width | Target |
|---|---|---|
| `sm` | 640px | Large phones (landscape) |
| `md` | 768px | Tablets |
| `lg` | 1024px | Small laptops |
| `xl` | 1280px | Desktop |
| `2xl` | 1536px | Large desktop |

**Key responsive rules:**
- Marketing site: readable and beautiful from 375px to 1920px
- App sidebar: hidden below `lg`, replaced by bottom nav
- Try-On canvas: full width on mobile, 55% on desktop
- Wardrobe grid: 2 cols → 3 cols → 4 cols (`grid-cols-2 md:grid-cols-3 xl:grid-cols-4`)
- Typography: `clamp()` for hero h1 — `clamp(2rem, 5vw, 4rem)`

---

## ⚙️ Next.js Configuration

```ts
// next.config.ts
const config = {
  images: {
    domains: [
      "firebasestorage.googleapis.com",
      "lh3.googleusercontent.com",  // Google profile photos
    ],
  },
  experimental: {
    optimizePackageImports: ["framer-motion", "lucide-react"],
  },
};
```

**Environment Variables (`.env.local`):**
```
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_API_URL=https://api.dressify.app
NEXT_PUBLIC_DEMO_RATE_LIMIT=3
```

---

## 📦 Key Dependencies

```json
{
  "dependencies": {
    "next": "14.x",
    "react": "18.x",
    "typescript": "5.x",
    "tailwindcss": "3.x",
    "framer-motion": "^11",
    "firebase": "^10",
    "zustand": "^4",
    "@tanstack/react-query": "^5",
    "lucide-react": "latest",
    "clsx": "latest",
    "tailwind-merge": "latest"
  }
}
```

---

## ✅ Definition of Done (Web)

A page / component is complete when:

- All states (loading, success, error, empty) are implemented and visually distinct
- Responsive across 375px → 1440px with no layout breaks
- Framer Motion animations implemented per spec, with `prefers-reduced-motion` fallback
- All interactive elements are keyboard accessible
- TypeScript — zero `any` types, all props fully typed
- No hardcoded colors or spacing values (use Tailwind tokens / CSS variables only)
- React Query handles all server data — no manual `useEffect` fetching
- Page loads in < 2s on fast 3G (Lighthouse performance score ≥ 85)

---

## 🚀 Build Order

Build in this sequence to maximize velocity:

1. Design system setup (Tailwind config, CSS variables, fonts)
2. Shared UI components (`Button`, `Input`, `Card`, `Modal`, `Toast`)
3. Auth flow (`/auth/login`, Firebase integration, middleware)
4. App shell (layout, sidebar, topbar, bottom nav)
5. Upload page (`/app/upload`)
6. Try-On page (`/app/try-on/[id]` + `<AvatarCanvas>`)
7. AI Feedback page + slide-over (`/app/feedback/[outfitId]`)
8. Wardrobe page (`/app/wardrobe`)
9. Profile page (`/app/profile`)
10. Landing page sections (Hero → How It Works → Features → Demo → Pricing → Footer)
11. Supporting marketing pages (`/features`, `/pricing`, `/about`)
12. Performance audit + Lighthouse optimization

---

*Build Dressify's web presence as a premium, fashion-forward product. Every pixel should communicate quality and trust.*
