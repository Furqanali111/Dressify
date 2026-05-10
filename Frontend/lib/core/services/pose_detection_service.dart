import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Wraps Google ML Kit PoseDetector for live camera feed processing.
///
/// Call [processFrame] from a camera image stream callback.
/// Call [dispose] when the screen is torn down.
///
/// Coordinate contract
/// ───────────────────
/// [processFrame] returns anchors with values already **normalized to [0, 1]**
/// relative to the display area (accounting for sensor rotation and front-camera
/// mirroring).  The painter simply multiplies by `displaySize.width / height`
/// to get pixel positions — no extra platform-specific math needed at the call site.
class PoseDetectionService {
  PoseDetectionService()
      : _detector = PoseDetector(
          options: PoseDetectorOptions(
            mode: PoseDetectionMode.stream,
            model: PoseDetectionModel.base,
          ),
        );

  final PoseDetector _detector;
  bool _busy = false;
  bool _isClosed = false;

  // Reused across frames to avoid per-frame GC on Android NV21 plane concat.
  Uint8List? _nv21Buffer;

  /// Process one [CameraImage] frame.
  ///
  /// Returns a map of named anchors (normalized 0–1) or `null` when:
  ///   - the service is disposed,
  ///   - a previous frame is still being processed, or
  ///   - no pose is found in the image.
  Future<Map<String, NormAnchor>?> processFrame({
    required CameraImage image,
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
    required CameraLensDirection lensDirection,
  }) async {
    if (_busy || _isClosed) return null;
    _busy = true;

    try {
      final InputImage? inputImage = _toInputImage(
        image: image,
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        lensDirection: lensDirection,
      );
      if (inputImage == null) return null;

      final List<Pose> poses = await _detector.processImage(inputImage);
      if (poses.isEmpty || _isClosed) return null;

      return _extractAnchors(
        pose: poses.first,
        image: image,
        sensorOrientation: sensorOrientation,
        lensDirection: lensDirection,
      );
    } catch (e) {
      // If we caught an error because the detector closed during processing (hot reload),
      // just return null gracefully.
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() {
    _isClosed = true;
    return _detector.close();
  }

  // ---------------------------------------------------------------------------
  // InputImage construction
  // ---------------------------------------------------------------------------

  InputImage? _toInputImage({
    required CameraImage image,
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
    required CameraLensDirection lensDirection,
  }) {
    final InputImageRotation? rotation = _computeRotation(
      sensorOrientation: sensorOrientation,
      deviceOrientation: deviceOrientation,
      lensDirection: lensDirection,
    );
    if (rotation == null) return null;

    final InputImageFormat format =
        Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;

    final Uint8List bytes;
    if (Platform.isAndroid) {
      // NV21: concatenate all planes into a reused buffer to avoid per-frame
      // GC pressure from temporary WriteBuffer allocations.
      final int totalBytes =
          image.planes.fold(0, (int s, Plane p) => s + p.bytes.length);
      if (_nv21Buffer == null || _nv21Buffer!.length != totalBytes) {
        _nv21Buffer = Uint8List(totalBytes);
      }
      int offset = 0;
      for (final Plane p in image.planes) {
        _nv21Buffer!.setRange(offset, offset + p.bytes.length, p.bytes);
        offset += p.bytes.length;
      }
      bytes = _nv21Buffer!;
    } else {
      // iOS BGRA8888: single plane
      if (image.planes.isEmpty) return null;
      bytes = image.planes.first.bytes;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _computeRotation({
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
    required CameraLensDirection lensDirection,
  }) {
    // Device-orientation-to-degrees map
    final int deviceDeg = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };

    final int rawRotation = lensDirection == CameraLensDirection.front
        ? (sensorOrientation + deviceDeg) % 360
        : (sensorOrientation - deviceDeg + 360) % 360;

    return InputImageRotationValue.fromRawValue(rawRotation);
  }

  // ---------------------------------------------------------------------------
  // Anchor extraction + normalization
  // ---------------------------------------------------------------------------

  Map<String, NormAnchor>? _extractAnchors({
    required Pose pose,
    required CameraImage image,
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
  }) {
    // After applying rotation, the "effective" image size seen by ML Kit may
    // swap width and height (sensor is landscape, display is portrait).
    final bool swapAxes = sensorOrientation == 90 || sensorOrientation == 270;
    final double imgW =
        swapAxes ? image.height.toDouble() : image.width.toDouble();
    final double imgH =
        swapAxes ? image.width.toDouble() : image.height.toDouble();

    // Normalized landmark position with likelihood gate.
    NormAnchor? lm(PoseLandmarkType type) {
      final PoseLandmark? l = pose.landmarks[type];
      if (l == null || l.likelihood < 0.45) return null;
      double nx = l.x / imgW;
      double ny = l.y / imgH;
      // Mirror X for front camera so overlay matches what the user sees.
      if (lensDirection == CameraLensDirection.front) nx = 1.0 - nx;
      return NormAnchor(nx, ny);
    }

    final NormAnchor? ls = lm(PoseLandmarkType.leftShoulder);
    final NormAnchor? rs = lm(PoseLandmarkType.rightShoulder);
    final NormAnchor? lh = lm(PoseLandmarkType.leftHip);
    final NormAnchor? rh = lm(PoseLandmarkType.rightHip);
    final NormAnchor? lk = lm(PoseLandmarkType.leftKnee);
    final NormAnchor? rk = lm(PoseLandmarkType.rightKnee);
    final NormAnchor? la = lm(PoseLandmarkType.leftAnkle);
    final NormAnchor? ra = lm(PoseLandmarkType.rightAnkle);

    final Map<String, NormAnchor> anchors = <String, NormAnchor>{};

    // ── Shoulder ──────────────────────────────────────────────────────────
    final NormAnchor? shoulder = _mid(ls, rs) ?? ls ?? rs;
    if (shoulder != null) anchors['shoulder'] = shoulder;
    // Export individual shoulders so the painter can compute actual horizontal width.
    if (ls != null) anchors['leftShoulder'] = ls;
    if (rs != null) anchors['rightShoulder'] = rs;

    // ── Arms + Nose (for arm/neck occlusion in overlay painter) ──────────────
    final NormAnchor? le   = lm(PoseLandmarkType.leftElbow);
    final NormAnchor? re   = lm(PoseLandmarkType.rightElbow);
    final NormAnchor? lw   = lm(PoseLandmarkType.leftWrist);
    final NormAnchor? rw   = lm(PoseLandmarkType.rightWrist);
    final NormAnchor? nose = lm(PoseLandmarkType.nose);
    if (le != null)   anchors['leftElbow']  = le;
    if (re != null)   anchors['rightElbow'] = re;
    if (lw != null)   anchors['leftWrist']  = lw;
    if (rw != null)   anchors['rightWrist'] = rw;
    if (nose != null) anchors['nose']       = nose;

    // ── Hip ───────────────────────────────────────────────────────────────
    final NormAnchor? hip = _mid(lh, rh) ?? lh ?? rh;
    if (hip != null) anchors['hip'] = hip;
    if (lh != null) anchors['leftHip']  = lh;
    if (rh != null) anchors['rightHip'] = rh;

    // ── Chest + Waist (interpolated between shoulder and hip) ─────────────
    if (shoulder != null && hip != null) {
      anchors['chest'] = _lerp(shoulder, hip, 0.30);
      anchors['waist'] = _lerp(shoulder, hip, 0.68);
    } else if (shoulder != null) {
      // Estimate from shoulder alone with typical body proportions
      anchors['chest'] = NormAnchor(shoulder.x, shoulder.y + 0.06);
      anchors['waist'] = NormAnchor(shoulder.x, shoulder.y + 0.14);
    }

    // ── Knees ─────────────────────────────────────────────────────────────
    if (lk != null) anchors['leftKnee']  = lk;
    if (rk != null) anchors['rightKnee'] = rk;

    // ── Feet ──────────────────────────────────────────────────────────────
    final NormAnchor? feet = _mid(la, ra) ?? la ?? ra;
    if (feet != null) anchors['feet'] = feet;
    if (la != null) anchors['leftAnkle']  = la;
    if (ra != null) anchors['rightAnkle'] = ra;

    return anchors.isEmpty ? null : anchors;
  }

  static NormAnchor? _mid(NormAnchor? a, NormAnchor? b) {
    if (a == null || b == null) return null;
    return NormAnchor((a.x + b.x) / 2, (a.y + b.y) / 2);
  }

  static NormAnchor _lerp(NormAnchor a, NormAnchor b, double t) =>
      NormAnchor(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
}

/// Normalized (0–1) anchor coordinate.
class NormAnchor {
  const NormAnchor(this.x, this.y);
  final double x;
  final double y;
}
