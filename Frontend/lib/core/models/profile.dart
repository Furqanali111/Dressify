class Profile {
  final String id;
  final String userId;
  final double? heightCm;
  final double? weightKg;
  final String? bodyType;
  final String? gender;
  final String? avatarKind;
  final Map<String, dynamic>? preferences;
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
    required this.createdAt,
    required this.updatedAt,
  });

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
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
