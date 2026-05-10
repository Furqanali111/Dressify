import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/pose_detection_service.dart';
import 'fit_profiles.dart';

/// UV-space (0–1 × 0–1) anchor positions that name which region of the
/// garment image corresponds to each body landmark.
///
/// The TPS warper maps these source UV points to screen-space target points
/// computed from body landmarks, producing a smooth, anatomically-correct
/// deformation of the garment image.
class GarmentControlPoints {
  const GarmentControlPoints(this.uvPoints);

  /// Source points in UV space [0,1]×[0,1] (image-relative).
  final List<Offset> uvPoints;

  // ── Per-type UV definitions ───────────────────────────────────────────────

  static const GarmentControlPoints _top = GarmentControlPoints(<Offset>[
    Offset(0.50, 0.04), // collar centre
    Offset(0.20, 0.13), // left shoulder seam
    Offset(0.80, 0.13), // right shoulder seam
    Offset(0.02, 0.32), // left sleeve end
    Offset(0.98, 0.32), // right sleeve end
    Offset(0.22, 0.91), // left waist
    Offset(0.78, 0.91), // right waist
    Offset(0.50, 0.97), // hem centre
  ]);

  static const GarmentControlPoints _jacket = GarmentControlPoints(<Offset>[
    Offset(0.50, 0.04),
    Offset(0.18, 0.12),
    Offset(0.82, 0.12),
    Offset(0.00, 0.36),
    Offset(1.00, 0.36),
    Offset(0.20, 0.89),
    Offset(0.80, 0.89),
    Offset(0.50, 0.97),
  ]);

  static const GarmentControlPoints _dress = GarmentControlPoints(<Offset>[
    Offset(0.50, 0.04),
    Offset(0.22, 0.11),
    Offset(0.78, 0.11),
    Offset(0.04, 0.26),
    Offset(0.96, 0.26),
    Offset(0.30, 0.90),
    Offset(0.70, 0.90),
    Offset(0.50, 0.97),
  ]);

  // Bottoms: 6 points — no collar or sleeve.
  static const GarmentControlPoints _bottom = GarmentControlPoints(<Offset>[
    Offset(0.28, 0.03), // left waistband
    Offset(0.72, 0.03), // right waistband
    Offset(0.35, 0.50), // left mid-thigh
    Offset(0.65, 0.50), // right mid-thigh
    Offset(0.28, 0.97), // left ankle/hem
    Offset(0.72, 0.97), // right ankle/hem
  ]);

  static GarmentControlPoints forType(String type) => switch (type) {
        'top' => _top,
        'jacket' => _jacket,
        'dress' => _dress,
        'bottom' => _bottom,
        _ => _top,
      };

  // ── Target point computation ──────────────────────────────────────────────

  /// Returns screen-space target positions corresponding to [uvPoints], or
  /// null if the required landmarks are not present in [anchors].
  List<Offset>? computeTargets(
    String type,
    Map<String, NormAnchor> anchors,
    Size size,
    double shoulderSpan,
  ) {
    return switch (type) {
      'top' || 'jacket' || 'dress' => _targetsUpperBody(
          type, anchors, size, shoulderSpan, FitProfile.forType(type)),
      'bottom' => _targetsBottom(anchors, size),
      _ => _targetsUpperBody(
          type, anchors, size, shoulderSpan, FitProfile.forType(type)),
    };
  }

  List<Offset>? _targetsUpperBody(
    String type,
    Map<String, NormAnchor> anchors,
    Size size,
    double shoulderSpan,
    FitProfile profile,
  ) {
    final NormAnchor? ls = anchors['leftShoulder'];
    final NormAnchor? rs = anchors['rightShoulder'];
    if (ls == null || rs == null) return null;

    final double lsX = ls.x * size.width;
    final double lsY = ls.y * size.height;
    final double rsX = rs.x * size.width;
    final double rsY = rs.y * size.height;

    // Mid-shoulder point
    final double midX = (lsX + rsX) / 2;
    final double midY = (lsY + rsY) / 2;

    // Collar: rises above shoulder midpoint
    final Offset collar = Offset(midX, midY - shoulderSpan * profile.collarRiseRatio);

    // Shoulder seam landmarks
    final Offset leftShoulder = Offset(lsX, lsY);
    final Offset rightShoulder = Offset(rsX, rsY);

    // Sleeve extension: project outward along the shoulder axis from each side.
    // Normalised direction from right shoulder → left shoulder.
    final double rawDx = lsX - rsX;
    final double rawDy = lsY - rsY;
    final double len = math.sqrt(rawDx * rawDx + rawDy * rawDy);
    final double dirX = len > 1e-6 ? rawDx / len : -1.0;
    final double dirY = len > 1e-6 ? rawDy / len : 0.0;

    final double extend = shoulderSpan * profile.sleeveExtendRatio;
    final double drop = shoulderSpan * profile.sleeveDropRatio;

    // Left sleeve: in the dirX direction (away from right shoulder)
    final Offset leftSleeve = Offset(lsX + dirX * extend, lsY + dirY * extend + drop);
    // Right sleeve: opposite direction
    final Offset rightSleeve = Offset(rsX - dirX * extend, rsY - dirY * extend + drop);

    // Hip landmarks (or estimated from torso height)
    final NormAnchor? lh = anchors['leftHip'];
    final NormAnchor? rh = anchors['rightHip'];
    final double torsoEst = shoulderSpan * 1.1;

    final double lhX = lh != null ? lh.x * size.width  : lsX;
    final double lhY = lh != null ? lh.y * size.height : lsY + torsoEst;
    final double rhX = rh != null ? rh.x * size.width  : rsX;
    final double rhY = rh != null ? rh.y * size.height : rsY + torsoEst;

    final Offset leftWaist  = Offset(lhX, lhY);
    final Offset rightWaist = Offset(rhX, rhY);

    // Hem: below the hip midpoint
    final double hipMidY = (lhY + rhY) / 2;
    final double torsoActual = hipMidY - midY;
    final double hemY = hipMidY + torsoActual * 0.15;
    final Offset hem = Offset(midX, hemY);

    return <Offset>[collar, leftShoulder, rightShoulder, leftSleeve, rightSleeve, leftWaist, rightWaist, hem];
  }

  List<Offset>? _targetsBottom(Map<String, NormAnchor> anchors, Size size) {
    final NormAnchor? lh = anchors['leftHip'];
    final NormAnchor? rh = anchors['rightHip'];
    if (lh == null || rh == null) return null;

    final double lhX = lh.x * size.width;
    final double lhY = lh.y * size.height;
    final double rhX = rh.x * size.width;
    final double rhY = rh.y * size.height;

    final double hipSpan = (lhX - rhX).abs();

    // Knee: estimate 1.4× hip-span below the hips, or use landmark
    final NormAnchor? lk = anchors['leftKnee'];
    final NormAnchor? rk = anchors['rightKnee'];
    final double lkX = lk != null ? lk.x * size.width  : lhX;
    final double lkY = lk != null ? lk.y * size.height : lhY + hipSpan * 1.4;
    final double rkX = rk != null ? rk.x * size.width  : rhX;
    final double rkY = rk != null ? rk.y * size.height : rhY + hipSpan * 1.4;

    // Ankle/hem: estimate 2.6× hip-span below hips, or use landmark
    final NormAnchor? la = anchors['leftAnkle'];
    final NormAnchor? ra = anchors['rightAnkle'];
    final double laX = la != null ? la.x * size.width  : lhX;
    final double laY = la != null ? la.y * size.height : lhY + hipSpan * 2.6;
    final double raX = ra != null ? ra.x * size.width  : rhX;
    final double raY = ra != null ? ra.y * size.height : rhY + hipSpan * 2.6;

    // Mid-thigh: halfway between hip and knee
    final Offset leftMidThigh  = Offset((lhX + lkX) / 2, (lhY + lkY) / 2);
    final Offset rightMidThigh = Offset((rhX + rkX) / 2, (rhY + rkY) / 2);

    return <Offset>[
      Offset(lhX, lhY), // left waistband
      Offset(rhX, rhY), // right waistband
      leftMidThigh,
      rightMidThigh,
      Offset(laX, laY), // left ankle
      Offset(raX, raY), // right ankle
    ];
  }
}
