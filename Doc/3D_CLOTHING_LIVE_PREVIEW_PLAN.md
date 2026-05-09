# 3D Clothing & Live Preview Improvement Plan

## What Was Already Fixed (Point 1 — Auto-Fit)

The live overlay already scales garments automatically via shoulder-span detection. The pixel distance between `leftShoulder` and `rightShoulder` landmarks drives the garment width — if the user steps back, shoulders shrink in frame and the garment scales down proportionally. The following three gaps were addressed:

| Gap | Fix Applied |
|-----|-------------|
| No user override for body proportion differences | **Pinch-to-scale gesture** (50%–200%) on the camera preview |
| Scale indicator not visible during adjustment | **Scale pill** in top-right shows live `%` value; tap to reset |
| Back camera pose degradation at distance | **"Step closer" hint badge** when ML Kit falls back to midpoint-only shoulder detection |
| Scale persisting across camera flips | **Auto-reset** `_manualScale = 1.0` on `_flipCamera()` |

---

## Point 2 — Realism: Why the Current 2D Overlay Has a Ceiling

The current approach paints a flat PNG onto a `Canvas`, then erases arm/neck regions using `BlendMode.dstOut`. The result looks like a costume layer because:

- The garment doesn't drape or fold with body geometry
- It doesn't respond to body tilt beyond a simple X-shear skew
- It sits in front of the body, not on it

This is a fundamental constraint of a 2D overlay. The roadmap below moves from cheapest/fastest to most realistic.

---

## Phase 1 — Perspective Quad-Warp (2–3 weeks)

**Goal**: Make the garment appear to follow the body's 3D shape, not float as a flat rectangle.

**How**: Replace the current `Rect`-based `paintImage` call with a quad-deformed image draw. Compute a trapezoid from four pose keypoints:

```
leftShoulder ──────── rightShoulder
     |                      |
  leftHip   ────────   rightHip
```

Use `Canvas.drawVertices` with a UV-mapped `ImageShader` to stretch the garment texture onto that quad. The garment will:
- Narrow at the waist to follow body taper
- Tilt correctly with body lean (replaces the current X-shear approximation)
- Compress/expand with camera distance naturally via the keypoints

**Files to change**: `_CameraOverlayPainter._paintOne()` in `camera_try_on_screen.dart`.

**New dependencies**: None — `Canvas.drawVertices` and `ImageShader` are in Flutter core.

**Effort**: ~1 week Flutter canvas work. No backend changes.

---

## Phase 2 — Ambient Lighting Match (3–5 days)

**Goal**: The garment looks lit by the same room as the user, not like a flat cut-out from a different photo.

**How**: On each frame tick, sample a 20×20 pixel crop from the camera image around the shoulder region. Compute average luminance. Apply a `ColorFilter.matrix` brightness shift to the garment `Paint` so the garment's lightness tracks the ambient environment.

**Effort**: 3 days. Pure Flutter, no backend. Negligible performance cost (one tiny crop per throttled tick).

---

## Phase 3 — Single-Image 3D Mesh Reconstruction (2–4 months)

**Goal**: Store each garment as a 3D mesh so it can be physically draped and deformed on a live body skeleton during preview.

### Pipeline

```
Upload photo
     │
     ▼
Backend receives PNG (existing upload flow)
     │
     ▼
GPU reconstruction job (new)
  - Model options: TripoSR, InstantMesh, Zero123++
  - Input: garment PNG with transparent background
  - Output: GLB mesh (~500 KB – 2 MB)
  - Runtime: 30–90 seconds on an A10G / T4 GPU
     │
     ▼
GLB stored alongside the 2D PNG
     │
     ▼
Flutter loads GLB for live preview
  - Render with model_viewer_plus or custom WebGL/Impeller layer
  - Skinned to ML Kit body skeleton keypoints
  - Physics drape approximated via bone weights
```

### Where 3D Conversion Happens

The reconstruction runs **on a backend GPU worker**, not on the user's phone. It is a one-time job triggered at upload time, the same way Ollama garment detection runs today. The user sees a "processing" placeholder while it runs, then the 3D asset is ready for all future sessions. The phone only needs to render the pre-built mesh — no ML inference on-device for the 3D part.

---

## Storage & Size Analysis

### Option A — Supabase (current provider)

| Format | Typical Size per Garment |
|--------|--------------------------|
| 2D PNG (current) | 80 KB – 300 KB |
| GLB mesh (Phase 3) | 500 KB – 2 MB |
| Draco-compressed GLB | 150 KB – 600 KB |

**Supabase Free tier**: 1 GB total storage, 2 GB egress/month.

**Reality check**: With Draco compression (~150–600 KB per garment), a user with 50 garments uses ~7–30 MB of 3D storage on top of their 2D PNGs. That fits comfortably within the free tier for a small user base. At scale (hundreds of users × 50 garments) you would exceed the 1 GB cap quickly. A paid Supabase plan ($25/month) gives 100 GB — enough for ~200,000 garments at average 500 KB each.

**Bandwidth concern**: Serving a 500 KB GLB on every live preview session open costs egress. With caching on the device (see Option B below) this becomes a one-time download per garment.

**Verdict**: Supabase free tier works fine during development and beta. At production scale (>500 active users), you need either a paid Supabase plan or to cache the mesh on-device (Option B).

---

### Option B — On-Device Storage

Instead of re-downloading the GLB on every session, cache the mesh to the device's app document directory after the first download.

```dart
// Pseudocode
final dir = await getApplicationDocumentsDirectory();
final file = File('${dir.path}/meshes/${itemId}.glb');
if (!file.existsSync()) {
  final bytes = await _downloadGlb(supabaseUrl);
  await file.writeAsBytes(bytes);
}
// Load mesh from local file — no network call
```

**Per-device storage**: 50 garments × 500 KB = ~25 MB. Well within any modern phone's available space.

**Supabase egress**: Each GLB is downloaded once per device, then served from local storage forever. Egress cost drops dramatically compared to Option A (re-download every session).

**Feasibility with current architecture**: Very high. The existing `storage.dart` / `Dio` download pattern is already used for 2D PNGs. Adding a local cache layer on top requires:
- `path_provider` package (already commonly included in Flutter projects)
- A `GlbCacheService` class (~60 lines) that checks local path before hitting Supabase
- No backend changes — the GLB URL is just another field on `ClothingItem` like `processed_image_path`

This is the recommended approach for Phase 3. On-device cache eliminates repeat download cost and makes the live preview feel instant after the first load.

---

## How It Will Look When Wearing

| Phase | Visual Result |
|-------|---------------|
| **Current (2D flat)** | Garment floats in front of body as a rectangle; arms/neck cut out but edges are geometric |
| **Phase 1 (quad-warp)** | Garment tapers at the waist, tilts with body lean — looks draped rather than pasted |
| **Phase 2 (lighting)** | Garment adopts room lighting — shadow side slightly darker, bright side lighter; no longer looks like a cut-out from a studio photo |
| **Phase 3 (3D mesh)** | Garment is rendered as a 3D object skinned to the body skeleton. Fabric folds at elbows and waist, correct occlusion behind arms, physically based lighting. Close to what dedicated AR fashion apps (Zara AR, Snap) achieve. |

Note: even Phase 3 will not look as realistic as the **static AI try-on** (fashn.ai), because fashn.ai uses a diffusion model that re-generates the entire image with the garment baked in at pixel level. The live preview trades realism for real-time feedback. The recommended UX is: use live preview for rough framing → tap "AI Try-On" to get the photorealistic result.

---

## Recommended Execution Order

```
Now      Phase 1 (quad-warp)        ← highest realism gain, lowest effort
+1 week  Phase 2 (lighting)         ← cheap polish on top of Phase 1
+2 month Phase 3 begins             ← GPU infra + GLB pipeline setup
+4 month Phase 3 Flutter renderer   ← model_viewer_plus or custom renderer
+4 month On-device GLB cache        ← ship with Phase 3
```

The static AI Try-On (fashn.ai) covers photorealistic results **today** — the live preview phases improve the real-time framing experience progressively alongside it.
