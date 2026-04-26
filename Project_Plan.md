# 📱 Dressify — Virtual Try-On App (MDM)

## 🧠 Overview
Dressify is a mobile application that allows users to:
- Create/select avatars
- Upload clothing images
- Automatically visualize outfits using intelligent 2D overlay
- Receive AI-based styling feedback

---

# 🎯 Product Vision (MVP)

Deliver a fast and intuitive **2D virtual try-on experience** where users can:
> Upload clothing → Auto-fit on avatar → Preview instantly → Save outfits

Focus:
- Speed
- Simplicity
- “Good enough” realism (not perfect)

---

# ✅ Functional Requirements (MVP)

## 👤 User Management
- Google Sign-In (OAuth)
- Basic profile:
  - Name
  - Height
  - Weight
  - Body Type

---

## 🧍 Avatar System (2D)
- Predefined avatars (10 types: 5 female + 5 male, each in Slim/Athletic/Average/Curvy/Plus)
- Avatar selection
- Basic scaling (based on user attributes)

---

## 👕 Clothing Upload & Processing
- Upload clothing image
- Background removal (segmentation)
- Store processed image

---

## 🎯 Auto Overlay Engine (CORE)
- Detect clothing type (top, bottom, etc.)
- Map clothing to avatar anchor points:
  - Shoulders
  - Chest
  - Waist
- Automatically:
  - Position
  - Scale
  - Align
- Optional manual adjustment (fallback)

---

## 📷 Preview System
- Render avatar with applied clothing
- Real-time updates on adjustments

---

## 💾 Wardrobe Management
- Save outfits
- Load saved outfits
- Store user clothing assets

---

## 🤖 AI Styling Feedback
- Analyze outfit
- Provide:
  - Rating (1–10)
  - Suggestions (color, balance, etc.)

---

# ⚙️ Non-Functional Requirements (MVP)

## 🚀 Performance
- Image processing: ≤ 3 seconds
- UI response: < 100ms
- Smooth rendering on mid-range devices

---

## 📱 Usability
- Minimal steps (upload → auto-fit → preview)
- Clean UI
- Easy interaction (drag/resize if needed)

---

## 🔒 Security
- Secure authentication (OAuth 2.0)
- Private image storage
- No unauthorized data access

---

## 📈 Scalability
- Cloud backend (Supabase — managed Postgres + Storage + Auth)
- Modular AI services

---

## 🧩 Maintainability
- Clean architecture
- Modular components:
  - Auth
  - Image processing
  - AI service

---

## 🌍 Compatibility
- Android (primary)
- iOS (secondary)
- Works on mid-range phones

---

## 🧠 AI Reliability
- Basic but meaningful feedback
- Avoid irrelevant suggestions

---

# 🚀 Development Phases

## 🟢 Phase 1: Core MVP
Goal: Basic try-on experience

- Google login
- Avatar selection
- Clothing upload
- Background removal
- Auto overlay (anchor-based)
- Preview rendering
- Save outfit
- Basic AI feedback
- Auto-Outfit Generation (AI Styling based on wardrobe)
- Live Weather Integration (for AI Context)
- AI Processing Status tracking
- API Rate Limiting for security

---

## 🟡 Phase 2: Camera Integration
- Real-time camera try-on
- Body detection (pose estimation)
- Live overlay

---

## 🔵 Phase 3: Personalization
- Body sliders (height/weight simulation)
- Improved fitting
- Advanced wardrobe system

---

## 🟣 Phase 4: Social + Commerce
- Post outfits
- Like/comment/DM
- Store uploads
- Purchase integration

---

## ⚫ Phase 5: 3D Upgrade
- 3D avatars
- Cloth simulation
- Realistic fitting

---

# 🛠️ Technology Stack (MVP)

## 🎮 Frontend (Mobile)
- **Flutter + Dart**
  - **Custom Painter** — pixel-level 2D canvas rendering
  - Same codebase for **Android + iOS**
  - **Hot reload** — fast iteration during development
  - Rich image & gesture libraries
  - **Flutter Flame** — optimized 2D game-like rendering for clothing overlay
  - Native performance with Dart compilation

---

## ☁️ Backend Data Layer
- **Supabase** (managed Postgres-based platform)
  - **Postgres** — relational DB for users, profiles, clothing items, outfits, outfit-items join, AI feedback
  - **Supabase Auth** — Google OAuth (verifies Google ID token, issues JWT)
  - **Supabase Storage** — S3-compatible object storage for raw and processed clothing images
  - Row-Level Security (RLS) policies enforce per-user data isolation
- Access from FastAPI via `asyncpg` / SQLAlchemy (direct Postgres) and `supabase-py` (Storage + Auth helpers)

---

## 🤖 AI / Image Processing
- Python (FastAPI)
- rembg → background removal
- OpenCV → image processing

---

## 🧠 AI Feedback
- LLM API (styling suggestions)
- Rule-based fallback system

---

## 🔗 Communication
- REST APIs (Flutter ↔ FastAPI) — **only channel between frontend and backend**
- Supabase SDK / Postgres connection lives on **backend only** (FastAPI ↔ Supabase)
- Frontend holds a JWT/session token from backend; no direct Supabase access

---

## 🧱 Architectural Rule: Thin Frontend, Heavy Backend
- **Frontend** is responsible **only** for UI and user interaction:
  - Render screens, capture input, show results
  - Collect images from gallery/camera
  - Display avatar + overlay returned by backend
  - Store session token locally
- **Backend** owns all processing:
  - Auth verification (Google ID token → Supabase Auth → backend JWT)
  - Image segmentation (rembg)
  - Clothing detection + anchor mapping
  - 2D avatar dressing / overlay composition
  - AI styling feedback
  - Supabase persistence (Postgres + Storage)
- Frontend **never** calls Supabase directly and **never** runs heavy ML/image processing.

---

# 🧩 System Architecture
[ Flutter Mobile App (Android + iOS) ]
|
| Dart + Custom Painter / Flame
| REST (dio) + JWT
↓
[ FastAPI Backend ]

Auth verification (Google ID token → JWT)
Image segmentation (rembg)
Clothing detection + anchor mapping
2D overlay composition
AI styling feedback (LLM)
|
↓
[ Supabase ]
Postgres  — users, profiles, clothing, outfits, feedback
Storage   — raw + processed clothing images
Auth      — Google OAuth verification



---

# 🎯 MVP Success Criteria

The MVP is successful if:
- User can upload clothing
- Clothing auto-fits correctly (~80% accuracy)
- Smooth preview experience
- User can save outfits
- AI provides useful feedback

---

# ⚡ Key Constraints

- No full 3D modeling (MVP is 2D)
- No complex cloth physics
- No perfect fitting required
- Focus on speed over perfection

---

# 🚧 Future Enhancements

- Real-time AR try-on
- Social features
- Brand/store integration
- Size-aware fitting
- 3D avatar system

---

# 📌 Notes

- Prioritize UX over complexity
- Keep AI simple in early stages
- Optimize performance early
- Build modular for scalability

---

# 📝 To Do (Developer Action Items)

- [ ] **Native Google Sign-In Setup**: Configure Google Cloud Console / Firebase project for Android to resolve `PlatformException` during real auth flow.
  - Generate SHA-1 fingerprint for Android local development (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`).
  - Create OAuth 2.0 Client ID for Android in Google Cloud Console.
  - Download `google-services.json` and place it in `Frontend/android/app/`.
  - Add Google Services plugin dependencies to Android `build.gradle` files.
- [ ] **Dedicated Style Tips Screen**: Build out a completely separate "Style Tips" screen to replace the current shortcut that just opens the "Style Me" bottom sheet. This screen should display AI-generated seasonal fashion advice, wardrobe analytics, and style inspiration.

---