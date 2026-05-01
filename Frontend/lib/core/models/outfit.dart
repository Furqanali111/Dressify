class OutfitItem {
  final String clothingItemId;
  final Map<String, dynamic>? position;

  const OutfitItem({
    required this.clothingItemId,
    this.position,
  });

  factory OutfitItem.fromJson(Map<String, dynamic> json) {
    return OutfitItem(
      clothingItemId: json['clothing_item_id'] as String,
      position: json['position'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'clothing_item_id': clothingItemId,
        'position': position,
      };
}

class Outfit {
  final String id;
  final String userId;
  final String name;
  final String avatarKind;
  final List<OutfitItem> items;
  final DateTime createdAt;
  final bool personalized;

  const Outfit({
    required this.id,
    required this.userId,
    required this.name,
    required this.avatarKind,
    this.items = const [],
    required this.createdAt,
    this.personalized = false,
  });

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      avatarKind: json['avatar_kind'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OutfitItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      personalized: json['personalized'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'avatar_kind': avatarKind,
        'items': items.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}
