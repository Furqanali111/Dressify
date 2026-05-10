# Dressify — Snapchat-Quality AR Try-On Plan

> **Goal**: Live camera overlay that feels like Snapchat AR — garment moves with the body,
> arms occlude it naturally, fabric has realistic folds and lighting.
>
> **Architecture decision (locked)**
> - Live Camera Preview → 2D deformable warp pipeline (this doc)
> - Wardrobe Item Card → 2D processed garment image (flat, clean, fast)
> - Avatar View → 2D garment composited onto avatar illustration
> - 3D GLB mesh → **deferred to Future (see bottom of this doc)**
>
> No 3D mesh anywhere in the current build.
> Every commercial try-on app (Snap, Zara, ASOS, Amazon) uses the 2D warp approach
> for real-time. The "3D feeling" comes from occlusion + lighting + fold detail, not mesh.

---

## Why This Architecture

```
Live Camera (this plan)         Wardrobe Card (current)         Future
────────────────────────        ───────────────────────         ──────────────────
2D garment image                2D processed image              3D GLB wardrobe viewer
Deformable warp to body         Tap → detail view               Spin / inspect mesh
Segmentation occlusion          No 3D, no WebView               Avatar dressed in GLB
30 FPS on-device                Instant load, no cache miss     Deferred — see §Future
No GPU backend call             Zero infra dependency
```

The perceived "3D" in Snapchat comes from **correct occlusion + lighting + fold detail**,
not from an actual 3D mesh composited over the camera.

---

## Phase S0 — Remove 3D Mesh from Live Preview & Wardrobe

> Before building anything new, cleanly remove the 3D overlay code that was
> prototyped with TripoSR. This avoids two active systems fighting each other,
> removes a WebView from the critical camera path, and eliminates the
> `android:networkSecurityConfig` dependency we added just to serve the GLB.
>
> The GLB pipeline (backend worker, Supabase bucket, DB columns) stays intact —
> it will be re-enabled when the 3D Wardrobe feature is built in the future.
> Only the Flutter-side render code is removed now.
> Remove the backend code for the 3d mesh as well.

### S0.1 — Camera Try-On Screen

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S0.1.1 | Remove `bool _is3dMode` state field and the "3D Mode" toggle pill widget from the top bar | ⬜ Todo | `camera_try_on_screen.dart` |
| S0.1.2 | Remove `_build3dGarments()` method and the `else if (_is3dMode)` branch in the camera stack builder | ⬜ Todo | `camera_try_on_screen.dart` |
| S0.1.3 | Remove `import` of `garment_mesh_renderer.dart` from camera try-on screen | ⬜ Todo | `camera_try_on_screen.dart` |
| S0.1.4 | Remove `_computeShoulderSpan()` helper (it was only used by the 3D garment positioning logic) | ⬜ Todo | `camera_try_on_screen.dart` |
| S0.1.5 | Verify the camera try-on screen still compiles and all existing 2D warp paths work | ⬜ Todo | Build + device test |

### S0.2 — Wardrobe & Item Detail

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S0.2.1 | Wardrobe item cards: confirm they display the `processedImageUrl` (2D) — no `GarmentMeshRenderer` should be referenced in any wardrobe widget | ⬜ Todo | `Frontend/lib/features/wardrobe/` |
| S0.2.2 | Item detail screen: if it has a "View 3D" or mesh-related button/section, remove it; show the processed image full-screen instead | ⬜ Todo | Item detail screen file |
| S0.2.3 | `GlbCacheService`: keep the class but remove all call sites that aren't in `GarmentMeshRenderer` (it will be re-wired when 3D wardrobe is built) | ⬜ Todo | Codebase search |

### S0.3 — Disable GLB Generation to Save GPU Costs

> The backend worker currently generates a GLB for every uploaded garment.
> With no viewer to display it, this is wasted RunPod spend.
> Pause GLB generation via a feature flag — the code stays, the jobs don't fire.

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S0.3.1 | Add `MESH_GENERATION_ENABLED=false` to `.env` and `app/config.py` settings | ⬜ Todo | `Backend/app/config.py` |
| S0.3.2 | In `upload.py` router: wrap the `trigger_mesh_reconstruction` ARQ enqueue in `if settings.MESH_GENERATION_ENABLED:` — no jobs fire when flag is false | ⬜ Todo | `Backend/app/routers/upload.py` |
| S0.3.3 | Set `MESH_GENERATION_ENABLED=true` in the future when 3D wardrobe is being built | ⬜ Todo | Infrastructure |

### S0.4 — Android Manifest Cleanup (Optional)

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S0.4.1 | The `network_security_config.xml` (localhost cleartext) was added for `model_viewer_plus`. Once the WebView is removed from the camera flow it is no longer needed — remove it and the `android:networkSecurityConfig` attribute from `AndroidManifest.xml` | ⬜ Todo | `android/app/src/main/` |

---

## Quality & Performance Targets

| Metric | Target |
|--------|--------|
| Frame rate (mid-range Android, e.g. Samsung A54) | ≥ 28 FPS |
| Frame rate (flagship, e.g. Pixel 8 / iPhone 15) | 30 FPS locked |
| Warp latency (time to reposition garment per frame) | < 8 ms |
| Segmentation occlusion latency | < 4 ms (reuse existing mask) |
| Style Preview render time (server-side diffusion) | < 6 seconds |
| GLB load time (wardrobe view, cached) | < 0.5 seconds |
| Garment edge quality | Sub-pixel AA, no hard cut |

---

## Pipeline Overview

```
Camera Frame (every ~33ms)
        │
        ├─► Pose Detection (ML Kit, already running)
        │         └─► 33 landmarks → body quad + fit anchors
        │
        ├─► Selfie Segmentation (ML Kit, already running)
        │         └─► person mask → occlusion layer
        │
        ▼
  S1: Precision Warp
        │  Garment image deformed to body quad using TPS
        │  Garment-type specific control points (collar, sleeve, waist, hem)
        ▼
  S2: Segmentation Occlusion
        │  Person mask composited on top → arms/hair naturally in front
        ▼
  S3: Edge Refinement & Shadow
        │  Soft feathered garment edge (no hard cut)
        │  Cast shadow underneath garment
        │  Ambient lighting (L3, already done)
        ▼
  S4: Neural Wrinkle Pass  [optional — quality upgrade]
        │  Pose-conditioned wrinkle map blended onto garment
        ▼
  Final Composite → Camera Preview + Garment + Person foreground
        │
        └─► "Style Preview" button (S5)
                  POST to backend → IDM-VTON → photorealistic still
```

---

## Phase S1 — Precision Quad-Warp

> Current L2 Quad-Warp uses 4 body points (shoulders + hips) as a simple quadrilateral.
> This phase upgrades it to a multi-point deformable mesh with garment-type awareness.
> Still zero ML inference — pure geometry on the CPU, runs in < 2ms per frame.

### Why upgrade from the current L2 quad

The current quad maps the whole garment image onto a 4-point quadrilateral.
This is good for scaling/tilting but the garment corners don't correspond to body parts —
a shirt's collar sits at the neck, not the shoulder, and the sleeves extend past the shoulders.
The upgrade maps **named garment zones** to **named body landmarks**.

### S1.1 — Garment Control Point Schema

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S1.1.1 | Define `GarmentControlPoints` model: `neckUV`, `leftShoulderUV`, `rightShoulderUV`, `leftSleeveUV`, `rightSleeveUV`, `waistLeftUV`, `waistRightUV`, `hemLeftUV`, `hemRightUV` — all in 0–1 UV space | ⬜ Todo | `Frontend/lib/core/models/garment_control_points.dart` (new) |
| S1.1.2 | Per-type defaults: `GarmentType.top` → full UV grid; `GarmentType.dress` → extended hem; `GarmentType.bottom` → waist-to-hem only; `GarmentType.jacket` → collar + full sleeve extension | ⬜ Todo | `Frontend/lib/core/models/garment_control_points.dart` |
| S1.1.3 | Backend: expose `garment_type` in `ClothingItemResponse` (AI extraction already classifies it; just ensure it's serialised) | ⬜ Todo | `Backend/app/schemas/clothing.py` |

### S1.2 — Thin-Plate Spline (TPS) Warper

> TPS maps each garment control point to its corresponding body landmark.
> This produces smooth, physically plausible deformation across the whole garment.

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S1.2.1 | `TpsWarper` class: takes source UV list + target screen `Offset` list; solves TPS coefficients (pure Dart, no native lib needed for ≤ 12 points) | ⬜ Todo | `Frontend/lib/core/utils/tps_warper.dart` (new) |
| S1.2.2 | `TpsWarper.warpMesh(rows, cols)` — generates a dense grid of warped `Offset` points; `rows=20, cols=14` is the default (280 quads, sub-pixel accuracy, ~1ms) | ⬜ Todo | `Frontend/lib/core/utils/tps_warper.dart` |
| S1.2.3 | `_GarmentWarpPainter`: replaces `_CameraOverlayPainter._paintImageOnQuad()`; uses `Canvas.drawVertices` with the TPS-warped mesh and UV `ImageShader` | ⬜ Todo | `camera_try_on_screen.dart` |
| S1.2.4 | Cache TPS coefficients between frames — only recompute when landmark positions change by > 3px (avoids 1ms solve on every frame when the user is still) | ⬜ Todo | `Frontend/lib/core/utils/tps_warper.dart` |
| S1.2.5 | Fallback: when fewer than 4 landmarks visible, fall back to existing L2 quad warp | ⬜ Todo | `camera_try_on_screen.dart` |

### S1.3 — Garment-Type Fit Tuning

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S1.3.1 | `FitProfile` per garment type: shoulder width multiplier, sleeve extension ratio, collar Y offset, waist taper amount — stored as constants, tunable | ⬜ Todo | `Frontend/lib/core/utils/fit_profiles.dart` (new) |
| S1.3.2 | Top/shirt: collar 15% above shoulder midpoint; sleeve tips 25% outside shoulder width | ⬜ Todo | `Frontend/lib/core/utils/fit_profiles.dart` |
| S1.3.3 | Dress: hem mapped to knee landmark (or estimated 2× torso length below waist) | ⬜ Todo | `Frontend/lib/core/utils/fit_profiles.dart` |
| S1.3.4 | Bottom/trousers: waistband anchored to hip landmarks; leg width estimated from hip span × 0.45 per leg | ⬜ Todo | `Frontend/lib/core/utils/fit_profiles.dart` |
| S1.3.5 | Jacket / coat: same as top but collar elevated further + sleeve tips 35% outside shoulder | ⬜ Todo | `Frontend/lib/core/utils/fit_profiles.dart` |

---

## Phase S2 — Segmentation Occlusion

> **The single biggest perceived quality jump.**
> Without occlusion, the garment floats on top of the person's arms — immediately fake.
> With occlusion, arms naturally pass in front of the garment at 30 FPS.
>
> We already run selfie segmentation every frame for background blur elsewhere.
> This phase uses that existing mask — zero extra ML inference cost.

### S2.1 — Compositing Layer Order

Current (wrong):
```
[Camera] → [Garment overlay] → display
```

Target (correct):
```
[Camera background]
  + [Garment layer]         ← drawn below person
  + [Person foreground]     ← arms / hair / hands on top
= final frame
```

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S2.1.1 | In `_onFrame`, after segmentation result arrives, extract person-foreground mask as `Uint8List` (from the `InputImage` confidence buffer) | ⬜ Todo | `camera_try_on_screen.dart` |
| S2.1.2 | Convert segmentation mask to `ui.Image` (RGBA — white where person, transparent where background); cache as `_personMaskImage`; update only when mask changes by > 5% (every 3rd frame is sufficient) | ⬜ Todo | `camera_try_on_screen.dart` |
| S2.1.3 | `_GarmentWarpPainter`: draw order: (1) warped garment, (2) `_personMaskImage` composited with `BlendMode.srcOver` — this paints the person's skin/clothing on top of the garment in the overlap region | ⬜ Todo | `camera_try_on_screen.dart` |
| S2.1.4 | Mask feathering: apply `MaskFilter.blur(BlurStyle.normal, 4.0)` to the person mask edge to avoid a hard cutout seam at the garment/arm boundary | ⬜ Todo | `camera_try_on_screen.dart` |
| S2.1.5 | Only apply occlusion for body parts that can realistically be in front of the garment: forearms, hands, hair, chin/neck — exclude torso (it should be behind the garment). Achieve this by masking only the region outside the garment bounding quad before compositing | ⬜ Todo | `camera_try_on_screen.dart` |
| S2.1.6 | Performance gate: skip mask image conversion if the frame delta is < 100ms (segmentation runs at ~10Hz; warp runs at ~30Hz — reuse last good mask between segmentation updates) | ⬜ Todo | `camera_try_on_screen.dart` |

### S2.2 — Garment Edge Quality

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S2.2.1 | Remove background from garment image during upload pre-processing (already done by rembg); verify alpha channel is clean with a threshold pass — pixels with alpha < 10 → fully transparent, alpha > 240 → fully opaque, in-between → soft edge | ⬜ Todo | `Backend/app/services/image_processing.py` |
| S2.2.2 | On-device: apply `ImageFilter` to garment texture before `ImageShader` to ensure sub-pixel smooth edges (use `FilterQuality.high` on the `Paint` object) | ⬜ Todo | `camera_try_on_screen.dart` |
| S2.2.3 | Edge shadow: draw a 6px feathered dark stroke along the garment silhouette at 15% opacity — adds depth, makes it look "on" the body not "floating" | ⬜ Todo | `camera_try_on_screen.dart` |

---

## Phase S3 — Depth Cues & Lighting Polish

> Small additions that push the overlay from "good overlay" to "looks physically there."
> All run on-device, < 1ms each.

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S3.1 | Body shadow: cast a soft elliptical shadow from the garment down onto the estimated floor plane (derived from foot landmarks or bottom of frame) | ⬜ Todo | `camera_try_on_screen.dart` |
| S3.2 | Neck shadow: render a small gradient shadow at the collar/neck junction — garment appears to sit on the shoulders, not hover | ⬜ Todo | `camera_try_on_screen.dart` |
| S3.3 | Ambient lighting (L3 already done): verify the luma-to-brightness formula maps correctly when wearing dark vs light garments | ⬜ Todo | Device test |
| S3.4 | Color temperature shift: sample R/G/B channels (not just luma) from the shoulder region; apply a `ColorFilter.matrix` that shifts garment hue toward the scene's colour temperature | ⬜ Todo | `camera_try_on_screen.dart` |
| S3.5 | Distance scale damping: when `_manualScale < 0.75` (user far away), reduce shadow opacity and edge blur proportionally — depth reads more naturally | ⬜ Todo | `camera_try_on_screen.dart` |

---

## Phase S4 — Neural Wrinkle & Fold Detail

> This phase is a quality upgrade, not a prerequisite. S1+S2+S3 already look great.
> Wrinkle detail is what takes it from "good" to "Snapchat-level."
>
> **Approach**: Pre-computed pose-conditioned wrinkle maps — NOT a real-time neural network.
> A lightweight model is run offline to generate a wrinkle overlay image for a discrete set of
> poses (arms down, arms at 45°, arms at 90°, leaning left, leaning right).
> At runtime, the correct wrinkle map is selected and alpha-blended based on current pose.
> This is how Snap's Lens Studio fashion lenses actually work — pre-baked, not live inference.

### S4.1 — Offline Wrinkle Map Generation

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S4.1.1 | Define 8 canonical poses by elbow and shoulder angles: `arms_down`, `arms_45`, `arms_90`, `lean_left_15`, `lean_right_15`, `seated`, `one_arm_raised`, `crossed_arms` | ⬜ Todo | `Doc/wrinkle_pose_catalog.md` (new) |
| S4.1.2 | For each garment at upload time, generate 8 wrinkle maps using a cloth simulation (Blender Python script or a cloth physics API) — stored alongside the GLB in Supabase | ⬜ Todo | `Backend/app/services/wrinkle_generation.py` (new) |
| S4.1.3 | Wrinkle maps are greyscale PNGs (128×192px, ~8KB each); 8 maps per garment = ~64KB extra storage | ⬜ Todo | `Backend/app/services/wrinkle_generation.py` |
| S4.1.4 | Backend: add `wrinkle_maps` JSON field to `ClothingItemResponse` — array of `{pose: string, url: string}` | ⬜ Todo | `Backend/app/schemas/clothing.py` |

### S4.2 — On-Device Wrinkle Compositing

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S4.2.1 | `WrinkleCacheService`: downloads and caches wrinkle maps alongside GLB; same evict/clearAll lifecycle | ⬜ Todo | `Frontend/lib/core/services/wrinkle_cache_service.dart` (new) |
| S4.2.2 | `PoseClassifier`: maps current landmark angles (shoulder-elbow, torso lean) to nearest canonical pose label | ⬜ Todo | `Frontend/lib/core/utils/pose_classifier.dart` (new) |
| S4.2.3 | In `_GarmentWarpPainter`: after drawing the warped garment, draw the matched wrinkle map using `BlendMode.multiply` at 35% opacity — adds shadow detail without changing garment color | ⬜ Todo | `camera_try_on_screen.dart` |
| S4.2.4 | Crossfade between wrinkle maps when pose class changes (0.3s lerp on opacity) — prevents a hard snap | ⬜ Todo | `camera_try_on_screen.dart` |
| S4.2.5 | Wrinkle map is warped through the same TPS transform as the garment so folds follow the deformation correctly | ⬜ Todo | `camera_try_on_screen.dart` |

---

## Phase S5 — "Style Preview" Diffusion Mode

> A separate non-real-time mode: user taps "Style Preview", waits 4–6 seconds,
> gets a photorealistic still image of themselves wearing the outfit.
> This is how Zara, H&M, and Amazon implement the "high quality" try-on —
> it is not the live camera feed, it is a one-shot server render.
>
> **Model**: IDM-VTON (state of the art, open source) or CatVTON (faster, slightly lower quality).
> **Infrastructure**: RunPod A100 endpoint (same RunPod account as TripoSR; different serverless function).

### S5.1 — Backend: Diffusion Try-On Endpoint

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S5.1.1 | Deploy IDM-VTON or CatVTON as a RunPod serverless handler; input: `{person_image_base64, garment_image_base64, garment_description}`; output: `{result_image_base64}` | ⬜ Todo | RunPod deployment |
| S5.1.2 | `POST /try-on/preview` FastAPI endpoint: accepts `person_image` (multipart), `clothing_item_id`; downloads garment from Supabase; sends both to RunPod; returns result image | ⬜ Todo | `Backend/app/routers/tryon.py` (new) |
| S5.1.3 | Garment description comes from the AI metadata already extracted at upload (`category`, `color`, `style`) — passed to IDM-VTON's text conditioning for better accuracy | ⬜ Todo | `Backend/app/routers/tryon.py` |
| S5.1.4 | Person image is a snapshot taken from the camera feed — captured at 1080×1440 (portrait); center-crop + resize to 768×1024 before sending | ⬜ Todo | `Backend/app/routers/tryon.py` |
| S5.1.5 | Result image cached in Supabase `tryon-previews` bucket for 24 hours; if same person+garment combo requested again within 24h, return cached result (avoid re-running $0.05 inference) | ⬜ Todo | `Backend/app/routers/tryon.py` |
| S5.1.6 | Timeout: 30s max; if RunPod cold start + inference exceeds 30s return 504 and client shows "Try again" | ⬜ Todo | `Backend/app/routers/tryon.py` |

### S5.2 — Frontend: Style Preview UI

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S5.2.1 | "Style Preview" floating button in camera try-on screen — shown only when ≥ 1 garment is selected | ⬜ Todo | `camera_try_on_screen.dart` |
| S5.2.2 | On tap: (1) capture a still frame from the camera feed, (2) show a bottom sheet with progress indicator + "Generating photorealistic preview…" text | ⬜ Todo | `camera_try_on_screen.dart` |
| S5.2.3 | POST to `/try-on/preview` with captured frame + selected garment IDs; poll or await response | ⬜ Todo | `Frontend/lib/core/api/api_client.dart` |
| S5.2.4 | Show result in a fullscreen image viewer with a save-to-gallery button and a share button | ⬜ Todo | `Frontend/lib/features/camera_try_on/style_preview_result_screen.dart` (new) |
| S5.2.5 | Error state: "Our AI stylists are busy — try again in a moment" with retry button | ⬜ Todo | `Frontend/lib/features/camera_try_on/style_preview_result_screen.dart` |
| S5.2.6 | Rate limit: max 3 Style Previews per user per day on free tier; unlimited on premium | ⬜ Todo | `Backend/app/routers/tryon.py` |

---

## Phase S6 — Performance & Frame Rate

> All the above must hit ≥ 28 FPS on a Samsung A-series (Snapdragon 778G class).
> This phase profiles, optimises, and locks frame rate.

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S6.1 | Profile baseline with Flutter DevTools timeline; identify any > 16ms frames in the paint pipeline | ⬜ Todo | DevTools |
| S6.2 | Move TPS coefficient solve to an `Isolate` — only fires when landmarks shift; result posted back to main thread | ⬜ Todo | `Frontend/lib/core/utils/tps_warper.dart` |
| S6.3 | Move segmentation mask conversion (`Uint8List` → `ui.Image`) to a background `Isolate`; main thread receives a ready `ui.Image` handle | ⬜ Todo | `camera_try_on_screen.dart` |
| S6.4 | Use `RepaintBoundary` around the garment layer and a separate one around the person foreground layer — Flutter only repaints the changed layer each frame | ⬜ Todo | `camera_try_on_screen.dart` |
| S6.5 | Pre-decode garment `ui.Image` into GPU texture once on selection; do not re-decode every paint call | ⬜ Todo | `camera_try_on_screen.dart` |
| S6.6 | Wrinkle map: pre-blit onto garment texture at classification time (not every frame) — only reblit on pose class change | ⬜ Todo | `camera_try_on_screen.dart` |
| S6.7 | Frame rate lock: if device reports < 60Hz display, skip the edge shadow and colour temperature passes (S3.4) to preserve frame budget | ⬜ Todo | `camera_try_on_screen.dart` |
| S6.8 | Device testing matrix: Samsung A54, Pixel 7, iPhone 13 mini, mid-range Xiaomi — all must hit ≥ 28 FPS | ⬜ Todo | Device test |

---

## Technology Reference

### What Each Layer Uses

| Layer | Technology | Runs on | Cost |
|-------|-----------|---------|------|
| Pose landmarks | ML Kit Pose Detection | On-device (CPU/GPU) | Free |
| Body segmentation | ML Kit Selfie Segmentation | On-device (GPU) | Free |
| Garment deformation | TPS warp + Canvas.drawVertices | On-device (CPU, < 2ms) | Free |
| Occlusion | Segmentation mask compositing | On-device (GPU, < 1ms) | Free |
| Wrinkle maps | Pre-baked PNG, blended at runtime | On-device (GPU, < 1ms) | $0/garment after generation |
| Wrinkle generation | Blender cloth sim or cloth API | Backend, one-time at upload | ~$0.01/garment |
| Style Preview render | IDM-VTON / CatVTON on A100 | RunPod serverless | ~$0.05–0.10/render |
| 3D GLB (Future F1) | InstantMesh / GarmentDreamer | RunPod serverless (paused) | ~$0.02–0.04/garment |

### Model Decision: IDM-VTON vs CatVTON

| | IDM-VTON | CatVTON |
|---|---|---|
| Quality | Best available (ICCV 2024) | Slightly lower |
| Speed on A100 | ~4–6s | ~2–3s |
| VRAM | 24 GB | 16 GB |
| Open source | Yes (MIT) | Yes (MIT) |
| GitHub | `yisol/IDM-VTON` | `zheng-chong/CatVTON` |
| **Recommendation** | Use for Style Preview | Use if A100 cost is a concern |

---

## Implementation Order

```
S0 (Cleanup — remove 3D from camera + wardrobe, disable GLB jobs)
  │  ← do this first, clears the field for the new system
  ▼
S1 (Precision Warp)           ← foundation for everything
  │
  ▼
S2 (Occlusion)                ← biggest single quality jump
  │
  ▼
S3 (Depth Cues)               ← 3–4 days, completes the "looks real" baseline
  │
  ▼
S6 (Performance)              ← lock frame rate before adding more layers
  │
  ▼
S5 (Style Preview)            ← standalone backend feature, parallelisable with S4
  │
S4 (Wrinkle Maps)             ← quality upgrade, last (needs wrinkle gen infra)
```

---

## Progress Tracking

| Phase | Items | Done | Status |
|-------|-------|------|--------|
| S0.1 Remove 3D from camera try-on | 5 | 0 | ⬜ Todo |
| S0.2 Wardrobe 2D cleanup | 3 | 0 | ⬜ Todo |
| S0.3 Disable GLB generation | 3 | 0 | ⬜ Todo |
| S0.4 Manifest cleanup | 1 | 0 | ⬜ Todo |
| S1.1 Garment Control Points | 3 | 0 | ⬜ Todo |
| S1.2 TPS Warper | 5 | 0 | ⬜ Todo |
| S1.3 Fit Tuning | 5 | 0 | ⬜ Todo |
| S2.1 Occlusion Compositing | 6 | 0 | ⬜ Todo |
| S2.2 Edge Quality | 3 | 0 | ⬜ Todo |
| S3 Depth Cues & Lighting | 5 | 0 | ⬜ Todo |
| S4.1 Wrinkle Map Generation | 4 | 0 | ⬜ Todo |
| S4.2 On-Device Compositing | 5 | 0 | ⬜ Todo |
| S5.1 Diffusion Backend | 6 | 0 | ⬜ Todo |
| S5.2 Style Preview UI | 6 | 0 | ⬜ Todo |
| S6 Performance | 8 | 0 | ⬜ Todo |
| **Total** | **68** | **0** | ⬜ Not started |

---

## What "Done" Looks Like

**After S1+S2** (2–3 weeks): The garment warps to the body when the user moves,
and their arms naturally pass in front of it. This is indistinguishable from
most commercial try-on apps at first glance.

**After S1+S2+S3** (3–4 weeks total): The garment looks physically present —
shadow underneath, edges soft, colour matches room lighting. This is Snapchat level
for standard use cases.

**After S4** (+2 weeks): Fabric folds and creases appear as the user moves their arms.
This is above most commercial apps; only high-budget Snap lenses do this well.

**After S5** (parallel, 2–3 weeks): "Style Preview" gives a photorealistic magazine-quality
still of the user in the outfit. This is the hero marketing feature — shareable, impressive.

---

## Future — 3D Wardrobe & Avatar View

> These features are deliberately deferred. The infrastructure (GLB pipeline, Supabase bucket,
> DB columns, GlbCacheService, GarmentMeshRenderer) is already built and waiting.
> Re-enable when the 2D live preview is solid and the team has bandwidth.

### F1 — 3D Wardrobe Item Viewer

**What**: Tapping a wardrobe item opens a fullscreen 3D viewer where the user can spin,
zoom, and inspect the garment mesh. Think of it like a product page on a fashion e-commerce
site — not real-time, just a nice way to see the garment in 3D before selecting it.

**Why deferred**: The GLB quality from TripoSR is currently blobby (see screenshots).
Re-enable this after upgrading the reconstruction model to InstantMesh or GarmentDreamer,
which produce mesh quality good enough to show to users.

**What needs to happen to re-enable**:
- Set `MESH_GENERATION_ENABLED=true` in backend config
- Add "View 3D" button back to item detail screen
- Wire `GarmentMeshRenderer` into item detail screen (widget is already built)
- Upgrade reconstruction model: swap TripoSR → InstantMesh on RunPod (better mesh for clothing)
- Consider GarmentDreamer (2024, clothing-specific) for even higher quality

**Estimated effort when ready**: 1 week (model upgrade + UI re-wiring)

**Mesh model upgrade path**:
| Stage | Model | Mesh quality | VRAM | Cost/garment |
|-------|-------|-------------|------|-------------|
| Current (paused) | TripoSR | Blobby blob | 4 GB | ~$0.01 |
| Next | InstantMesh | Cleaner, multi-view | 16 GB | ~$0.02 |
| Best | GarmentDreamer | Cloth-topology mesh | 24 GB | ~$0.04 |

---

### F2 — 3D Avatar Dress-Up View

**What**: The user's selected avatar (from the avatar selection screen) is shown as a 3D model.
Selected wardrobe items are placed onto the avatar as 3D GLB meshes.
The avatar can be rotated. Think of it as a virtual mannequin dressed in the user's wardrobe.

**Why deferred**: Requires:
1. Rigged 3D avatar models (not the current 2D illustration avatars)
2. A garment-to-avatar fitting system (draping GLB mesh onto avatar skeleton)
3. GLB mesh quality good enough to look presentable on a rigged figure

This is a significant engineering effort and only makes sense after GLB quality is improved (F1).

**Estimated effort when ready**: 4–6 weeks (new avatar assets + skeleton binding + fitting system)

**Technology options when building**:
- Avatar rigs: Ready Player Me (free tier, auto-generates from selfie), Mixamo, custom SMPL-X
- Garment fitting: Neural garment draping (GarmentDreamer output is already cloth-topology)
- Renderer: Keep `model_viewer_plus` — it supports multi-mesh scenes

---

### F3 — Real-Time 3D Cloth Simulation (Research-Level, Not a Near-Term Target)

**What**: Full SMPL-X body mesh estimation from camera + garments simulated as 3D cloth
draping over the body in real-time with GPU cloth physics (stiffness, gravity, collision).

**Important clarification — what Snapchat actually does**:
Snap's premium brand lenses (Gucci, Dior) that use this approach receive hand-crafted 3D
garment files from the brand's own 3D artists — not auto-generated from photos.
A Gucci 3D artist spends hours building a cloth-topology mesh with proper UV maps and
material parameters. Snap's system then simulates that hand-made asset on the body.

**Why this doesn't apply to Dressify's core proposition**:
Dressify's value is "upload a photo of any garment you own → try it on."
No current AI model (TripoSR, InstantMesh, GarmentDreamer) produces a 3D asset with the
cloth topology quality needed for real-time simulation from a single phone photo.
This gap is a fundamental research problem, not an engineering one.

**What we're already building (S1–S3) IS Snap Tier 1** — the 2D warp approach that powers
the vast majority of Snap fashion lenses. That is the correct and achievable target for Dressify.

**If this ever becomes viable**: Requires breakthroughs in single-image cloth reconstruction
that don't exist yet. Monitor GarmentDreamer and follow-on work. Not on any active roadmap.

---

### Decision Trigger for F1

Re-open F1 when all of the following are true:
- [ ] S1 + S2 + S3 are complete and 28 FPS is confirmed on mid-range Android
- [ ] InstantMesh is deployed on RunPod and producing visibly better meshes than TripoSR
- [ ] At least 500 active users (GLB generation cost becomes worth the investment)
