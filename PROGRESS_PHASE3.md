# Dressify — Phase 3 Progress: Camera & Real-Time Try-On

> Tracks implementation status for all Phase 3 items (Camera & Real-Time Try-On).
> Updated as each item is completed — not batched at the end.

---

## 3.0 Dependencies & Permissions

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 3.0.1 | Add `camera` package | ✅ Done | `pubspec.yaml` |
| 3.0.2 | Add `google_mlkit_pose_detection` package | ✅ Done | `pubspec.yaml` |
| 3.0.3 | Add `share_plus` package | ✅ Done | `pubspec.yaml` |
| 3.0.4 | Android: `CAMERA` permission in manifest | ✅ Done | `android/app/src/main/AndroidManifest.xml` |
| 3.0.5 | iOS: `NSCameraUsageDescription` + `NSMicrophoneUsageDescription` | ✅ Done | `ios/Runner/Info.plist` |

---

## 3.1 Camera Feed Screen

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 3.1.1 | Camera controller init, lifecycle, front/back flip | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |
| 3.1.2 | `CameraTryOnScreen` — full-screen `CameraPreview` with overlay stack | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |
| 3.1.3 | Route `cameraTryOn` in `AppRoute` enum + `app_router.dart` | ✅ Done | `core/router/app_routes.dart`, `core/router/app_router.dart` |
| 3.1.4 | Camera icon button in `TryOnScreen` top bar (only when outfit has items) | ✅ Done | `features/try_on/try_on_screen.dart` |

---

## 3.2 Pose Detection

| # | Item | Status | Notes |
|---|------|--------|-------|
| 3.2.1 | `PoseDetectionService` — ML Kit `PoseDetector` wrapper, processes `CameraImage` | ✅ Done | `core/services/pose_detection_service.dart` |
| 3.2.2 | Anchor extraction from landmarks: shoulder, chest, waist, hip, feet derived from ML Kit keypoints | ✅ Done | `core/services/pose_detection_service.dart` |
| 3.2.3 | Coordinate normalization: image-space landmarks → normalized (0–1) for display scaling | ✅ Done | `core/services/pose_detection_service.dart` |

---

## 3.3 Live Garment Overlay

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 3.3.1 | `CameraOverlayPainter` — `CustomPainter` that draws garments at pose anchor positions | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |
| 3.3.2 | Frame throttle — max one pose detection per 250 ms (prevents GPU/CPU overload) | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |
| 3.3.3 | Garment image loading from outfit items (same `_decodeNetworkImage` pattern as try-on) | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |
| 3.3.4 | Depth ordering: shoes → bottom → dress → top/jacket (same `_depth` logic as try-on) | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |

---

## 3.4 Capture & Share

| # | Item | Status | File(s) |
|---|------|--------|---------|
| 3.4.1 | Capture button — `RepaintBoundary.toImage()` composites camera feed + garment overlay | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |
| 3.4.2 | Captured image preview dialog (shows composite before sharing) | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |
| 3.4.3 | Share via `share_plus` (`Share.shareXFiles`) | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |

---

## 3.5 UX Polish

| # | Item | Status | Notes |
|---|------|--------|-------|
| 3.5.1 | "Stand in front of the camera" guide when no pose is detected | ✅ Done | `features/camera_try_on/camera_try_on_screen.dart` |
| 3.5.2 | Garment selector — full wardrobe picker within camera mode | ➡️ Deferred | Moved to Open Action Items in Project_Plan.md |

---

## Summary

| Status | Count |
|--------|-------|
| ✅ Done | 16 |
| ➡️ Deferred | 1 |
