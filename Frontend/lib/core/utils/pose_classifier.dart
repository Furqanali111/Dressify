import 'dart:math' as math;

import '../services/pose_detection_service.dart';

/// Maps the current set of body landmarks to one of the 8 canonical pose
/// labels defined in wrinkle_pose_catalog.md.
///
/// All inputs are [NormAnchor] values in normalised 0-1 image coordinates.
/// The output is a pose label string matching a key in the wrinkle map dict.
class PoseClassifier {
  PoseClassifier._();

  static const List<String> poses = <String>[
    'arms_down',
    'arms_45',
    'arms_90',
    'lean_left_15',
    'lean_right_15',
    'seated',
    'one_arm_raised',
    'crossed_arms',
  ];

  /// Returns the canonical pose label for the given landmark map.
  /// Falls back to 'arms_down' when insufficient landmarks are available.
  static String classify(Map<String, NormAnchor> a) {
    final NormAnchor? ls = a['leftShoulder'];
    final NormAnchor? rs = a['rightShoulder'];
    final NormAnchor? lh = a['leftHip'];
    final NormAnchor? rh = a['rightHip'];
    final NormAnchor? le = a['leftElbow'];
    final NormAnchor? re = a['rightElbow'];
    final NormAnchor? lw = a['leftWrist'];
    final NormAnchor? rw = a['rightWrist'];
    final NormAnchor? lk = a['leftKnee'];
    final NormAnchor? rk = a['rightKnee'];

    // 1. Crossed arms: wrists close together near the chest
    if (ls != null && rs != null && lw != null && rw != null) {
      final double wristDist = (lw.x - rw.x).abs();
      final double midX = (ls.x + rs.x) / 2;
      final double avgWristY = (lw.y + rw.y) / 2;
      final double shoulderY = (ls.y + rs.y) / 2;
      final bool wristsClose = wristDist < 0.22;
      final bool wristsAtChest =
          avgWristY > shoulderY && avgWristY < shoulderY + 0.30;
      final bool wristsNearMid =
          (lw.x - midX).abs() < 0.20 && (rw.x - midX).abs() < 0.20;
      if (wristsClose && wristsAtChest && wristsNearMid) {
        return 'crossed_arms';
      }
    }

    // 2. Seated: knees near hip vertical level
    if (lh != null && rh != null && lk != null && rk != null) {
      final double hipY = (lh.y + rh.y) / 2;
      final double kneeY = (lk.y + rk.y) / 2;
      if ((kneeY - hipY).abs() < 0.12) return 'seated';
    }

    // 3. Torso lean from shoulder axis
    double torsoDeg = 0;
    if (ls != null && rs != null) {
      // positive = left shoulder higher → leaning left
      torsoDeg = math.atan2(rs.y - ls.y, rs.x - ls.x) * 180 / math.pi;
    }
    if (torsoDeg > 12) return 'lean_left_15';
    if (torsoDeg < -12) return 'lean_right_15';

    // 4. Shoulder abduction angles
    final double leftAbd = (ls != null && lh != null && le != null)
        ? _abductionAngle(ls, lh, le)
        : 0;
    final double rightAbd = (rs != null && rh != null && re != null)
        ? _abductionAngle(rs, rh, re)
        : 0;

    // 5. One arm raised: large asymmetry
    if ((leftAbd - rightAbd).abs() > 45 &&
        math.max(leftAbd, rightAbd) > 70) {
      return 'one_arm_raised';
    }

    final double maxAbd = math.max(leftAbd, rightAbd);
    if (maxAbd > 70) return 'arms_90';
    if (maxAbd > 35) return 'arms_45';
    return 'arms_down';
  }

  /// Angle (degrees) between the body-down axis (shoulder→hip) and the arm
  /// axis (shoulder→elbow). 0° = arm along torso, 90° = arm horizontal.
  static double _abductionAngle(
    NormAnchor shoulder,
    NormAnchor hip,
    NormAnchor elbow,
  ) {
    final double bdx = hip.x - shoulder.x;
    final double bdy = hip.y - shoulder.y;
    final double adx = elbow.x - shoulder.x;
    final double ady = elbow.y - shoulder.y;
    final double bLen = math.sqrt(bdx * bdx + bdy * bdy);
    final double aLen = math.sqrt(adx * adx + ady * ady);
    if (bLen < 0.001 || aLen < 0.001) return 0;
    final double cosA = ((bdx * adx + bdy * ady) / (bLen * aLen))
        .clamp(-1.0, 1.0);
    return math.acos(cosA) * 180 / math.pi;
  }
}
