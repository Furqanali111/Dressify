/// App-wide constants that were previously hardcoded inline.
/// Centralising them here makes tuning easy and prevents magic-number drift.
library;

import 'dart:ui' show Color;

import 'package:camera/camera.dart';

class AppConstants {
  AppConstants._();

  // ── Camera try-on ──────────────────────────────────────────────────────────

  /// Minimum time between processed camera frames for pose detection.
  static const Duration frameThrottle = Duration(milliseconds: 250);

  /// Camera resolution used for the try-on stream.
  /// Medium balances quality vs. frame-rate on mid-range devices.
  static const ResolutionPreset cameraResolution = ResolutionPreset.medium;

  /// Timeout for decoding a remote garment image before treating it as failed.
  static const Duration imageLoadTimeout = Duration(seconds: 15);

  // ── Try-on canvas ──────────────────────────────────────────────────────────

  /// Dark canvas background colour for the 2-D avatar try-on screen.
  static const Color tryOnCanvasColor = Color(0xFF1A1A2A);

  /// How long the "Outfit saved" success toast is shown.
  static const Duration saveFeedbackDuration = Duration(seconds: 2);
}
