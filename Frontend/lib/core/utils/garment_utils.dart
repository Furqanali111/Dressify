import 'package:flutter/material.dart';
import '../models/clothing_item.dart';

/// Which avatar anchor point a garment type snaps to.
String garmentAnchorKey(String type) => switch (type) {
      'top' || 'jacket' || 'dress' => 'shoulder',
      'bottom' => 'waist',
      'shoes' => 'feet',
      _ => 'chest',
    };

/// Normalized (0..1) position of the snap anchor within the garment image.
/// Uses backend-supplied anchorPoints when present; falls back to sensible defaults.
Offset garmentAnchorNorm(ClothingItem item) {
  final Map<String, dynamic>? ap = item.anchorPoints;
  final String key = garmentAnchorKey(item.type);
  if (ap != null && ap.containsKey(key)) {
    final Map<String, dynamic> pt = ap[key] as Map<String, dynamic>;
    return Offset(
      (pt['x'] as num? ?? 0.5).toDouble(),
      (pt['y'] as num? ?? 0.15).toDouble(),
    );
  }
  return switch (item.type) {
    'top' || 'jacket' => const Offset(0.5, 0.16),
    'dress' => const Offset(0.5, 0.12),
    'bottom' => const Offset(0.5, 0.07),
    'shoes' => const Offset(0.5, 0.10),
    _ => const Offset(0.5, 0.20),
  };
}

/// Depth ordering — lower value paints first (behind higher values).
int garmentDepth(String type) => switch (type) {
      'shoes' => 0,
      'bottom' => 1,
      'dress' => 2,
      'top' || 'jacket' => 3,
      _ => 4,
    };

/// Width of garment as fraction of avatar canvas width (used in 2-D try-on).
double garmentWidthFactor(String type) => switch (type) {
      'top' || 'jacket' || 'dress' => 0.72,
      'bottom' => 0.66,
      'shoes' => 0.52,
      _ => 0.42,
    };

/// Width multiplier relative to shoulder span (used in camera overlay).
double garmentShoulderMultiplier(String type) => switch (type) {
      'top' || 'jacket' => 1.35,
      'dress' => 1.25,
      'bottom' => 1.20,
      'shoes' => 0.55,
      _ => 0.90,
    };
