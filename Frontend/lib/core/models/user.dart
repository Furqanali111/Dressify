class User {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
