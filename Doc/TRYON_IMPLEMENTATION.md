# Virtual Try-On: Implementation Plan

## Overview

Two distinct modes with different quality/speed tradeoffs:

| Mode | Goal | Latency | Quality |
|---|---|---|---|
| **Live Preview** | Real-time camera overlay | 0ms (live) | ~75–80% realism |
| **AI Try-On** | Photo-based photorealistic result | 8–15s | ~95–100% realism |

---

## Part 1 — Live Preview Enhancement

### Current State
- ML Kit pose detection → shoulder midpoint
- Garment PNG painted flat at shoulder position
- No occlusion → looks pasted on

### Target State
- Garment painted at correct shoulder position and angle
- Arms and neck **appear in front** of the garment
- Soft blended edges (not hard cutout)
- Segmentation mask refines occlusion zones for precision

---

### Architecture

```
Camera Frame (each tick)
  │
  ├─► Pose Detection (ML Kit)          → anchors: shoulder, elbow, wrist, nose
  ├─► Selfie Segmentation (ML Kit)     → personMask: Float32List (Phase 2 only)
  │
  └─► CustomPainter
        1. Draw garment PNG at shoulder (existing)
        2. Apply shoulder-angle perspective skew
        3. Erase arm paths  ─── BlendMode.dstOut (camera shows through)
        4. Erase neck region ─── BlendMode.dstOut
        5. [Phase 2] Refine erase with segmentation mask
```

**Key insight**: `CameraPreview` widget already renders the live feed behind the `CustomPaint` overlay. Painting with `BlendMode.dstOut` in arm/neck regions makes those overlay pixels transparent — the live camera naturally shows through. **No camera frame decoding required.**

---

### Phase 1 — Pose-Based Occlusion (No new packages)

#### 1.1 Extend PoseDetectionService

Add elbow, wrist, and nose landmarks to the exported anchor map.

**File**: `Frontend/lib/core/services/pose_detection_service.dart`

```dart
// In _extractAnchors(), add after existing shoulder exports:
final NormAnchor? le = lm(PoseLandmarkType.leftElbow);
final NormAnchor? re = lm(PoseLandmarkType.rightElbow);
final NormAnchor? lw = lm(PoseLandmarkType.leftWrist);
final NormAnchor? rw = lm(PoseLandmarkType.rightWrist);
final NormAnchor? nose = lm(PoseLandmarkType.nose);

if (le != null) anchors['leftElbow']  = le;
if (re != null) anchors['rightElbow'] = re;
if (lw != null) anchors['leftWrist']  = lw;
if (rw != null) anchors['rightWrist'] = rw;
if (nose != null) anchors['nose']     = nose;
```

#### 1.2 Add Garment-Layer Occlusion to Overlay Painter

**File**: `Frontend/lib/features/camera_try_on/camera_try_on_screen.dart`

Replace the `_paintOne` method and add occlusion logic:

```dart
@override
void paint(Canvas canvas, Size size) {
  final Map<String, NormAnchor>? a = anchors;
  if (a == null || a.isEmpty) return;

  final List<_GarmentData> sorted = List<_GarmentData>.from(garments)
    ..sort((a, b) => garmentDepth(a.item.type).compareTo(garmentDepth(b.item.type)));

  final double shoulderSpan = _computeShoulderSpan(a, size);

  // ── Draw all garments into an isolated layer ──────────────────────────────
  // saveLayer isolates blend operations so dstOut only affects this layer,
  // not the CameraPreview beneath it.
  canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

  for (final _GarmentData g in sorted) {
    _paintOne(canvas, size, g, a, shoulderSpan);
  }

  // ── Erase arm regions (let camera show through) ───────────────────────────
  final Paint erasePaint = Paint()..blendMode = BlendMode.dstOut;

  final Path leftArm  = _buildArmPath(a, 'left',  size, shoulderSpan);
  final Path rightArm = _buildArmPath(a, 'right', size, shoulderSpan);
  final Path neck     = _buildNeckPath(a, size, shoulderSpan);

  // Soft-edged erase: gradient alpha on the boundary so it blends naturally
  canvas.drawPath(leftArm,  _softErasePaint(leftArm.getBounds(),  erasePaint));
  canvas.drawPath(rightArm, _softErasePaint(rightArm.getBounds(), erasePaint));
  canvas.drawPath(neck,     _softErasePaint(neck.getBounds(),     erasePaint));

  canvas.restore();
}

// Arm path: rounded capsule from shoulder → elbow → wrist
Path _buildArmPath(
  Map<String, NormAnchor> a,
  String side,
  Size size,
  double shoulderSpan,
) {
  final String sKey = side == 'left' ? 'leftShoulder' : 'rightShoulder';
  final String eKey = side == 'left' ? 'leftElbow'    : 'rightElbow';
  final String wKey = side == 'left' ? 'leftWrist'    : 'rightWrist';

  final NormAnchor? shoulder = a[sKey];
  final NormAnchor? elbow    = a[eKey];
  final NormAnchor? wrist    = a[wKey];

  if (shoulder == null) return Path();

  // Width of the arm capsule (proportional to body width)
  final double r = shoulderSpan * 0.18;

  final Offset p0 = Offset(shoulder.x * size.width, shoulder.y * size.height);
  final Offset p1 = elbow != null
      ? Offset(elbow.x * size.width, elbow.y * size.height)
      : Offset(p0.dx + (side == 'left' ? -r * 0.5 : r * 0.5), p0.dy + shoulderSpan * 0.6);
  final Offset p2 = wrist != null
      ? Offset(wrist.x * size.width, wrist.y * size.height)
      : null;

  return _capsulePath([p0, p1, if (p2 != null) p2], r);
}

// Neck path: soft ellipse above shoulder midpoint
Path _buildNeckPath(
  Map<String, NormAnchor> a,
  Size size,
  double shoulderSpan,
) {
  final NormAnchor? shoulder = a['shoulder'];
  final NormAnchor? nose     = a['nose'];

  if (shoulder == null) return Path();

  final double cx = shoulder.x * size.width;
  // Top of erase zone: between nose and shoulder (the neck area)
  final double top = nose != null
      ? (nose.y * size.height + shoulder.y * size.height) / 2
      : shoulder.y * size.height - shoulderSpan * 0.35;
  final double bottom = shoulder.y * size.height;

  final double neckW = shoulderSpan * 0.38;
  final double neckH = (bottom - top).abs();

  return Path()
    ..addOval(Rect.fromCenter(
      center: Offset(cx, top + neckH / 2),
      width: neckW,
      height: neckH,
    ));
}

// Builds a rounded-capsule path through a list of joints
Path _capsulePath(List<Offset> joints, double radius) {
  if (joints.isEmpty) return Path();
  if (joints.length == 1) {
    return Path()..addOval(Rect.fromCircle(center: joints[0], radius: radius));
  }

  final path = Path();
  for (int i = 0; i < joints.length - 1; i++) {
    final Offset a = joints[i];
    final Offset b = joints[i + 1];
    final Offset dir = (b - a) / (b - a).distance;
    final Offset perp = Offset(-dir.dy, dir.dx);

    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromPoints(
        a + perp * radius - dir * radius,
        b - perp * radius + dir * radius,
      ).expandToInclude(Rect.fromCircle(center: a, radius: radius))
       .expandToInclude(Rect.fromCircle(center: b, radius: radius)),
      Radius.circular(radius),
    ));
  }
  return path;
}

// Returns an erase paint with a radial gradient for soft edges
Paint _softErasePaint(Rect bounds, Paint base) {
  if (bounds.isEmpty) return base;
  return Paint()
    ..blendMode = BlendMode.dstOut
    ..shader = RadialGradient(
      colors: [Colors.black, Colors.black.withAlpha(0)],
      stops: const [0.55, 1.0],
    ).createShader(bounds);
}
```

#### 1.3 Shoulder-Angle Perspective Skew

If one shoulder is higher than the other, the garment should tilt to match. Apply a horizontal skew transform in `_paintOne`.

```dart
void _paintOne(Canvas canvas, Size size, _GarmentData g,
    Map<String, NormAnchor> anchors, double shoulderSpan) {
  // ... existing rect calculation ...

  // Shoulder tilt: if right shoulder is lower than left, skew the garment
  final double lsy = (anchors['leftShoulder']?.y  ?? anchors['shoulder']!.y);
  final double rsy = (anchors['rightShoulder']?.y ?? anchors['shoulder']!.y);
  final double skew = (rsy - lsy) * 0.6; // damped skew factor

  canvas.save();
  canvas.transform(Matrix4(
    1, skew, 0, 0,
    0, 1,    0, 0,
    0, 0,    1, 0,
    // translate so skew pivots at shoulder centre
    0, -skew * ay, 0, 1,
  ).storage);

  paintImage(
    canvas: canvas,
    rect: rect,
    image: img,
    fit: BoxFit.fill,
  );

  canvas.restore();
}
```

---

### Phase 2 — Segmentation Refinement

This phase refines the arm/neck erase zones to only remove pixels where a real person is detected, preventing garment erasure in empty space (e.g., if the arm path extends past the body).

#### 2.1 Add Package

```yaml
# pubspec.yaml
dependencies:
  google_mlkit_selfie_segmentation: ^0.3.0
```

#### 2.2 Run Segmentation Per Frame (Throttled)

**File**: `camera_try_on_screen.dart` — in `_CameraTryOnScreenState`:

```dart
final SegmentationService _segService = SegmentationService();
Float32List? _segMask;
int _segMaskWidth  = 0;
int _segMaskHeight = 0;

// In _onFrame — run segmentation on the same throttle as pose:
void _onFrame(CameraImage image) {
  final DateTime now = DateTime.now();
  if (now.difference(_lastFrameTime) < _frameThrottle) return;
  _lastFrameTime = now;

  // Pose (existing)
  _poseService.processFrame(...).then((anchors) {
    if (mounted) setState(() => _anchors = anchors);
  });

  // Segmentation (new)
  _segService.processFrame(image: image, ...).then((mask) {
    if (mounted && mask != null) {
      setState(() {
        _segMask       = mask.confidences;
        _segMaskWidth  = mask.width;
        _segMaskHeight = mask.height;
      });
    }
  });
}
```

#### 2.3 Segmentation Service

**New file**: `Frontend/lib/core/services/segmentation_service.dart`

```dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

class SegmentationMaskResult {
  final Float32List confidences;
  final int width;
  final int height;
  SegmentationMaskResult(this.confidences, this.width, this.height);
}

class SegmentationService {
  final SelfieSegmenter _segmenter = SelfieSegmenter(
    segmenterOptions: SegmenterOptions(enableRawSizeMask: true),
  );
  bool _busy = false;

  Future<SegmentationMaskResult?> processFrame({
    required CameraImage image,
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      final InputImage? inputImage = _toInputImage(image, sensorOrientation, lensDirection);
      if (inputImage == null) return null;
      final SegmentationMask mask = await _segmenter.processImage(inputImage);
      return SegmentationMaskResult(
        mask.confidences,
        mask.width,
        mask.height,
      );
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  // InputImage construction identical to PoseDetectionService._toInputImage
  InputImage? _toInputImage(CameraImage image, int sensorOrientation,
      CameraLensDirection lensDirection) { /* same logic */ }

  Future<void> dispose() => _segmenter.close();
}
```

#### 2.4 Pass Mask to Painter + Use for Precise Erasure

Pass `_segMask`, `_segMaskWidth`, `_segMaskHeight` to `_CameraOverlayPainter`. In `paint()`, after building arm/neck paths, apply the mask as a clipping refinement: only erase pixels where `segMask[y * maskW + x] > 0.5`.

Since masks are low-res (e.g., 256×144), bilinear-interpolate the mask value for each screen pixel. Use this as a multiplier on the erase alpha — arm path erase × mask confidence.

---

### Performance Budget

| Operation | Target | How |
|---|---|---|
| Pose detection | ≤ 33ms | Already throttled to 15fps |
| Selfie segmentation | ≤ 20ms | Same throttle, runs concurrently |
| `_paintOne` + arm paths | ≤ 4ms | Pure canvas ops, no decode |
| Frame rate | ≥ 30fps camera | CameraPreview is GPU-composited |
| Total overlay budget | ≤ 16ms/frame | Fits in 60fps budget |

**Critical**: Never decode `CameraImage` to `ui.Image` on the main thread. All ML Kit calls are already async off-thread. The `_onFrame` callback just dispatches them — never awaits.

---

### Phase 1 Checklist

- [ ] Add `leftElbow`, `rightElbow`, `leftWrist`, `rightWrist`, `nose` to `PoseDetectionService`
- [ ] Add `_buildArmPath()`, `_buildNeckPath()`, `_capsulePath()`, `_softErasePaint()` to painter
- [ ] Wrap garment draw in `canvas.saveLayer` / `canvas.restore`
- [ ] Erase arm + neck paths with `BlendMode.dstOut` + gradient paint
- [ ] Apply shoulder-angle skew transform in `_paintOne`
- [ ] Test on Android (check arm erase respects screen coordinate mapping)
- [ ] Test with front camera mirror (left/right arm paths should flip correctly)

### Phase 2 Checklist

- [ ] Add `google_mlkit_selfie_segmentation` to `pubspec.yaml`
- [ ] Implement `SegmentationService`
- [ ] Run segmentation in `_onFrame` concurrently with pose
- [ ] Bilinear-interpolate mask into screen coordinates in painter
- [ ] Multiply erase alpha by mask confidence per pixel
- [ ] Verify no frame-rate regression on mid-range Android

---

## Part 2 — AI Photo Try-On

### Flow

```
User taps Capture in camera screen
    ↓
Existing capture preview dialog appears
    ↓
New "AI Try-On" button added to the dialog
    ↓
POST /api/tryon  { person_image, clothing_item_id }
    ↓
Backend downloads garment PNG from Supabase
    ↓
Call fashn.ai API (or Replicate IDM-VTON)
    ↓
Store result image in Supabase
    ↓
Return result_url (or poll via GET /api/tryon/{job_id})
    ↓
Flutter shows result in full-screen viewer
```

---

### Backend

#### New Endpoint: `POST /api/tryon`

**File**: `Backend/app/routers/tryon.py` (new file)

```python
import httpx
from fastapi import APIRouter, Depends, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.config import settings
from app.models.clothing_item import ClothingItem
from app.services.storage import download_file, upload_file
from app.routers.deps import current_user

router = APIRouter(prefix="/tryon", tags=["tryon"])

@router.post("")
async def create_tryon(
    person_image: UploadFile = File(...),
    clothing_item_id: str    = Form(...),
    db: AsyncSession         = Depends(get_db),
    user                     = Depends(current_user),
):
    # 1. Fetch the garment PNG URL from DB
    item = await db.get(ClothingItem, clothing_item_id)
    if not item or item.user_id != user.id:
        raise HTTPException(404, "Item not found")

    # 2. Download garment from Supabase
    garment_bytes = download_file(settings.CLOTHING_BUCKET, item.processed_image_path)

    # 3. Read person photo
    person_bytes = await person_image.read()

    # 4. Call VTON API
    result_bytes = await _call_vton_api(person_bytes, garment_bytes)

    # 5. Store result
    result_path = f"tryon/{user.id}/{clothing_item_id}_{int(time.time())}.jpg"
    upload_file(settings.CLOTHING_BUCKET, result_path, result_bytes, "image/jpeg")

    # 6. Return signed URL
    result_url = get_signed_url(settings.CLOTHING_BUCKET, result_path, expires_in=3600)
    return {"result_url": result_url}


async def _call_vton_api(person_bytes: bytes, garment_bytes: bytes) -> bytes:
    """
    Primary: fashn.ai  (https://fashn.ai/docs)
    Fallback: Replicate IDM-VTON
    """
    if settings.FASHN_API_KEY:
        return await _fashn_tryon(person_bytes, garment_bytes)
    elif settings.REPLICATE_API_KEY:
        return await _replicate_tryon(person_bytes, garment_bytes)
    else:
        raise HTTPException(503, "No VTON API configured")


async def _fashn_tryon(person_bytes: bytes, garment_bytes: bytes) -> bytes:
    import base64
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            "https://api.fashn.ai/v1/run",
            headers={"Authorization": f"Bearer {settings.FASHN_API_KEY}"},
            json={
                "model_image": base64.b64encode(person_bytes).decode(),
                "garment_image": base64.b64encode(garment_bytes).decode(),
                "category": "tops",   # adjust based on clothing type
            },
        )
        resp.raise_for_status()
        data = resp.json()

        # Poll for result (fashn.ai is async)
        prediction_id = data["id"]
        for _ in range(30):   # max 30s
            await asyncio.sleep(1)
            status_resp = await client.get(
                f"https://api.fashn.ai/v1/status/{prediction_id}",
                headers={"Authorization": f"Bearer {settings.FASHN_API_KEY}"},
            )
            status = status_resp.json()
            if status["status"] == "completed":
                img_resp = await client.get(status["output"][0])
                return img_resp.content
            elif status["status"] == "failed":
                raise RuntimeError("VTON API failed")
        raise TimeoutError("VTON API timed out")
```

#### Config additions

```python
# app/config.py — add to Settings:
FASHN_API_KEY:     str = ""
REPLICATE_API_KEY: str = ""
```

```bash
# .env
FASHN_API_KEY=your_key_here
```

#### Register router

```python
# app/main.py
from app.routers import tryon
app.include_router(tryon.router, prefix="/api")
```

---

### Frontend

#### New Dart Files

**`lib/core/providers/tryon_provider.dart`**

```dart
enum TryOnStatus { idle, loading, done, error }

class TryOnState {
  final TryOnStatus status;
  final String?     resultUrl;
  final String?     errorMessage;
  const TryOnState({this.status = TryOnStatus.idle, this.resultUrl, this.errorMessage});
}

class TryOnNotifier extends StateNotifier<TryOnState> {
  TryOnNotifier(this._dio) : super(const TryOnState());
  final Dio _dio;

  Future<void> generate({
    required Uint8List personImageBytes,
    required String    clothingItemId,
  }) async {
    state = const TryOnState(status: TryOnStatus.loading);
    try {
      final form = FormData.fromMap({
        'person_image':      MultipartFile.fromBytes(personImageBytes, filename: 'person.jpg'),
        'clothing_item_id':  clothingItemId,
      });
      final resp = await _dio.post<Map<String, dynamic>>('/tryon', data: form);
      state = TryOnState(status: TryOnStatus.done, resultUrl: resp.data!['result_url']);
    } catch (e) {
      state = TryOnState(status: TryOnStatus.error, errorMessage: e.toString());
    }
  }

  void reset() => state = const TryOnState();
}

final tryOnProvider = StateNotifierProvider<TryOnNotifier, TryOnState>(
  (ref) => TryOnNotifier(ref.watch(apiClientProvider)),
);
```

#### Capture Preview Dialog — Add "AI Try-On" Button

```dart
// In _CapturePreviewDialog, add to the action row:
Consumer(builder: (context, ref, _) {
  final state = ref.watch(tryOnProvider);
  return ElevatedButton.icon(
    icon: state.status == TryOnStatus.loading
        ? const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.auto_awesome),
    label: Text(state.status == TryOnStatus.loading ? 'Processing…' : 'AI Try-On'),
    onPressed: state.status == TryOnStatus.loading ? null : () async {
      // Pick a garment to try on (show picker if multiple)
      final item = await _pickGarment(context, ref);
      if (item == null) return;
      await ref.read(tryOnProvider.notifier).generate(
        personImageBytes: widget.pngBytes,
        clothingItemId: item.id,
      );
      // When done, navigate to result screen
      if (context.mounted) {
        final url = ref.read(tryOnProvider).resultUrl;
        if (url != null) context.pushNamed(AppRoute.tryOnResult.name, extra: url);
      }
    },
  );
}),
```

**New Screen**: `lib/features/tryon_result/tryon_result_screen.dart`

```dart
class TryOnResultScreen extends StatelessWidget {
  const TryOnResultScreen({super.key, required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('AI Try-On Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _share(imageUrl),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
```

#### App Route

```dart
// app_routes.dart
tryOnResult('/tryon-result'),

// app_router.dart
GoRoute(
  path: AppRoute.tryOnResult.path,
  name: AppRoute.tryOnResult.name,
  parentNavigatorKey: _rootNavigatorKey,
  builder: (_, state) => TryOnResultScreen(imageUrl: state.extra as String),
),
```

---

## Implementation Order

```
Week 1 — Live Preview Phase 1
  Day 1: Extend PoseDetectionService (elbow, wrist, nose)
  Day 2: Implement arm/neck erase paths in painter
  Day 3: Add shoulder-angle skew, test on device
  Day 4: Tune arm width, neck ellipse size, gradient softness
  Day 5: Edge-case testing (side view, arms raised, close/far)

Week 2 — Live Preview Phase 2
  Day 1–2: SegmentationService + throttled integration
  Day 3–4: Mask → screen coordinate mapping + precision erase
  Day 5: Performance profiling, ensure ≥ 30fps on mid-range Android

Week 3 — AI Try-On
  Day 1: Sign up fashn.ai, test API with Postman
  Day 2: Backend endpoint + config
  Day 3: Flutter provider + capture dialog button
  Day 4: Result screen + share flow
  Day 5: Loading UX (animated shimmer while waiting), error handling
```

---

## Key Decisions / Tradeoffs

| Decision | Choice | Reason |
|---|---|---|
| Erase method | `BlendMode.dstOut` | No camera frame decode needed, zero extra cost |
| Segmentation throttle | Same as pose (15fps) | Runs concurrently, both off main thread |
| Arm path style | Capsule (rounded rect) | Looks natural, handles bent arms |
| Erase edge | Radial gradient alpha | Soft blend, no hard cutout border |
| VTON API | fashn.ai primary | REST, fast, pay-per-use, no GPU needed |
| VTON garment category | Sent from `ClothingItem.type` | Top → "tops", bottom → "bottoms", etc. |

---

## Notes

- The `canvas.saveLayer` call is essential. Without it, `BlendMode.dstOut` erases pixels from the `CameraPreview` widget itself, not from the garment layer.
- Arm path width (`shoulderSpan * 0.18`) is a starting value — tune on device for best results.
- The neck ellipse intentionally overlaps the collar area so the collar appears to wrap naturally.
- For Phase 2, never run segmentation AND pose on the same frame if the device is struggling — detect frame drop and skip segmentation ticks.
- fashn.ai free tier allows enough calls for development/testing. Move to paid for production.
