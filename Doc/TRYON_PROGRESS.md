# Dressify — Virtual Try-On Progress

> Tracks implementation status for Live Preview Enhancement and AI Photo Try-On.
> Mark each item ✅ Done the moment it is complete — not at the end of the sub-phase.

---

## T1 — Live Preview: Phase 1 (Pose-Based Occlusion)

### T1.1 Pose Detection — Shoulder Span & Extended Landmarks

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T1.1.1 | `leftShoulder` and `rightShoulder` exported individually from `_extractAnchors()` | ✅ Done | `Frontend/lib/core/services/pose_detection_service.dart` |
| T1.1.2 | `_computeShoulderSpan` uses actual horizontal distance between left/right shoulders (not torso-height proxy) | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.1.3 | Add `leftElbow`, `rightElbow`, `leftWrist`, `rightWrist` to exported anchor map | ✅ Done | `Frontend/lib/core/services/pose_detection_service.dart` |
| T1.1.4 | Add `nose` to exported anchor map | ✅ Done | `Frontend/lib/core/services/pose_detection_service.dart` |

### T1.2 Painter — Garment Layer Isolation

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T1.2.1 | Wrap all garment draws in `canvas.saveLayer(…, Paint())` / `canvas.restore()` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.2.2 | Verify `BlendMode.dstOut` only affects the garment layer (not `CameraPreview` beneath) | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |

### T1.3 Painter — Arm Occlusion Paths

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T1.3.1 | `_capsulePath(joints, radius)` — builds a rounded-capsule path through a list of joint offsets | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.3.2 | `_softErasePaint(bounds)` — returns a `BlendMode.dstOut` paint with radial gradient for soft edges | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.3.3 | `_buildArmPath(anchors, 'left', size, shoulderSpan)` — capsule from left shoulder → elbow → wrist; falls back gracefully when elbow/wrist missing | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.3.4 | `_buildArmPath(anchors, 'right', size, shoulderSpan)` — same for right arm | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.3.5 | Erase left and right arm paths with `_softErasePaint` inside `paint()` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.3.6 | Test arm erase on Android device — verify screen coordinate mapping is correct | ⬜ Todo | device |
| T1.3.7 | Test with front (selfie) camera — left/right arm paths flip correctly with mirrored feed | ⬜ Todo | device |

### T1.4 Painter — Neck Occlusion Path

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T1.4.1 | `_buildNeckPath(anchors, size, shoulderSpan)` — ellipse centred between nose and shoulder midpoint; width = `shoulderSpan * 0.38` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.4.2 | Erase neck path with `_softErasePaint` inside `paint()` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.4.3 | Tune neck ellipse dimensions so collar wraps naturally (overlaps shirt collar area) | ⬜ Todo | device |

### T1.5 Painter — Shoulder-Angle Skew

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T1.5.1 | In `_paintOne`: compute `skew = (rsy - lsy) * 0.6` from left/right shoulder Y positions | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.5.2 | Apply `Matrix4` skew transform in `_paintOne` pivoting at shoulder centre; `canvas.save()` / `canvas.restore()` around `paintImage` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T1.5.3 | Test skew on device — ensure garment tilts naturally when shoulder is raised | ⬜ Todo | device |

---

## T2 — Live Preview: Phase 2 (Segmentation Refinement)

### T2.1 Package & Config

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T2.1.1 | Add `google_mlkit_selfie_segmentation: ^0.10.1` to `pubspec.yaml` | ✅ Done | `Frontend/pubspec.yaml` |
| T2.1.2 | Run `flutter pub get` and confirm no version conflicts | ✅ Done | terminal |

### T2.2 SegmentationService

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T2.2.1 | `SegmentationMaskResult` data class: `confidences: List<double>`, `width: int`, `height: int` | ✅ Done | `Frontend/lib/core/services/segmentation_service.dart` |
| T2.2.2 | `SegmentationService` class with `SelfieSegmenter(enableRawSizeMask: true)` | ✅ Done | `Frontend/lib/core/services/segmentation_service.dart` |
| T2.2.3 | `processFrame({image, sensorOrientation, lensDirection})` — busy-guard, calls `_segmenter.processImage`, returns `SegmentationMaskResult?` | ✅ Done | `Frontend/lib/core/services/segmentation_service.dart` |
| T2.2.4 | `_toInputImage()` — reuse same YUV→`InputImage` conversion as `PoseDetectionService` | ✅ Done | `Frontend/lib/core/services/segmentation_service.dart` |
| T2.2.5 | `dispose()` — calls `_segmenter.close()` | ✅ Done | `Frontend/lib/core/services/segmentation_service.dart` |

### T2.3 Frame Integration

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T2.3.1 | Instantiate `SegmentationService _segService` in `_CameraTryOnScreenState` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T2.3.2 | Add `List<double>? _segMask`, `int _segMaskWidth`, `int _segMaskHeight` state fields | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T2.3.3 | In `_onFrame`: dispatch segmentation concurrently with pose (same throttle, non-awaited) | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T2.3.4 | Update `_segMask` / `_segMaskWidth` / `_segMaskHeight` in `setState` when mask arrives | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T2.3.5 | Call `_segService.dispose()` in `dispose()` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |

### T2.4 Painter — Mask-Based Precision Erase

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T2.4.1 | Pass `segMask`, `segMaskWidth`, `segMaskHeight` fields to `_CameraOverlayPainter` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T2.4.2 | In `paint()`: convert mask to `ui.Image` (alpha = confidence); use `BlendMode.dstIn` inside erase `saveLayer` to clip erase to person-only pixels | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T2.4.3 | Verify no frame-rate regression on mid-range Android (target ≥ 30fps) — profile with Flutter DevTools | ⬜ Todo | device |
| T2.4.4 | Skip segmentation ticks when device is struggling — handled by `SegmentationService._busy` guard; returns `null` immediately if previous frame still processing | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |

---

## T3 — AI Photo Try-On

### T3.1 Backend — Config & API Keys

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T3.1.1 | Add `FASHN_API_KEY: str = ""` and `REPLICATE_API_KEY: str = ""` to `Settings` | ✅ Done | `Backend/app/config.py` |
| T3.1.2 | Add `FASHN_API_KEY=` placeholder to `.env` | ✅ Done | `Backend/.env` |
| T3.1.3 | Sign up for fashn.ai and obtain API key; test manually with Postman | ⬜ Todo | external |

### T3.2 Backend — Try-On Endpoint

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T3.2.1 | New router file `tryon.py` with `APIRouter(prefix="/tryon")` | ✅ Done | `Backend/app/routers/tryon.py` |
| T3.2.2 | `POST /tryon` endpoint: accept `person_image: UploadFile` + `clothing_item_id: str`; verify item ownership | ✅ Done | `Backend/app/routers/tryon.py` |
| T3.2.3 | Download garment PNG from Supabase Storage by `item.processed_image_path` | ✅ Done | `Backend/app/routers/tryon.py` |
| T3.2.4 | `_fashn_tryon(person_bytes, garment_bytes)` — base64-encode both, POST to `https://api.fashn.ai/v1/run`, poll `/v1/status/{id}` until `completed` or `failed`, return result bytes | ✅ Done | `Backend/app/routers/tryon.py` |
| T3.2.5 | `_replicate_tryon(person_bytes, garment_bytes)` — fallback using Replicate IDM-VTON | ✅ Done | `Backend/app/routers/tryon.py` |
| T3.2.6 | `_call_vton_api()` — selects fashn.ai or Replicate based on which key is set; raises HTTP 503 if neither configured | ✅ Done | `Backend/app/routers/tryon.py` |
| T3.2.7 | Upload result image to Supabase at `tryon/{user_id}/{item_id}_{timestamp}.jpg` | ✅ Done | `Backend/app/routers/tryon.py` |
| T3.2.8 | Return signed URL (1-hour expiry) for the stored result | ✅ Done | `Backend/app/routers/tryon.py` |
| T3.2.9 | Register `tryon.router` in `app/main.py` with prefix `/api/v1` | ✅ Done | `Backend/app/main.py` |

### T3.3 Frontend — Provider & State

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T3.3.1 | `TryOnStatus` enum: `idle`, `loading`, `done`, `error` | ✅ Done | `Frontend/lib/core/providers/tryon_provider.dart` |
| T3.3.2 | `TryOnState` data class: `status`, `resultUrl?`, `errorMessage?` | ✅ Done | `Frontend/lib/core/providers/tryon_provider.dart` |
| T3.3.3 | `TryOnNotifier extends StateNotifier<TryOnState>`: `generate({personImageBytes, clothingItemId})` — POSTs multipart form, updates state | ✅ Done | `Frontend/lib/core/providers/tryon_provider.dart` |
| T3.3.4 | `TryOnNotifier.reset()` — resets to `TryOnState.idle` | ✅ Done | `Frontend/lib/core/providers/tryon_provider.dart` |
| T3.3.5 | `tryOnProvider` — `StateNotifierProvider<TryOnNotifier, TryOnState>` wired to `apiClientProvider` | ✅ Done | `Frontend/lib/core/providers/tryon_provider.dart` |

### T3.4 Frontend — Capture Dialog & UI

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T3.4.1 | "AI Try-On" button added to `_CapturePreviewDialog` action row; shows spinner while `status == loading` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T3.4.2 | Garment picker: if multiple items loaded, inline horizontal selector to choose one before calling `generate()` | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |
| T3.4.3 | On success: `context.pushNamed(AppRoute.tryOnResult.name, extra: resultUrl)` via `onTryOnResult` callback | ✅ Done | `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart` |

### T3.5 Frontend — Result Screen & Routing

| # | Item | Status | File(s) |
|---|------|--------|---------|
| T3.5.1 | `AppRoute.tryOnResult('/tryon-result')` added to `app_routes.dart` | ✅ Done | `Frontend/lib/core/router/app_routes.dart` |
| T3.5.2 | `GoRoute` for `tryOnResult` added to `app_router.dart` (`parentNavigatorKey: _rootNavigatorKey`) | ✅ Done | `Frontend/lib/core/router/app_router.dart` |
| T3.5.3 | `TryOnResultScreen`: black `Scaffold` with `AppBar`, `InteractiveViewer` + `CachedNetworkImage`, share button | ✅ Done | `Frontend/lib/features/tryon_result/tryon_result_screen.dart` |
| T3.5.4 | Share button: `Dio().get<List<int>>` bytes + `XFile.fromData` + `Share.shareXFiles` (no `path_provider`) | ✅ Done | `Frontend/lib/features/tryon_result/tryon_result_screen.dart` |
| T3.5.5 | Loading UX: `CachedNetworkImage` placeholder shows `CircularProgressIndicator` while image resolves | ✅ Done | `Frontend/lib/features/tryon_result/tryon_result_screen.dart` |

---

## Summary

| Status | Count |
|--------|-------|
| ✅ Done | 53 |
| ⬜ Todo | 7 (device testing × 6, external API key × 1) |

---

## Sub-Phase Completion Checklist

| Sub-Phase | Items | Done | Status |
|---|---|---|---|
| T1.1 Pose Detection — Extended Landmarks | 4 | 4 | ✅ Complete |
| T1.2 Painter — Garment Layer Isolation | 2 | 2 | ✅ Complete |
| T1.3 Painter — Arm Occlusion Paths | 7 | 5 | 🔄 Needs device test |
| T1.4 Painter — Neck Occlusion Path | 3 | 2 | 🔄 Needs device test |
| T1.5 Painter — Shoulder-Angle Skew | 3 | 2 | 🔄 Needs device test |
| T2.1 Segmentation Package & Config | 2 | 2 | ✅ Complete |
| T2.2 SegmentationService | 5 | 5 | ✅ Complete |
| T2.3 Frame Integration | 5 | 5 | ✅ Complete |
| T2.4 Mask-Based Precision Erase | 4 | 3 | 🔄 Needs device test |
| T3.1 Backend — Config & API Keys | 3 | 2 | 🔄 Needs API key |
| T3.2 Backend — Try-On Endpoint | 9 | 9 | ✅ Complete |
| T3.3 Frontend — Provider & State | 5 | 5 | ✅ Complete |
| T3.4 Frontend — Capture Dialog & UI | 3 | 3 | ✅ Complete |
| T3.5 Frontend — Result Screen & Routing | 5 | 5 | ✅ Complete |
| **Total** | **60** | **53** | 🔄 In Progress |
