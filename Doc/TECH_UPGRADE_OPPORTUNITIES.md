# Dressify — Technology Upgrade Opportunities

> Purpose: a shortlist of newer technologies/approaches that could improve Dressify's UX and core features.
> **Caveat:** written from general knowledge, not live research. Before committing to any item,
> verify current model names, licences, pricing and Flutter package versions.
> Effort: S = days, M = 1–2 weeks, L = 2+ weeks.

---

## 1. Try-on quality (the headline feature)

| Idea | Replaces / improves | Why | Effort |
|------|---------------------|-----|--------|
| Newer open VTON models (CatVTON, Leffa, IDM-VTON successors) self-hosted on a serverless GPU | Dependence on fashn.ai only (S5.1.1 RunPod still undone) | Lower per-render cost, no vendor lock-in, can keep fashn.ai as fallback | M |
| General image-editing models (e.g. Gemini image editing) as a second still-try-on provider | Single provider | Often simple to integrate via API; A/B against fashn.ai on quality and cost | S |
| Result caching + progress UI | Silent 90s wait | Perceived speed; already cached 24h server-side, add streaming status to the app | S |
| On-device subject/person segmentation upgrades | ML Kit selfie segmentation | Cleaner arm/hair occlusion edges in the live camera | M |
| Ask for full-body framing guidance via pose landmarks (visibility scores) | Users failing silently | Fewer bad captures; "step back" prompts | S |

## 2. Wardrobe intelligence

| Idea | Replaces / improves | Why | Effort |
|------|---------------------|-----|--------|
| Image embeddings (CLIP/SigLIP-class) stored in Postgres with **pgvector** (Supabase supports it) | Pure LLM metadata + filters | "Find something like this", visual search, duplicate detection, better outfit matching | M |
| Structured-output LLM calls (JSON schema / tool use) for metadata + outfits | Prompt-and-parse | Fewer malformed responses, simpler validation | S |
| Prompt caching + smaller/cheaper model tier for metadata extraction | Per-upload vision cost | Lower cost per garment | S |
| Better background removal (newer matting models) | rembg | Cleaner edges on lace, hair-like fringes, transparent fabrics | M |
| On-device lightweight LLM/vision (ML Kit GenAI-style APIs) for simple tagging | Server round-trip | Instant offline tagging, privacy | L (device support varies) |

## 3. Outfit recommendations

| Idea | Why | Effort |
|------|-----|--------|
| Use `wear_logs` to penalise recent repeats and boost underused items in the prompt | Directly uses data already collected | S |
| Embedding-based compatibility scoring before the LLM (shortlist, then LLM picks) | Cheaper, more consistent suggestions | M |
| Calendar/occasion context (opt-in) | "Meeting at 9, dinner at 8" outfits | M |
| Thumbs up/down on every suggestion feeding Style DNA | Faster learning loop | S |

## 4. App experience and architecture

| Idea | Replaces / improves | Why | Effort |
|------|---------------------|-----|--------|
| Offline-first local cache (e.g. Drift/SQLite or Isar-class DB) | Network-only data path | Wardrobe opens instantly and works offline. Note: conflicts with the "no DB on phone" architecture rule, so limit to a read-through cache | M |
| Push notifications (FCM) for "upload processed", "outfit ready" | Polling | Users can leave the screen; ties into the existing Notification model | M |
| Supabase Realtime for processing status | Polling in `pollUntilComplete` | Instant card updates | S |
| Flutter Impeller renderer + DevTools profiling | Unknown frame times (S6.1/S6.8 undone) | Likely smoother CustomPainter/shader work; measure first | S |
| Fragment shaders (Flutter `FragmentProgram`) for garment lighting/edge blending | CPU-side canvas tricks | GPU-side effects at 30 FPS | M |
| Image CDN / on-the-fly resizing (Supabase image transforms) | Full-size images in grids | Faster wardrobe scrolling, less data | S |
| Crash and performance monitoring (Sentry or Firebase Crashlytics) | Blind to real-device failures | Essential once testers use the app | S |

## 5. Quality and delivery

| Idea | Why | Effort |
|------|-----|--------|
| CI: `flutter analyze` + `pytest` on every push | Backend tests were empty until now | S |
| Backend integration tests with a test DB and mocked AI/Storage | Protect upload/outfit flows | M |
| Flutter golden tests for key screens | Catch visual regressions during refactors | M |
| Split `camera_try_on_screen.dart` (~1,950 lines) and `profile_screen.dart` (~1,080) | Safer, faster UI changes | M |
| Secrets scanning + key rotation (Phase 2.6.1 manual item) | Security | S |

---

## Suggested order

1. Profile on real devices (S6.1/S6.8) and add crash monitoring.
2. Add CI and grow backend tests.
3. Offline read-through cache and Realtime/push for uploads.
4. Wear-log-aware outfit generation, then pgvector embeddings.
5. Second try-on provider and/or self-hosted VTON.

## Open questions

- Is the "no DB/storage SDK on the phone" rule strict? It determines how far offline caching can go.
- What is the monthly budget for try-on renders? It decides self-hosting versus API providers.
