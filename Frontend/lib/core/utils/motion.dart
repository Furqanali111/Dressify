import 'package:flutter/material.dart';

extension MotionContext on BuildContext {
  /// Honors the OS-level "Reduce Motion" / "Disable Animations" accessibility
  /// preference. When true, callers should collapse animation durations to
  /// `Duration.zero` and skip oscillating effects.
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;

  /// Convenience: returns `Duration.zero` when reduce-motion is on, otherwise
  /// returns [normal]. Use as `context.motion(300.ms)`.
  Duration motion(Duration normal) => reduceMotion ? Duration.zero : normal;
}
