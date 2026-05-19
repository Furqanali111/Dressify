# Dressify

An AI-powered personal stylist and virtual wardrobe app. Manage your clothing, try on garments live through your camera, generate outfits with LLMs, and get real-time fashion feedback — all from your phone.

## Features

### AR Live Try-On (Camera)
Point your camera at yourself and see garments warped onto your body in real time. Powered by Google ML Kit pose detection, body segmentation, and thin-plate spline (TPS) deformation. Pose-conditioned wrinkle maps (8 canonical poses) blend onto the garment as you move.

### AI Photo Try-On
Upload a full-body photo and get a photo-realistic result via [fashn.ai](https://fashn.ai) (with Replicate IDM-VTON as fallback). Results are cached for 24 hours per garment so repeated requests are instant.

### Virtual Wardrobe
Upload a clothing photo and the backend automatically:
- Detects and extracts each garment (background removal via rembg)
- Classifies type, color, pattern, style, sub-type, and size using an LLM (GPT-4o or Ollama Llama 3.2 Vision)
- Generates 8 pose-conditioned wrinkle maps per garment
- Queues failed uploads for automatic retry

### 2D Avatar Try-On
Drag garments onto a 2D avatar. Choose from 10 body types (male/female × slim/athletic/average/curvy/plus). Supports multi-garment outfits with drag-to-reposition.

### AI Outfit Generation
LLM-generated outfit suggestions from your wardrobe, personalized by occasion, live weather, style preferences, and a seed garment.

### Fit Rating
Size compatibility score (S–XXL) computed from your chest/waist measurements against each garment's size label.

### Wardrobe Analytics
Wear frequency tracking, underutilized item detection, color/style distribution charts, and cost-per-wear estimates.

### AI Style Feedback
Real-time outfit critique: color harmony, silhouette balance, occasion fit, and actionable suggestions.

## Tech Stack

### Backend
| Layer | Technology |
|---|---|
| Framework | FastAPI (Python 3.11+) |
| Database | PostgreSQL · SQLAlchemy (async) · Alembic |
| Auth | Supabase Auth (Google OAuth) · JWT |
| Storage | Supabase Storage |
| AI — Vision | OpenAI GPT-4o-mini · Ollama Llama 3.2 Vision |
| AI — Try-On | fashn.ai API · Replicate IDM-VTON (fallback) |
| Background Jobs | ARQ · Redis |
| Image Processing | Pillow · rembg · NumPy |
| Rate Limiting | SlowAPI (Redis-backed) |

### Frontend
| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State | Riverpod |
| Navigation | GoRouter |
| Camera / ML | Google ML Kit — Pose Detection, Body Segmentation |
| Warping | Thin-Plate Spline (TPS) — custom Dart implementation |
| Network | Dio |
| Auth | Google Sign-In |

## Project Structure

```
Dressify/
├── Backend/
│   ├── app/
│   │   ├── core/            # Rate limiting, security
│   │   ├── db.py            # Async SQLAlchemy session
│   │   ├── deps.py          # Auth dependency (JWT → User)
│   │   ├── models/          # ORM models (User, ClothingItem, Outfit, …)
│   │   ├── routers/         # API endpoints
│   │   │   ├── auth.py
│   │   │   ├── clothing.py
│   │   │   ├── tryon.py     # fashn.ai / Replicate try-on
│   │   │   ├── outfits.py
│   │   │   ├── analytics.py
│   │   │   ├── feedback.py
│   │   │   ├── wear_logs.py
│   │   │   └── …
│   │   ├── schemas/         # Pydantic request/response models
│   │   ├── services/
│   │   │   ├── image_processing.py  # Garment extraction, bg removal
│   │   │   ├── wrinkle_generation.py # 8-pose wrinkle map generation
│   │   │   ├── ai_vision.py         # GPT / Ollama metadata extraction
│   │   │   ├── ai_outfit_generator.py
│   │   │   ├── fit_rating.py
│   │   │   ├── retry_worker.py      # Upload retry queue (long-running task)
│   │   │   ├── storage.py           # Supabase Storage helpers
│   │   │   └── weather.py
│   │   ├── config.py        # Pydantic settings (loads .env)
│   │   └── worker.py        # ARQ worker jobs
│   ├── alembic/             # Database migrations
│   └── requirements.txt
├── Frontend/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── api/         # Dio client + interceptors
│   │   │   ├── models/      # Dart data models
│   │   │   ├── providers/   # Riverpod state notifiers
│   │   │   ├── router/      # GoRouter routes
│   │   │   ├── services/    # Camera, pose, segmentation, wrinkle cache
│   │   │   ├── theme/       # Design system (colors, spacing, typography)
│   │   │   ├── utils/       # TPS warper, garment control points, fit profiles
│   │   │   └── widgets/     # Shared widgets (AppToast, chips, …)
│   │   └── features/
│   │       ├── camera_try_on/   # Live AR try-on screen
│   │       ├── try_on/          # 2D avatar try-on screen
│   │       ├── tryon_result/    # AI photo try-on result
│   │       ├── wardrobe/        # Wardrobe grid, outfit cards
│   │       ├── upload/          # Garment upload flow
│   │       ├── feedback/        # AI style feedback
│   │       ├── style_tips/      # Wardrobe analytics
│   │       ├── profile/         # Measurements, style DNA
│   │       └── …
│   └── pubspec.yaml
└── Doc/                     # Feature plans and improvement logs
```

## Setup

### Prerequisites
- Python 3.11+
- Flutter 3.x
- Redis (for background jobs and rate limiting)
- A Supabase project (Auth + Storage + Postgres)
- OpenAI API key **or** a local Ollama instance with `llama3.2-vision:11b`
- (Optional) fashn.ai API key for photo try-on

### Backend

**1. Install dependencies**
```bash
cd Backend
pip install -r requirements.txt
```

**2. Start Redis**
```bash
docker run -d --name dressify-redis -p 6379:6379 redis:alpine
```

**3. Create `.env`** in `Backend/`
```env
# Supabase
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_KEY=<anon key>
SUPABASE_SERVICE_KEY=<service role key>
DATABASE_URL=postgresql+asyncpg://<user>:<pass>@db.<project>.supabase.co:5432/postgres

# Auth
GOOGLE_CLIENT_ID=<your Google OAuth client ID>
JWT_SECRET=<random secret>

# AI
OPENAI_API_KEY=sk-...          # or leave empty to use Ollama
OLLAMA_BASE_URL=http://localhost:11434/v1
OLLAMA_VISION_MODEL=llama3.2-vision:11b

# Virtual Try-On (optional)
FASHN_API_KEY=<fashn.ai key>
REPLICATE_API_KEY=<replicate key>

# Redis
REDIS_URL=redis://localhost:6379
```

**4. Run migrations**
```bash
alembic upgrade head
```

**5. Start the API and worker** (two terminals)
```bash
# Terminal 1 — API
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload


# Terminal 2 — ARQ background worker (garment processing, metadata extraction)
python -m arq app.worker.WorkerSettings
```

### Frontend

```bash
cd Frontend
flutter pub get
# Set your API base URL in lib/core/api/api_client.dart
flutter run
```

**Dev bypass** — skip Google Sign-In during local development:
```bash
flutter run --dart-define=BYPASS_AUTH=true
```

## API Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/google` | Exchange Google ID token for JWT |
| GET/DELETE | `/clothing` | List / batch-delete wardrobe items |
| GET/PATCH/DELETE | `/clothing/{id}` | Get / update / delete a single item |
| GET | `/clothing/{id}/fit` | Fit rating for a garment |
| POST | `/upload` | Upload a clothing photo (queues background processing) |
| POST | `/tryon` | AI photo try-on via fashn.ai |
| POST/GET | `/outfits` | Create / list outfits |
| POST | `/outfits/generate` | LLM-generated outfit suggestion |
| GET | `/analytics/wardrobe` | Wardrobe color/style/wear analytics |
| POST | `/feedback` | AI style critique for an outfit |
| GET/POST | `/wear-logs` | Log a wear event |
| GET/PATCH | `/profile` | Body measurements and style preferences |

Full interactive docs available at `http://localhost:8000/docs` when the API is running.
