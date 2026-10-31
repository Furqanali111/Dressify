class Profile {
  final String id;
  final String userId;
  final double? heightCm;
  final double? weightKg;
  final String? bodyType;
  final String? gender;
  final String? avatarKind;
  final Map<String, dynamic>? preferences;
  // Phase 4.1 — body measurements
  final double? chestCm;
  final double? waistCm;
  final double? hipCm;
  final double? shoulderCm;
  // Computed by backend: scale factor per garment category
  final double fitScaleTop;
  final double fitScaleBottom;
  final double fitScaleDress;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.userId,
    this.heightCm,
    this.weightKg,
    this.bodyType,
    this.gender,
    this.avatarKind,
    this.preferences,
    this.chestCm,
    this.waistCm,
    this.hipCm,
    this.shoulderCm,
    this.fitScaleTop = 1.0,
    this.fitScaleBottom = 1.0,
    this.fitScaleDress = 1.0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasMeasurements =>
      chestCm != null || waistCm != null || hipCm != null || shoulderCm != null;

  bool get isFitPersonalized =>
      fitScaleTop != 1.0 || fitScaleBottom != 1.0 || fitScaleDress != 1.0;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      bodyType: json['body_type'] as String?,
      gender: json['gender'] as String?,
      avatarKind: json['avatar_kind'] as String?,
      preferences: json['preferences'] as Map<String, dynamic>?,
      chestCm: (json['chest_cm'] as num?)?.toDouble(),
      waistCm: (json['waist_cm'] as num?)?.toDouble(),
      hipCm: (json['hip_cm'] as num?)?.toDouble(),
      shoulderCm: (json['shoulder_cm'] as num?)?.toDouble(),
      fitScaleTop: (json['fit_scale_top'] as num?)?.toDouble() ?? 1.0,
      fitScaleBottom: (json['fit_scale_bottom'] as num?)?.toDouble() ?? 1.0,
      fitScaleDress: (json['fit_scale_dress'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'body_type': bodyType,
        'gender': gender,
        'avatar_kind': avatarKind,
        'preferences': preferences,
        'chest_cm': chestCm,
        'waist_cm': waistCm,
        'hip_cm': hipCm,
        'shoulder_cm': shoulderCm,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
