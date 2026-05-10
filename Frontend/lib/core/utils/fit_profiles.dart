/// Per-type constants that shape how a garment maps to body landmarks.
/// All ratios are relative to the shoulder span (px distance between shoulders).
class FitProfile {
  const FitProfile({
    required this.collarRiseRatio,
    required this.sleeveExtendRatio,
    required this.sleeveDropRatio,
  });

  /// How far the collar centre rises above the shoulder midpoint Y.
  final double collarRiseRatio;

  /// How far each sleeve tip extends outward beyond the shoulder landmark.
  final double sleeveExtendRatio;

  /// Vertical drop of the sleeve tip below the shoulder landmark.
  final double sleeveDropRatio;

  static const FitProfile top = FitProfile(
    collarRiseRatio: 0.32,
    sleeveExtendRatio: 0.20,
    sleeveDropRatio: 0.16,
  );

  static const FitProfile jacket = FitProfile(
    collarRiseRatio: 0.28,
    sleeveExtendRatio: 0.26,
    sleeveDropRatio: 0.22,
  );

  static const FitProfile dress = FitProfile(
    collarRiseRatio: 0.34,
    sleeveExtendRatio: 0.12,
    sleeveDropRatio: 0.10,
  );

  // Bottoms have no collar or sleeves — ratios unused, kept for type safety.
  static const FitProfile bottom = FitProfile(
    collarRiseRatio: 0.0,
    sleeveExtendRatio: 0.0,
    sleeveDropRatio: 0.0,
  );

  static FitProfile forType(String type) => switch (type) {
        'top' => top,
        'jacket' => jacket,
        'dress' => dress,
        'bottom' => bottom,
        _ => top,
      };
}
