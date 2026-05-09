# Dressify — Live Preview & 3D Clothing Progress

> Tracks implementation status for all live preview improvements and the 3D clothing pipeline.
> Mark each item ✅ Done the moment it is complete — not at the end of the sub-phase.

---

## L1 — Auto-Fit & Pinch-to-Scale

### L1.1 Flutter — Camera Overlay Fit Controls

| # | Item | Status | File(s) |
|---|------|--------|---------|
| L1.1.1 | `_manualScale` + `_scaleOnGestureStart` state fields in `_CameraTryOnScreenState` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| L1.1.2 | Wrap `RepaintBoundary` in `GestureDetector`; `onScaleUpdate` clamps `_manualScale` to 0.5–2.0; only fires when `pointerCount ≥ 2` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| L1.1.3 | `_manualScale` passed to `_CameraOverlayPainter` and multiplied into garment width in `_paintOne()` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| L1.1.4 | `_CameraOverlayPainter.shouldRepaint`: add `old.manualScale != manualScale` check | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| L1.1.5 | Auto-reset `_manualScale = 1.0` in `_flipCamera()` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| L1.1.6 | `_ScalePill` widget — shows live `%` value; tap resets to 1.0; appears when scale differs by >1% from default | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| L1.1.7 | Pose quality hint badge — "Step closer for better fit" shown when anchors exist but only midpoint fallback available (no `leftShoulder`/`rightShoulder`) | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |

---

## L2 — Perspective Quad-Warp

> Replaces the flat `Rect`-based garment draw with a shoulder+hip quadrilateral deformation.
> The garment will taper at the waist, tilt with body lean, and compress with camera distance.
> No new dependencies — uses `Canvas.drawVertices` + `ImageShader` from Flutter core.

### L2.1 Flutter — Painter Refactor

| # | Item | Status | File(s) |
|---|------|--------|---------|
| L2.1.1 | Extract `_computeBodyQuad(anchors, size)` — returns `(ls, rs, lh, rh)` as four `Offset` points; falls back to current `Rect` when hip keypoints are absent | ✅ Done | `camera_try_on_screen.dart` |
| L2.1.2 | Replace `paintImage(rect: rect)` with `_paintImageOnQuad(canvas, img, quad)` using `Canvas.drawVertices` + `ImageShader` with UV coordinates mapped to image corners | ✅ Done | `camera_try_on_screen.dart` |
| L2.1.3 | Remove existing X-shear `Matrix4` skew — quad deformation handles body tilt natively | ✅ Done | `camera_try_on_screen.dart` |
| L2.1.4 | Preserve fallback: when `leftHip`/`rightHip` landmarks are absent (e.g. top-garment, cropped frame), fall back to current `Rect`+skew path | ✅ Done | `camera_try_on_screen.dart` |
| L2.1.5 | Test quad-warp on front camera at 3 distances: arm's length, 1 m, 2 m — garment should scale and taper correctly | ⬜ Todo | Device test |
| L2.1.6 | Test quad-warp on back camera — same distance variations | ⬜ Todo | Device test |

---

## L3 — Ambient Lighting Match

> Samples the live camera frame near the shoulder region each frame tick to derive ambient
> luminance. Applies a `ColorFilter.matrix` brightness shift to the garment paint so it
> appears lit by the same room as the user.

### L3.1 Flutter — Lighting Service

| # | Item | Status | File(s) |
|---|------|--------|---------|
| L3.1.1 | `LuminanceSampler` helper: given a `CameraImage` and a `Rect` in normalised coordinates, returns average `[0.0–1.0]` luma from the Y plane (NV21/BGRA) | ⬜ Todo | `Frontend/lib/core/services/luminance_sampler.dart` (new) |
| L3.1.2 | In `_onFrame`, after pose result, call `LuminanceSampler.sample()` on the shoulder region (`Rect.fromCenter(shoulder, 0.10w, 0.10h)`); store result in `_ambientLuma` state field | ⬜ Todo | `camera_try_on_screen.dart` |
| L3.1.3 | Pass `ambientLuma` to `_CameraOverlayPainter`; apply `ColorFilter.matrix` brightness shift to garment `Paint` in `_paintOne()` — scale factor: `0.75 + luma * 0.50` (darkens at `luma=0`, brightens at `luma=1`, neutral at `luma=0.5`) | ⬜ Todo | `camera_try_on_screen.dart` |
| L3.1.4 | Add `old.ambientLuma != ambientLuma` to `shouldRepaint` | ⬜ Todo | `camera_try_on_screen.dart` |
| L3.1.5 | Throttle luminance sampling to every 3rd frame tick (share `_lastFrameTime` gate) — avoids CPU cost on every 250 ms tick | ⬜ Todo | `camera_try_on_screen.dart` |

---

## L4 — 3D Mesh Reconstruction Pipeline

> One-time GLB mesh generated at upload time by a backend GPU worker.
> Stored in Supabase; downloaded once per device and cached locally via `GlbCacheService`.
> Live preview loads the mesh from the local cache — no repeat network call.

### L4.1 Backend — Database & Schema

| # | Item | Status | File(s) |
|---|------|--------|---------|
| L4.1.1 | Alembic migration: add `glb_mesh_path` VARCHAR (nullable) to `clothing_items` | ⬜ Todo | `Backend/alembic/versions/` (new migration) |
| L4.1.2 | `ClothingItem` SQLAlchemy model: add `glb_mesh_path` column | ⬜ Todo | `Backend/app/models/clothing_item.py` |
| L4.1.3 | `ClothingItemResponse` Pydantic schema: expose `glb_mesh_path` (nullable string) | ⬜ Todo | `Backend/app/schemas/clothing.py` |
| L4.1.4 | `ClothingItem` model: add `mesh_status` ENUM (`pending`, `processing`, `completed`, `failed`) nullable, default null | ⬜ Todo | `Backend/app/models/clothing_item.py` |

### L4.2 Backend — GPU Reconstruction Service

| # | Item | Status | File(s) |
|---|------|--------|---------|
| L4.2.1 | Provision GPU worker instance (Vast.ai / RunPod / Replicate) capable of running TripoSR or InstantMesh | ⬜ Todo | Infrastructure |
| L4.2.2 | `mesh_reconstruction.py` service: `async reconstruct_glb(png_bytes) → bytes` — calls GPU worker API, returns GLB binary | ⬜ Todo | `Backend/app/services/mesh_reconstruction.py` (new) |
| L4.2.3 | Add Draco compression post-processing step — target GLB size ≤ 600 KB; pip dep: `pygltflib` + `draco` CLI | ⬜ Todo | `Backend/app/services/mesh_reconstruction.py` |
| L4.2.4 | Background task `trigger_mesh_reconstruction(item_id, png_path)`: downloads PNG from Supabase, calls service, uploads GLB to `clothing-meshes` bucket, updates `glb_mesh_path` + `mesh_status` | ⬜ Todo | `Backend/app/services/mesh_reconstruction.py` |
| L4.2.5 | Create `clothing-meshes` Supabase storage bucket; set public read, auth write | ⬜ Todo | Supabase dashboard |
| L4.2.6 | Wire background task into `POST /upload` endpoint — fires after `processing_status` set to `completed` | ⬜ Todo | `Backend/app/routers/upload.py` |
| L4.2.7 | `GET /clothing/{id}` response: include signed URL for `glb_mesh_path` alongside `processed_image_path` | ⬜ Todo | `Backend/app/routers/clothing.py` |
| L4.2.8 | `mesh_status` polling endpoint or websocket push — client polls until `mesh_status == completed` | ⬜ Todo | `Backend/app/routers/clothing.py` |

### L4.3 Frontend — ClothingItem Model & Provider

| # | Item | Status | File(s) |
|---|------|--------|---------|
| L4.3.1 | `ClothingItem` Dart model: add `glbMeshUrl` (nullable String) and `meshStatus` (nullable String) fields | ⬜ Todo | `Frontend/lib/core/models/clothing_item.dart` |
| L4.3.2 | `wardrobeProvider` + `clothingApiService`: deserialise new fields from API response | ⬜ Todo | `Frontend/lib/core/providers/wardrobe_provider.dart` |

### L4.4 Frontend — On-Device GLB Cache

| # | Item | Status | File(s) |
|---|------|--------|---------|
| L4.4.1 | Add `path_provider` to `pubspec.yaml` (if not already present) | ⬜ Todo | `Frontend/pubspec.yaml` |
| L4.4.2 | `GlbCacheService` class: `getMeshPath(itemId, remoteUrl) → Future<String?>` — checks `<appDocDir>/meshes/<itemId>.glb`; downloads and writes if absent; returns local path | ⬜ Todo | `Frontend/lib/core/services/glb_cache_service.dart` (new) |
| L4.4.3 | `GlbCacheService.evict(itemId)` — deletes local GLB when clothing item is deleted; called from wardrobe delete flow | ⬜ Todo | `Frontend/lib/core/services/glb_cache_service.dart` |
| L4.4.4 | `GlbCacheService.clearAll()` — clears mesh cache on sign-out | ⬜ Todo | `Frontend/lib/core/services/glb_cache_service.dart` |

### L4.5 Frontend — 3D Renderer

| # | Item | Status | File(s) |
|---|------|--------|---------|
| L4.5.1 | Add `model_viewer_plus` (or `flutter_3d_controller`) to `pubspec.yaml`; evaluate render quality and AR support | ⬜ Todo | `Frontend/pubspec.yaml` |
| L4.5.2 | `GarmentMeshRenderer` widget: loads GLB from local path via `GlbCacheService`; renders in an `Offstage` layer initially to warm up the GL context | ⬜ Todo | `Frontend/lib/core/widgets/garment_mesh_renderer.dart` (new) |
| L4.5.3 | Camera try-on screen: detect when loaded garments have `glbMeshUrl != null`; show "3D Mode" toggle pill in top bar | ⬜ Todo | `camera_try_on_screen.dart` |
| L4.5.4 | In 3D mode, replace `_CameraOverlayPainter` with `GarmentMeshRenderer` composited over `CameraPreview` | ⬜ Todo | `camera_try_on_screen.dart` |
| L4.5.5 | Skeleton binding: pass `_anchors` (shoulder, chest, waist, hip) to renderer so it positions and scales the mesh to the body | ⬜ Todo | `garment_mesh_renderer.dart` |
| L4.5.6 | Fallback: when GLB not yet available (`meshStatus != completed`), silently stay in 2D mode; show progress indicator on "3D Mode" toggle | ⬜ Todo | `camera_try_on_screen.dart` |
| L4.5.7 | Device test: 3D mode frame rate profiling on Android mid-range (target ≥ 24 fps) | ⬜ Todo | Device test |
| L4.5.8 | Device test: 3D mode on iOS (test GLB loading, skeleton binding, AR accuracy) | ⬜ Todo | Device test |

---

## Summary

| Status | Count |
|--------|-------|
| ✅ Done | 11 |
| ⬜ Todo | 27 |

---

## Sub-Phase Completion Checklist

| Sub-Phase | Items | Done | Status |
|---|---|---|---|
| L1 Auto-Fit & Pinch-to-Scale | 7 | 7 | ✅ Complete |
| L2 Perspective Quad-Warp | 6 | 4 | 🔄 In Progress |
| L3 Ambient Lighting Match | 5 | 0 | ⬜ Not started |
| L4.1 DB & Schema | 4 | 0 | ⬜ Not started |
| L4.2 GPU Reconstruction Service | 8 | 0 | ⬜ Not started |
| L4.3 ClothingItem Model & Provider | 2 | 0 | ⬜ Not started |
| L4.4 On-Device GLB Cache | 4 | 0 | ⬜ Not started |
| L4.5 3D Renderer | 8 | 0 | ⬜ Not started |
| **Total** | **38** | **7** | 🔄 In Progress |

---

## Storage & Infrastructure Reference

| Concern | Detail |
|---------|--------|
| GLB size (raw) | 500 KB – 2 MB per garment |
| GLB size (Draco compressed) | 150 KB – 600 KB per garment |
| Supabase free tier cap | 1 GB total; fits ~2,000 compressed meshes |
| Supabase paid ($25/month) | 100 GB; fits ~200,000 meshes |
| On-device storage (50 garments) | ~25 MB — negligible on any modern phone |
| GPU reconstruction time | 30–90 seconds per garment (A10G / T4 class) |
| Recommended GPU provider | Vast.ai (cheapest), RunPod, or Replicate (managed) |
| Reconstruction model options | TripoSR (fastest), InstantMesh (best quality), Zero123++ |

## On-Device Cache Architecture

```
First load (garment ID: abc123)
  └── GlbCacheService.getMeshPath("abc123", supabaseUrl)
        ├── Check <appDocDir>/meshes/abc123.glb  ← file exists?
        │     YES → return local path immediately (zero network)
        │     NO  → download from Supabase
        │             └── write to <appDocDir>/meshes/abc123.glb
        │                   └── return local path

Item deleted
  └── GlbCacheService.evict("abc123")
        └── delete <appDocDir>/meshes/abc123.glb

User signs out
  └── GlbCacheService.clearAll()
        └── delete <appDocDir>/meshes/ directory
```
