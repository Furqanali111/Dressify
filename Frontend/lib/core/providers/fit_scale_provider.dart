import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_provider.dart';

/// Per-garment-type scale factors derived from the user's body measurements
/// vs the selected avatar's baseline proportions (computed by the backend).
class FitScales {
  const FitScales({
    this.top = 1.0,
    this.bottom = 1.0,
    this.dress = 1.0,
  });

  final double top;
  final double bottom;
  final double dress;

  bool get isPersonalized => top != 1.0 || bottom != 1.0 || dress != 1.0;

  double forType(String garmentType) {
    switch (garmentType) {
      case 'top':
      case 'jacket':
        return top;
      case 'bottom':
        return bottom;
      case 'dress':
        return dress;
      default:
        return 1.0;
    }
  }
}

/// Reads fit scale factors from the latest [profileProvider] value.
/// Returns [FitScales()] (all 1.0) when profile is absent or has no measurements.
final fitScalesProvider = Provider<FitScales>((ref) {
  final profile = ref.watch(profileProvider).value;
  if (profile == null) return const FitScales();
  return FitScales(
    top:    profile.fitScaleTop,
    bottom: profile.fitScaleBottom,
    dress:  profile.fitScaleDress,
  );
});
