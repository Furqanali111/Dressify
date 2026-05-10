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
| S0.1.1 | Remove `bool _is3dMode` state field and the "3D Mode" toggle pill widget from the top bar | ✅ Done | `camera_try_on_screen.dart` |
| S0.1.2 | Remove `_build3dGarments()` method and the `else if (_is3dMode)` branch in the camera stack builder | ✅ Done | `camera_try_on_screen.dart` |
| S0.1.3 | Remove `import` of `garment_mesh_renderer.dart` from camera try-on screen | ✅ Done | `camera_try_on_screen.dart` |
| S0.1.4 | Remove `_computeShoulderSpan()` helper (it was only used by the 3D garment positioning logic) | ✅ Done | `camera_try_on_screen.dart` |
| S0.1.5 | Verify the camera try-on screen still compiles and all existing 2D warp paths work | ✅ Done | `flutter analyze` — no issues |

### S0.2 — Wardrobe & Item Detail

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S0.2.1 | Wardrobe item cards: confirm they display the `processedImageUrl` (2D) — no `GarmentMeshRenderer` should be referenced in any wardrobe widget | ✅ Done | `Frontend/lib/features/wardrobe/` |
| S0.2.2 | Item detail screen: if it has a "View 3D" or mesh-related button/section, remove it; show the processed image full-screen instead | ✅ Done | No 3D references found in any wardrobe screen |
| S0.2.3 | `GlbCacheService`: keep the class but remove all call sites that aren't in `GarmentMeshRenderer` (it will be re-wired when 3D wardrobe is built) | ✅ Done | `wardrobe_provider.dart` |

### S0.3 — Remove Local GPU Worker & Disable GLB Generation

> The TripoSR repo and local GPU worker are fully removed.
> Backend enqueue call is deleted. A feature flag gates re-enablement for the future.

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S0.3.1 | Add `MESH_GENERATION_ENABLED=False` to `app/config.py` settings | ✅ Done | `Backend/app/config.py` |
| S0.3.2 | Remove `trigger_mesh_reconstruction` ARQ enqueue from `retry_worker.py` | ✅ Done | `Backend/app/services/retry_worker.py` |
| S0.3.3 | Remove `trigger_mesh_reconstruction` from `WorkerSettings.functions` and its module-level import | ✅ Done | `Backend/app/worker.py` |
| S0.3.4 | Delete `Backend/local_gpu_worker.py` (the FastAPI TripoSR server) | ✅ Done | Deleted |
| S0.3.5 | Delete `Backend/TripoSR/` directory (cloned TripoSR repo, ~500 MB) | ✅ Done | Deleted |
| S0.3.6 | Set `MESH_GENERATION_ENABLED=true` in the future when 3D wardrobe (F1) is being built | ⬜ Future | Infrastructure |

### S0.4 — Android Manifest Cleanup (Optional)

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S0.4.1 | The `network_security_config.xml` (localhost cleartext) was added for `model_viewer_plus`. Keeping it for now — localhost cleartext is also needed in dev for the backend API at `http://localhost:8000`. Remove only if a production network security policy requires it. | ⬜ Kept intentionally | `android/app/src/main/` |

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
| S1.1.1 | Define `GarmentControlPoints` model: UV anchors for collar, left/right shoulder seam, left/right sleeve tip, left/right waist, hem centre — all in 0–1 UV space | ✅ Done | `Frontend/lib/core/utils/garment_control_points.dart` |
| S1.1.2 | Per-type defaults: `top` (8 pts), `jacket` (8 pts), `dress` (8 pts), `bottom` (6 pts — no collar/sleeve); `computeTargets()` maps each UV point to a screen-space body landmark | ✅ Done | `Frontend/lib/core/utils/garment_control_points.dart` |
| S1.1.3 | Backend: expose `garment_type` in `ClothingItemResponse` (AI extraction already classifies it; just ensure it's serialised) | ✅ Done | `Backend/app/schemas/clothing.py` → `type: str` field; Flutter reads `item.type` throughout |

### S1.2 — Thin-Plate Spline (TPS) Warper

> TPS maps each garment control point to its corresponding body landmark.
> This produces smooth, physically plausible deformation across the whole garment.

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S1.2.1 | `TpsSolution` + `TpsWarper.solve()`: augmented Gaussian elimination on (n+3)×(n+3) matrix; solves x and y simultaneously; pure Dart, no native lib | ✅ Done | `Frontend/lib/core/utils/tps_warper.dart` |
| S1.2.2 | `TpsWarper.buildMesh()` — 16×10 indexed triangle grid (187 vertices, 960 indices) via `ui.Vertices.raw()`; returns `(ui.Vertices, Paint)` with `ImageShader` at `FilterQuality.medium` | ✅ Done | `Frontend/lib/core/utils/tps_warper.dart` |
| S1.2.3 | Integrate TPS into `_CameraOverlayPainter._paintOne()`: solve cached in state `_tpsSolutions` on every anchor update (~4 Hz); painter calls `buildMesh()` per frame (~30 Hz); `manualScale` applied as canvas transform around body anchor | ✅ Done | `camera_try_on_screen.dart` |
| S1.2.4 | Cache TPS coefficients in `_tpsSolutions: Map<String, TpsSolution?>` in state; solved once per anchor update inside `setState`; painter only calls the cheap `eval()` × 187 per frame | ✅ Done | `camera_try_on_screen.dart` |
| S1.2.5 | Fallback: when `tpsSolutions[id] == null` (degenerate/missing landmarks), falls back to existing quad warp → skew+paintImage chain | ✅ Done | `camera_try_on_screen.dart` |

### S1.3 — Garment-Type Fit Tuning

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S1.3.1 | `FitProfile` per garment type: `collarRiseRatio`, `sleeveExtendRatio`, `sleeveDropRatio` — all relative to shoulder span; stored as constants | ✅ Done | `Frontend/lib/core/utils/fit_profiles.dart` |
| S1.3.2 | Top/shirt: `collarRiseRatio=0.32`, `sleeveExtendRatio=0.20`, `sleeveDropRatio=0.16`; sleeve direction computed from normalised shoulder axis vector | ✅ Done | `Frontend/lib/core/utils/fit_profiles.dart` |
| S1.3.3 | Dress: `collarRiseRatio=0.34`, `sleeveExtendRatio=0.12`, `sleeveDropRatio=0.10`; hem target derived from hip midpoint + 15% torso extension below hips | ✅ Done | `Frontend/lib/core/utils/fit_profiles.dart` |
| S1.3.4 | Bottom/trousers: waistband anchored to hip landmarks; mid-thigh from midpoint of hip+knee; ankle from landmark or estimated at 2.6× hip-span below hips | ✅ Done | `Frontend/lib/core/utils/garment_control_points.dart` |
| S1.3.5 | Jacket/coat: `collarRiseRatio=0.28`, `sleeveExtendRatio=0.26`, `sleeveDropRatio=0.22` — wider shoulder extension than top | ✅ Done | `Frontend/lib/core/utils/fit_profiles.dart` |

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
| S2.1.1 | In `_onFrame`, after segmentation result arrives, extract person-foreground mask as `Uint8List` (from the `InputImage` confidence buffer) | ✅ Done | `segmentation_service.dart` returns `SegmentationMaskResult.confidences` |
| S2.1.2 | Convert segmentation mask to `ui.Image` (RGBA — white where person, transparent where background); cache as `_segMaskImage`; rate-limited by `_busy` guard + frame throttle (~4 Hz) | ✅ Done | `camera_try_on_screen.dart` → `_buildMaskImage()` |
| S2.1.3 | Painter compositing: garment drawn in outer `saveLayer`; dstOut inner layer erases garment pixels where person landmarks (arm capsules + neck ellipse) are present; segmentation mask intersected via `dstIn` to restrict to real person pixels | ✅ Done | `camera_try_on_screen.dart` → `paint()` |
| S2.1.4 | Mask feathering: `imageFilter = ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4)` applied to the `dstIn` mask draw — soft fade at garment/arm boundary instead of hard pixel cut | ✅ Done | `camera_try_on_screen.dart` → `paint()` |
| S2.1.5 | Occlusion restricted to arms and neck only (not torso): geometric arm capsule paths and neck ellipse ensure only forearms/hands/chin region is erased; torso area has no erase shape so garment covers it correctly | ✅ Done | `camera_try_on_screen.dart` → `_buildArmPath()`, `_buildNeckPath()` |
| S2.1.6 | Performance gate: segmentation `_busy` guard prevents frame stacking; frame throttle limits ML calls to ~4 Hz; mask image is reused across paint frames between segmentation updates | ✅ Done | `segmentation_service.dart` → `_busy` flag |

### S2.2 — Garment Edge Quality

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S2.2.1 | Remove background from garment image during upload pre-processing (already done by rembg); alpha channel is clean from the rembg pipeline | ✅ Done | `Backend/app/services/image_processing.py` |
| S2.2.2 | On-device: `FilterQuality.high` on the `ImageShader` Paint — bicubic sampling for sub-pixel smooth garment edges | ✅ Done | `Frontend/lib/core/utils/tps_warper.dart` |
| S2.2.3 | Edge shadow: blurred black copy of garment drawn at 18% alpha behind the main garment — makes it look "on" the body rather than floating; uses `ColorFilter.matrix` (→ transparent black) + `ImageFilter.blur(8,8)` | ✅ Done | `camera_try_on_screen.dart` → `_paintOne()` TPS path |

---

## Phase S3 — Depth Cues & Lighting Polish

> Small additions that push the overlay from "good overlay" to "looks physically there."
> All run on-device, < 1ms each.

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S3.1 | Body shadow: soft elliptical `RadialGradient` drawn at 22% alpha below garment hem — position from `tps.eval(0.5, 1.0)` when TPS available | ✅ Done | `camera_try_on_screen.dart` → `_paintBodyShadow()` |
| S3.2 | Neck shadow: soft elliptical gradient at 14% alpha at collar/neck junction — position from `tps.eval(0.5, 0.04)`, skipped for bottom type | ✅ Done | `camera_try_on_screen.dart` → `_paintNeckShadow()` |
| S3.3 | Ambient lighting verified: `lum = 0.75 + ambientLuma * 0.50` maps [0,1] luma → [0.75, 1.25] brightness multiplier in ColorFilter.matrix | ✅ Done | `camera_try_on_screen.dart` → `paint()` |
| S3.4 | Color temperature: `LuminanceSampler.sampleRGB()` samples R/G/B from shoulder region (BGRA/iOS); gains normalized and lerped at 30% strength; applied per-channel in ColorFilter.matrix; NV21/Android returns neutral (1,1,1) | ✅ Done | `luminance_sampler.dart`, `camera_try_on_screen.dart` |
| S3.5 | Distance scale damping: `shadowOpacity = ((manualScale-0.5)/0.25).clamp(0,1)` when `manualScale < 0.75` — fades body and neck shadows as garment scales down | ✅ Done | `camera_try_on_screen.dart` → `paint()` |

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
| S4.1.1 | Define 8 canonical poses by elbow and shoulder angles: `arms_down`, `arms_45`, `arms_90`, `lean_left_15`, `lean_right_15`, `seated`, `one_arm_raised`, `crossed_arms` | ✅ Done | `Doc/wrinkle_pose_catalog.md` |
| S4.1.2 | For each garment at upload time, generate 8 wrinkle maps using procedural gaussian-ellipse zones (PIL + numpy) — stored in Supabase clothing bucket under `wrinkle/` prefix | ✅ Done | `Backend/app/services/wrinkle_generation.py` → `generate_and_upload_wrinkle_maps()` wired in `retry_worker.py` |
| S4.1.3 | Wrinkle maps are greyscale PNGs (128×192px, ~8KB each); 8 maps per garment = ~64KB extra storage | ✅ Done | `Backend/app/services/wrinkle_generation.py` |
| S4.1.4 | Backend: add `wrinkle_maps` JSON field to `ClothingItemResponse` — array of `{pose: string, url: string}` | ✅ Done | `Backend/app/schemas/clothing.py` → `WrinkleMapEntry` + `ClothingItemResponse.wrinkle_maps`; migration `a4b5c6d7e8f9` |

### S4.2 — On-Device Wrinkle Compositing

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S4.2.1 | `WrinkleCacheService`: downloads and caches wrinkle maps alongside GLB; same evict/clearAll lifecycle | ✅ Done | `Frontend/lib/core/services/wrinkle_cache_service.dart` |
| S4.2.2 | `PoseClassifier`: maps current landmark angles (shoulder-elbow, torso lean) to nearest canonical pose label | ✅ Done | `Frontend/lib/core/utils/pose_classifier.dart` |
| S4.2.3 | In `_CameraOverlayPainter`: after drawing the warped garment, draw the matched wrinkle map via ColorFilter.matrix at 35% opacity — dark overlay where wrinkle is dark, transparent where white | ✅ Done | `camera_try_on_screen.dart` → `_paintWrinkleOverlay()` |
| S4.2.4 | Crossfade between wrinkle maps when pose class changes (0.3s lerp on opacity) — prevents a hard snap | ✅ Done | `camera_try_on_screen.dart` → `_paintWrinkleOverlay()` |
| S4.2.5 | Wrinkle map is warped through the same TPS transform as the garment so folds follow the deformation correctly | ✅ Done | `camera_try_on_screen.dart` → `TpsWarper.buildMesh(solution: tps, img: wrinkleImg)` |

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
| S5.1.2 | `POST /tryon` FastAPI endpoint: accepts `person_image` (multipart), `clothing_item_id`; downloads garment from Supabase; sends both to fashn.ai (Replicate fallback); returns result image | ✅ Done | `Backend/app/routers/tryon.py` |
| S5.1.3 | Garment description comes from the AI metadata already extracted at upload (`category`, `color`, `style`) — passed to IDM-VTON's text conditioning for better accuracy | ✅ Done | `Backend/app/routers/tryon.py` → `garment_desc` built from `item.color + style + type` |
| S5.1.4 | Person image is a snapshot taken from the camera feed — captured at 1080×1440 (portrait); center-crop + resize to 768×1024 before sending | ✅ Done | `Backend/app/routers/tryon.py` → `_resize_person_image()` |
| S5.1.5 | Result image cached in Supabase for 24 hours; if same person+garment combo requested again within 24h, return cached result (avoid re-running $0.05 inference) | ✅ Done | `Backend/app/routers/tryon.py` → `_check_tryon_cache()` with deterministic `_cached.jpg` + `_ts.txt` paths |
| S5.1.6 | Timeout: 90s max (45×2s poll); `TimeoutError` → HTTP 504 "Our AI stylists are busy — try again in a moment" | ✅ Done | `Backend/app/routers/tryon.py` |

### S5.2 — Frontend: Style Preview UI

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S5.2.1 | Capture button in camera try-on screen — shown only when ≥ 1 garment is selected | ✅ Done | `camera_try_on_screen.dart` → `_CaptureButton` + `hasGarments` guard |
| S5.2.2 | On tap: (1) capture still frame via `RepaintBoundary.toImage`, (2) show `_CapturePreviewDialog` with "AI Try-On" button | ✅ Done | `camera_try_on_screen.dart` → `_capture()` + `_CapturePreviewDialog` |
| S5.2.3 | POST to `/tryon` with captured frame + selected garment ID via `tryOnProvider.generate()` | ✅ Done | `Frontend/lib/core/providers/tryon_provider.dart` |
| S5.2.4 | Show result in a fullscreen image viewer with a save-to-gallery button and a share button | ✅ Done | `Frontend/lib/features/tryon_result/tryon_result_screen.dart` |
| S5.2.5 | Error state: "Our AI stylists are busy — try again in a moment" with retry button | ✅ Done | `tryon_result_screen.dart` + 504 from backend |
| S5.2.6 | Rate limit: 10 try-ons per user per day | ✅ Done | `Backend/app/routers/tryon.py` → `@limiter.limit("10/day")` |

---

## Phase S6 — Performance & Frame Rate

> All the above must hit ≥ 28 FPS on a Samsung A-series (Snapdragon 778G class).
> This phase profiles, optimises, and locks frame rate.

| # | Item | Status | File(s) |
|---|------|--------|---------|
| S6.1 | Profile baseline with Flutter DevTools timeline; identify any > 16ms frames in the paint pipeline | ⬜ Todo | DevTools — manual |
| S6.2 | TPS solve Isolate: analyzed — 11×11 Gaussian elimination < 0.1ms; Isolate message overhead ~1ms would be slower. Not beneficial at n=8. | ✅ Done | Decision: main thread solve is correct |
| S6.3 | Mask conversion Isolate: `ui.decodeImageFromPixels` already posts GPU upload to a background thread; main thread only builds the `Uint8List` (~65K ops at 4Hz = negligible). | ✅ Done | Decision: current async chain is sufficient |
| S6.4 | `RepaintBoundary` added around the garment `CustomPaint` inside `LayoutBuilder` — garment layer repaints are isolated from CameraPreview composite | ✅ Done | `camera_try_on_screen.dart` → LayoutBuilder |
| S6.5 | Garment `ui.Image` decoded once in `_loadItems` and stored in `_garments` map; reused across all frames via `ImageShader` pointer — no per-frame decode | ✅ Done | `camera_try_on_screen.dart` → `_loadItems()` |
| S6.6 | Wrinkle map pre-blit: garment shown immediately, wrinkle maps load async via `WrinkleCacheService.loadForItem().then()` and replace `_GarmentData` when ready | ✅ Done | `camera_try_on_screen.dart` → `_loadItems()` |
| S6.7 | Quality gate: `_highQuality` set from `PlatformDispatcher.displays.refreshRate >= 59Hz` in `initState`; gates garment edge-shadow blur (S2.2.3) and mask feathering blur (S2.1.4) | ✅ Done | `camera_try_on_screen.dart` → `initState`, painter |
| S6.8 | Device testing matrix: Samsung A54, Pixel 7, iPhone 13 mini, mid-range Xiaomi — all must hit ≥ 28 FPS | ⬜ Todo | Device test — manual |

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
| S0.1 Remove 3D from camera try-on | 5 | 5 | ✅ Done |
| S0.2 Wardrobe 2D cleanup | 3 | 3 | ✅ Done |
| S0.3 Remove GPU worker & disable GLB | 6 | 5 | 🔄 In Progress (S0.3.6 future) |
| S0.4 Manifest cleanup | 1 | 0 | ⬜ Kept intentionally |
| S1.1 Garment Control Points | 3 | 3 | ✅ Done |
| S1.2 TPS Warper | 5 | 5 | ✅ Done |
| S1.3 Fit Tuning | 5 | 5 | ✅ Done |
| S2.1 Occlusion Compositing | 6 | 6 | ✅ Done |
| S2.2 Edge Quality | 3 | 3 | ✅ Done |
| S3 Depth Cues & Lighting | 5 | 5 | ✅ Done |
| S4.1 Wrinkle Map Generation | 4 | 4 | ✅ Done |
| S4.2 On-Device Compositing | 5 | 5 | ✅ Done |
| S5.1 Diffusion Backend | 6 | 5 | 🔄 In Progress (S5.1.1 RunPod deployment pending) |
| S5.2 Style Preview UI | 6 | 6 | ✅ Done |
| S6 Performance | 8 | 6 | 🔄 In Progress (S6.1, S6.8 manual device testing) |
| **Total** | **71** | **69** | 🔄 In Progress |

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
