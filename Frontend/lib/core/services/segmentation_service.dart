import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

class SegmentationMaskResult {
  const SegmentationMaskResult({
    required this.confidences,
    required this.width,
    required this.height,
  });

  final List<double> confidences;
  final int width;
  final int height;
}

/// Wraps ML Kit SelfieSegmenter for live camera feed processing.
///
/// Runs concurrently with [PoseDetectionService] on the same throttled frame
/// callback. Returns a per-pixel confidence mask (0.0–1.0) in raw model size.
///
/// Call [dispose] when the owning screen is torn down.
class SegmentationService {
  SegmentationService()
      : _segmenter = SelfieSegmenter(
          mode: SegmenterMode.stream,
          enableRawSizeMask: true,
        );

  final SelfieSegmenter _segmenter;
  bool _busy = false;
  bool _isClosed = false;

  // Reused across frames to avoid per-frame GC on Android NV21 plane concat.
  Uint8List? _nv21Buffer;

  Future<SegmentationMaskResult?> processFrame({
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

      final SegmentationMask? mask = await _segmenter.processImage(inputImage);
      if (mask == null) return null;
      return SegmentationMaskResult(
        confidences: mask.confidences,
        width: mask.width,
        height: mask.height,
      );
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() {
    _isClosed = true;
    return _segmenter.close();
  }

  // ---------------------------------------------------------------------------
  // InputImage construction — mirrors PoseDetectionService logic exactly
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
}
