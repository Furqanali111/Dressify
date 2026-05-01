class StyleProfile {
  final String userId;
  final List<String> likedColors;
  final List<String> likedStyles;
  final List<String> likedPatterns;
  final List<String> dislikedStyles;
  final DateTime? updatedAt;

  const StyleProfile({
    required this.userId,
    this.likedColors = const [],
    this.likedStyles = const [],
    this.likedPatterns = const [],
    this.dislikedStyles = const [],
    this.updatedAt,
  });

  bool get hasPreferences =>
      likedColors.isNotEmpty ||
      likedStyles.isNotEmpty ||
      likedPatterns.isNotEmpty ||
      dislikedStyles.isNotEmpty;

  factory StyleProfile.fromJson(Map<String, dynamic> json) => StyleProfile(
        userId:         json['user_id'] as String,
        likedColors:    List<String>.from(json['liked_colors']    as List? ?? []),
        likedStyles:    List<String>.from(json['liked_styles']    as List? ?? []),
        likedPatterns:  List<String>.from(json['liked_patterns']  as List? ?? []),
        dislikedStyles: List<String>.from(json['disliked_styles'] as List? ?? []),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'liked_colors':    likedColors,
        'liked_styles':    likedStyles,
        'liked_patterns':  likedPatterns,
        'disliked_styles': dislikedStyles,
      };

  StyleProfile copyWith({
    List<String>? likedColors,
    List<String>? likedStyles,
    List<String>? likedPatterns,
    List<String>? dislikedStyles,
  }) =>
      StyleProfile(
        userId:         userId,
        likedColors:    likedColors    ?? this.likedColors,
        likedStyles:    likedStyles    ?? this.likedStyles,
        likedPatterns:  likedPatterns  ?? this.likedPatterns,
        dislikedStyles: dislikedStyles ?? this.dislikedStyles,
        updatedAt:      updatedAt,
      );
}
