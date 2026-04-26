# Backend Phase 1 Progress

## Completed
- [x] Create backend directory and file structure
- [x] Configure `pyproject.toml` (uv / poetry deps, ruff, pytest)
- [x] Setup `app/main.py` (FastAPI app factory, CORS, error handlers, health check)
- [x] Setup `app/config.py` (Pydantic settings for environment variables)
- [x] DB & Migrations: Setup Alembic, base models, and `app/db.py`
- [x] Implement Models: `user`, `profile`, `clothing_item`, `outfit`, `ai_feedback`
- [x] Auth: Implement `POST /auth/google`, `get_current_user` dependency, and `GET /me`
- [x] Profile: Implement `PATCH /profile`

- [x] Storage: Implement Supabase upload and signed URL utility in `app/services/storage.py`
- [x] Upload Pipeline: Implement `POST /upload` (rembg + static anchor guesses)
- [x] Clothing CRUD: Implement `GET /clothing`, `GET /clothing/:id`, `DELETE /clothing/:id`
- [x] Outfits CRUD: Implement `POST /outfits`, `GET /outfits`, `DELETE /outfits/:id`
- [x] AI Feedback: Implement `POST /feedback` with OpenAI/Llama 3.2 support
- [x] AI Enhancements: Add `occasion` parsing and full wardrobe context injection for outfit styling
- [x] AI Vision: Implement async `BackgroundTasks` to extract `color`, `pattern`, `style`, and `sub_type` using `llama3.2-vision`
- [x] DB Drivers: Configured connection strings and transitioned to `psycopg` driver for maximum stability
- [x] Auto-Outfit Generation: Implement `POST /outfits/generate`
- [x] Weather Integration: Fetch weather via Open-Meteo for AI styling context
- [x] AI Status Tracking: Add `processing_status` to Clothing Items
- [x] API Security: Add `slowapi` rate limiting to AI endpoints

- [x] Testing: Setup tests structure — `tests/conftest.py`, `test_auth.py`, `test_upload.py`, `test_outfits.py` exist

## To Do
- [ ] Testing: Fill out actual assertions in test files; add CI integration
- [ ] Bug: Fix `POST /outfits/generate` — four bugs (missing `avatar_kind`, `OutfitItem` id column, `model_validate` fails, type mismatch on `items`)
