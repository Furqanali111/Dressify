# Dressify Backend — Phase 1 Plan

Phase 1 = Core MVP per `Project_Plan.md`. The frontend is built and waiting on real endpoints. This plan defines the backend in enough detail to start building, with the goal of unblocking the two pain points the frontend has flagged: **real auth** (replace `BYPASS_AUTH=true`) and **real data** (replace `lib/core/mock/mock_data.dart`).

## Stack (locked in `Project_Plan.md`)

- **Python 3.11+** / **FastAPI**
- **Supabase** = managed Postgres + Storage + Auth (one stop)
  - Postgres for `users`, `profiles`, `clothing_items`, `outfits`, `outfit_items`, `ai_feedback`
  - Storage for raw + processed clothing images (and avatar thumbnails later)
  - Auth for Google OAuth verification
- **`supabase-py`** for Auth + Storage helpers
- **`asyncpg`** + **SQLAlchemy 2.x async** for direct Postgres queries
- **`rembg`** for background removal
- **OpenCV** for clothing-type detection + anchor-point estimation
- **LLM** (OpenAI GPT-4o-mini with Ollama Llama 3.2 offline fallback) for styling feedback
- **PyJWT** to mint short-lived backend JWTs
- **Pydantic v2** for request/response models
- **`uvicorn`** for the dev server, **`gunicorn`** behind a reverse proxy for prod

## File structure

```
Backend/
├── pyproject.toml                # uv / poetry deps + ruff + pytest config
├── .env.example                  # documents required vars
├── .env                          # gitignored
├── alembic/                      # schema migrations
│   ├── env.py
│   └── versions/
├── app/
│   ├── main.py                   # FastAPI app factory, CORS, error handlers
│   ├── config.py                 # Settings (pydantic-settings) reading .env
│   ├── deps.py                   # FastAPI dependencies (db session, current user)
│   ├── db.py                     # async engine + session factory
│   ├── security.py               # JWT mint/verify, Supabase Auth client
│   ├── models/                   # SQLAlchemy tables
│   │   ├── user.py
│   │   ├── profile.py
│   │   ├── clothing_item.py
│   │   ├── outfit.py
│   │   └── ai_feedback.py
│   ├── schemas/                  # Pydantic request/response models
│   │   ├── auth.py
│   │   ├── profile.py
│   │   ├── clothing.py
│   │   ├── outfit.py
│   │   └── feedback.py
│   ├── routers/                  # one file per resource
│   │   ├── auth.py               # POST /auth/google
│   │   ├── profile.py            # GET / PATCH /profile
│   │   ├── upload.py             # POST /upload (multipart, streaming progress)
│   │   ├── clothing.py           # GET /clothing, GET /clothing/:id, DELETE /clothing/:id
│   │   ├── outfits.py            # POST /outfits, GET /outfits, DELETE /outfits/:id
│   │   └── feedback.py           # POST /feedback
│   ├── services/                 # business logic — testable, no FastAPI deps
│   │   ├── image_processing.py   # rembg + OpenCV
│   │   ├── anchor_detection.py   # shoulder/chest/waist heuristic
│   │   ├── storage.py            # Supabase Storage upload + signed URLs
│   │   └── ai_feedback.py        # LLM call + fallback
│   └── core/
│       ├── errors.py             # typed exceptions → HTTP responses
│       └── logging.py
└── tests/
    ├── conftest.py               # pytest fixtures (db, client, fake user)
    ├── test_auth.py
    ├── test_upload.py
    └── test_outfits.py
```

## Environment variables (`.env`)

```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...        # server-side only, NEVER ship to client
SUPABASE_JWT_SECRET=...              # for verifying Supabase-issued tokens
DATABASE_URL=postgresql+asyncpg://postgres:...@db.xxx.supabase.co:5432/postgres
GOOGLE_CLIENT_ID=...                 # web client ID — used to verify Google ID tokens
JWT_SECRET=...                       # backend-issued JWT signing key
JWT_ISSUER=dressify-api
JWT_TTL_HOURS=24
OPENAI_API_KEY=...                   # for AI feedback (optional; falls back to Ollama)
OLLAMA_BASE_URL=http://localhost:11434/v1  # local Llama 3.2 fallback
ALLOWED_ORIGINS=http://localhost:3000,exp://...
LOG_LEVEL=info
```

## Database schema

All tables get `id uuid primary key default gen_random_uuid()`, `created_at timestamptz default now()`, `updated_at timestamptz`. Every table that holds user data gets a `user_id uuid references users(id) on delete cascade` and a Row-Level Security policy: `user_id = auth.uid()`.

```sql
-- 1. users — mirrors Supabase auth.users for FK targets
create table users (
  id           uuid primary key,                -- = auth.users.id
  email        text not null unique,
  display_name text,
  avatar_url   text,
  created_at   timestamptz default now()
);

-- 2. profiles — body stats from Profile Setup screen
create table profiles (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null unique references users(id) on delete cascade,
  height_cm  numeric(5, 2),                     -- always stored in cm
  weight_kg  numeric(5, 2),                     -- always stored in kg
  body_type  text check (body_type in ('slim','athletic','average','curvy','plus')),
  avatar_kind text check (avatar_kind in ('slim','athletic','average','curvy','plus')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. clothing_items — one row per uploaded garment
create table clothing_items (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users(id) on delete cascade,
  name            text not null,
  type            text not null
                     check (type in ('top','bottom','dress','jacket','shoes','accessory','other')),
  raw_image_path     text not null,             -- Storage path: clothing-raw/<user>/<id>.jpg
  processed_image_path text,                    -- Storage path: clothing-processed/<user>/<id>.png
  detection_confidence numeric(3,2),            -- 0..1
  anchor_points   jsonb,                        -- {shoulder:{x,y}, chest:{x,y}, waist:{x,y}}
  created_at      timestamptz default now()
);

-- 4. outfits — saved looks
create table outfits (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  name        text not null,
  avatar_kind text not null,                    -- snapshot, doesn't follow profile changes
  created_at  timestamptz default now()
);

-- 5. outfit_items — many-to-many between outfits and clothing_items
create table outfit_items (
  outfit_id        uuid references outfits(id) on delete cascade,
  clothing_item_id uuid references clothing_items(id) on delete cascade,
  position         jsonb,                       -- {x, y, scale, rotation} per-item adjustment
  primary key (outfit_id, clothing_item_id)
);

-- 6. ai_feedback — one row per /feedback call (lets us regenerate without losing history)
create table ai_feedback (
  id          uuid primary key default gen_random_uuid(),
  outfit_id   uuid not null references outfits(id) on delete cascade,
  score       numeric(3,1) not null check (score between 0 and 10),
  verdict     text not null,
  suggestions jsonb not null,                   -- [{category, title, detail}, ...]
  created_at  timestamptz default now()
);

-- RLS — turn on for every user-data table
alter table profiles        enable row level security;
alter table clothing_items  enable row level security;
alter table outfits         enable row level security;
alter table outfit_items    enable row level security;
alter table ai_feedback     enable row level security;

create policy "own rows" on profiles
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
-- repeat for clothing_items, outfits, ai_feedback

create policy "own outfit_items" on outfit_items for all using (
  exists (select 1 from outfits o where o.id = outfit_id and o.user_id = auth.uid())
);
```

## Storage buckets

| Bucket | Purpose | Public? |
|---|---|---|
| `clothing-raw` | originals, before background removal | private |
| `clothing-processed` | transparent PNGs returned to the app | private |
| `outfit-thumbnails` | server-rendered previews for wardrobe outfit cards | private |

All access via signed URLs minted by the backend (TTL ~1h). Frontend never gets bucket URLs directly.

## Auth flow (resolves frontend `BYPASS_AUTH`)

```
[Flutter app]                       [FastAPI backend]                [Supabase]
    │                                       │                            │
    │ google_sign_in.signIn()                                              │
    │ → returns Google ID token                                            │
    │                                                                       │
    │ POST /auth/google                                                     │
    │   { id_token: "..." }                                                 │
    │ ───────────────────────────────────────►                              │
    │                                       │                                │
    │                                       │ verify w/ Google's public keys │
    │                                       │ (id_token signature + aud)     │
    │                                       │                                │
    │                                       │ supabase.auth.sign_in_with_idp │
    │                                       │ ─────────────────────────────► │
    │                                       │ ◄───────────── auth.users row  │
    │                                       │                                │
    │                                       │ upsert into public.users       │
    │                                       │ ─────────────────────────────► │
    │                                       │                                │
    │                                       │ mint backend JWT               │
    │                                       │   { sub: user.id, exp: 24h }   │
    │                                       │                                │
    │ ◄───── { jwt, user, has_profile }      │                                │
    │                                                                        │
    │ store JWT in flutter_secure_storage                                    │
    │ Authorization: Bearer <jwt> on every subsequent call                  │
```

Subsequent requests: `Authorization: Bearer <jwt>` is verified by a `get_current_user` FastAPI dependency that decodes the JWT, loads the user, and exposes it to handlers. RLS is satisfied by passing `user.id` into the SQL session via `set local "request.jwt.claims"` so `auth.uid()` resolves correctly.

The frontend already has [sign_in_screen.dart](Frontend/lib/features/auth/sign_in_screen.dart) wired with a `TODO(auth)` at the right spot — replacing the stubbed `Future.delayed` with the real `google_sign_in` call + this endpoint flips the bypass off.

## Endpoints

All under `/api/v1`. Auth required unless noted.

| Method | Path | Body / Params | Returns | Replaces frontend stub |
|---|---|---|---|---|
| `POST` | `/auth/google` | `{ id_token }` | `{ jwt, user, has_profile }` | sign-in screen |
| `GET`  | `/me` | — | `{ user, profile, avatar_kind }` | splash auth check |
| `PATCH` | `/profile` | `{ height_cm?, weight_kg?, body_type?, avatar_kind? }` | `Profile` | profile setup + avatar selection |
| `POST` | `/upload` | multipart `image`, `name?` | `ClothingItem` (with `processed_url`, `anchor_points`, `detection_confidence`) | upload screen processing flow |
| `GET`  | `/clothing` | `?type=top&limit=&cursor=` | `{ items: ClothingItem[], next_cursor }` | wardrobe (replaces MockData.clothing) |
| `GET`  | `/clothing/:id` | — | `ClothingItem` (with fresh signed URL) | try-on screen |
| `DELETE` | `/clothing/:id` | — | `204` | wardrobe long-press → Delete |
| `POST` | `/outfits` | `{ name, avatar_kind, items: [{clothing_item_id, position}] }` | `Outfit` | try-on Save Outfit |
| `GET` | `/outfits` | — | `Outfit[]` | wardrobe + home recent (replaces MockData.outfits) |
| `DELETE` | `/outfits/:id` | — | `204` | wardrobe long-press → Delete |
| `POST` | `/feedback` | `{ outfit_id }` | `AiFeedback` | AI feedback sheet (initial + regenerate) |

## `POST /upload` — the heavy endpoint

Sequential pipeline inside the request:

1. **Validate** — content type, ≤ 10 MB, has user JWT
2. **Persist raw** — write to `clothing-raw/<user_id>/<uuid>.jpg`
3. **`rembg`** — produce transparent PNG, write to `clothing-processed/<user_id>/<uuid>.png`
4. **OpenCV detection** — clothing type (top/bottom/dress/jacket via simple aspect-ratio + edge heuristic for MVP) + confidence
5. **Anchor estimation** — derive shoulder/chest/waist points from the silhouette bounding box
6. **DB insert** — `clothing_items` row with paths + anchors + confidence
7. **Sign URL** — return processed image as a signed URL the app can render

For MVP we run this synchronously per request — clothing images are small enough. If P95 creeps past 3s (the perf target), wrap in a background task + push the result via a `GET /clothing/:id` poll.

## Frontend fields the backend must return

Backed out from the existing UI:

```python
# /upload response
class ClothingItem(BaseModel):
    id: UUID
    name: str
    type: Literal['top','bottom','dress','jacket','shoes','accessory','other']
    raw_url: HttpUrl                 # signed
    processed_url: HttpUrl           # signed
    anchor_points: dict[str, dict[str, float]]  # {"shoulder":{"x":0.5,"y":0.18}, ...} normalized 0..1
    detection_confidence: float       # 0..1; frontend triggers manual adjust if < 0.7
    created_at: datetime
```

```python
# /feedback response  → drives ai_feedback_sheet.dart
class AiFeedback(BaseModel):
    score: float                     # 0..10, drives the rating arc
    verdict: str                     # short overall line
    suggestions: list[Suggestion]    # exactly 4: color / balance / occasion / accessories

class Suggestion(BaseModel):
    category: Literal['color','balance','occasion','accessories']
    title: str
    detail: str
```

## Build order

1. **Skeleton** — `pyproject.toml`, `app/main.py`, health check, CORS, settings, error handlers
2. **DB + migrations** — Alembic, base models, run against Supabase Postgres
3. **Auth** — `POST /auth/google` + `get_current_user` dep + `GET /me` (this unblocks the frontend `BYPASS_AUTH` cutover)
4. **Profile** — `PATCH /profile` (unblocks profile setup persistence)
5. **Storage helper** — Supabase upload + signed URL utility
6. **Upload pipeline** — `POST /upload` end-to-end with `rembg` only first; defer detection/anchors to a static guess (top with center-of-frame anchors) so the frontend can wire the call. Iterate on detection accuracy after.
7. **Clothing CRUD** — `GET /clothing`, `GET /clothing/:id`, `DELETE` (replaces `MockData.clothing` in the wardrobe)
8. **Outfits CRUD** — `POST`, `GET`, `DELETE` (replaces `MockData.outfits`, unblocks try-on Save)
9. **AI feedback** — `POST /feedback` with Anthropic call + rule-based fallback so the endpoint never errors

After step 3, the frontend can flip `BYPASS_AUTH=false` in `.env`. After step 8, [lib/core/mock/mock_data.dart](Frontend/lib/core/mock/mock_data.dart) can be deleted and replaced by Riverpod providers calling the dio client.

## Testing posture

- **Unit** — pure services (`image_processing`, `ai_feedback`) with frozen sample images
- **Integration** — `httpx.AsyncClient` against the FastAPI app + a Postgres test container; mock Supabase Storage with a fake (uploads to a temp dir)
- **Auth** — verify rejection on missing/invalid/expired JWTs; verify RLS by impersonating user A and trying to read user B's row
- **Smoke** — one e2e test that uploads a fixture jpeg → checks the processed PNG byte count is non-zero → saves an outfit → fetches it back

## Out of scope for Phase 1

- Real-time camera try-on (Phase 2)
- Pose estimation (Phase 2)
- Body sliders / re-fitting (Phase 3)
- Sharing / social (Phase 4)
- 3D rendering (Phase 5)

## Frontend ↔ backend handshake checklist

When each backend endpoint lands, the frontend can flip the corresponding switch:

- [x] `POST /auth/google` ready → frontend `authStateProvider.signInWithGoogle()` wired
- [x] `GET /me` ready → **frontend still calls `GET /profile`; fix `authStateProvider.init()` to use `GET /me` and parse real `User`**
- [x] `PATCH /profile` ready → frontend profile setup + avatar selection call it
- [x] `POST /upload` ready → **frontend still uses `Timer.periodic` mock — wire real multipart upload**
- [x] `GET /clothing` ready → `wardrobeProvider` consumes it
- [x] `GET /outfits` ready (bug fixed: was returning wrong value) → `outfitsProvider` consumes it
- [x] `DELETE /clothing/:id` + `DELETE /outfits/:id` ready → wardrobe long-press delete wired
- [ ] `POST /outfits` ready → **try-on Save Outfit not yet wired on frontend**
- [ ] `POST /feedback` ready → **AI feedback sheet not yet wired on frontend** (still mocked)

Once all are checked, Phase 1 is shippable.
