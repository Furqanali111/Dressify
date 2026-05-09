import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class LuminanceSampler {
  /// Samples the average luminance (0.0 to 1.0) of a [CameraImage] within
  /// a normalized [region] (values from 0.0 to 1.0 representing percentage of width/height).
  static double sample(CameraImage image, Rect region) {
    final int width = image.width;
    final int height = image.height;

    // Convert normalized region to pixel coordinates
    final int left = (region.left * width).clamp(0, width - 1).toInt();
    final int top = (region.top * height).clamp(0, height - 1).toInt();
    final int right = (region.right * width).clamp(0, width - 1).toInt();
    final int bottom = (region.bottom * height).clamp(0, height - 1).toInt();

    final int sampleWidth = right - left;
    final int sampleHeight = bottom - top;

    if (sampleWidth <= 0 || sampleHeight <= 0) return 0.5;

    // Step size to roughly sample a maximum of 20x20 pixels
    final int stepX = (sampleWidth / 20).ceil().clamp(1, sampleWidth);
    final int stepY = (sampleHeight / 20).ceil().clamp(1, sampleHeight);

    int sumLuma = 0;
    int count = 0;

    if (image.format.group == ImageFormatGroup.nv21 ||
        image.format.group == ImageFormatGroup.yuv420) {
      // Y plane is planes[0], 1 byte per pixel
      final Uint8List yPlane = image.planes[0].bytes;
      final int rowStride = image.planes[0].bytesPerRow;

      for (int y = top; y < bottom; y += stepY) {
        final int rowOffset = y * rowStride;
        for (int x = left; x < right; x += stepX) {
          sumLuma += yPlane[rowOffset + x];
          count++;
        }
      }
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      // BGRA format: B, G, R, A bytes
      final Uint8List bytes = image.planes[0].bytes;
      final int rowStride = image.planes[0].bytesPerRow;
      final int pixelStride = image.planes[0].bytesPerPixel ?? 4;

      for (int y = top; y < bottom; y += stepY) {
        final int rowOffset = y * rowStride;
        for (int x = left; x < right; x += stepX) {
          final int p = rowOffset + x * pixelStride;
          if (p + 2 >= bytes.length) continue;
          // Perceived luminance: ~ 0.3 R + 0.59 G + 0.11 B
          // BGRA: B = p, G = p+1, R = p+2
          final int b = bytes[p];
          final int g = bytes[p + 1];
          final int r = bytes[p + 2];
          final int luma = (0.299 * r + 0.587 * g + 0.114 * b).round();
          sumLuma += luma;
          count++;
        }
      }
    } else {
      // Unsupported format
      return 0.5;
    }

    if (count == 0) return 0.5;

    final double avgLuma = sumLuma / count;
    return (avgLuma / 255.0).clamp(0.0, 1.0);
  }
}
