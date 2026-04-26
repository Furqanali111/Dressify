import 'package:flutter/material.dart';

/// Temporary in-memory mock data. Delete once the backend client + Riverpod
/// providers replace it. All shapes are intentionally lightweight (plain
/// classes, no freezed) to avoid coupling to a model layer that's still TBD.

enum AvatarKind {
  femaleSlim,
  femaleAthletic,
  femaleAverage,
  femaleCurvy,
  femalePlus,
  maleSlim,
  maleAthletic,
  maleAverage,
  maleCurvy,
  malePlus,
}

extension AvatarKindX on AvatarKind {
  String get label {
    switch (this) {
      case AvatarKind.femaleSlim:
        return 'Slim (F)';
      case AvatarKind.femaleAthletic:
        return 'Athletic (F)';
      case AvatarKind.femaleAverage:
        return 'Average (F)';
      case AvatarKind.femaleCurvy:
        return 'Curvy (F)';
      case AvatarKind.femalePlus:
        return 'Plus (F)';
      case AvatarKind.maleSlim:
        return 'Slim (M)';
      case AvatarKind.maleAthletic:
        return 'Athletic (M)';
      case AvatarKind.maleAverage:
        return 'Average (M)';
      case AvatarKind.maleCurvy:
        return 'Curvy (M)';
      case AvatarKind.malePlus:
        return 'Plus (M)';
    }
  }

  Color get accent {
    switch (this) {
      case AvatarKind.femaleSlim:
      case AvatarKind.maleSlim:
        return const Color(0xFF8E85FF);
      case AvatarKind.femaleAthletic:
      case AvatarKind.maleAthletic:
        return const Color(0xFF63B4FF);
      case AvatarKind.femaleAverage:
      case AvatarKind.maleAverage:
        return const Color(0xFFFF8FA3);
      case AvatarKind.femaleCurvy:
      case AvatarKind.maleCurvy:
        return const Color(0xFFFFB266);
      case AvatarKind.femalePlus:
      case AvatarKind.malePlus:
        return const Color(0xFF66D9A8);
    }
  }
  
  String get assetPath {
    switch (this) {
      case AvatarKind.femaleSlim: return 'assets/avatars/02_avatar_slim_female.png';
      case AvatarKind.femaleAthletic: return 'assets/avatars/02_avatar_athletic_female.png';
      case AvatarKind.femaleAverage: return 'assets/avatars/02_avatar_average_female.png';
      case AvatarKind.femaleCurvy: return 'assets/avatars/02_avatar_curvy_female.png';
      case AvatarKind.femalePlus: return 'assets/avatars/02_avatar_plus_female.png';
      case AvatarKind.maleSlim: return 'assets/avatars/02_avatar_slim_male.png';
      case AvatarKind.maleAthletic: return 'assets/avatars/02_avatar_athletic_male.png';
      case AvatarKind.maleAverage: return 'assets/avatars/02_avatar_average_male.png';
      case AvatarKind.maleCurvy: return 'assets/avatars/02_avatar_curvy_male.png';
      case AvatarKind.malePlus: return 'assets/avatars/02_avatar_plus_male.png';
    }
  }
}

enum ClothingType { top, bottom, dress, jacket, shoes, accessory, other }

extension ClothingTypeX on ClothingType {
  String get label {
    switch (this) {
      case ClothingType.top:
        return 'Top';
      case ClothingType.bottom:
        return 'Bottom';
      case ClothingType.dress:
        return 'Dress';
      case ClothingType.jacket:
        return 'Jacket';
      case ClothingType.shoes:
        return 'Shoes';
      case ClothingType.accessory:
        return 'Accessory';
      case ClothingType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ClothingType.top:
        return Icons.checkroom;
      case ClothingType.bottom:
        return Icons.dry_cleaning;
      case ClothingType.dress:
        return Icons.woman_2;
      case ClothingType.jacket:
        return Icons.ac_unit;
      case ClothingType.shoes:
        return Icons.directions_run;
      case ClothingType.accessory:
        return Icons.watch;
      case ClothingType.other:
        return Icons.label_outline;
    }
  }
}

class MockClothingItem {
  const MockClothingItem({
    required this.id,
    required this.name,
    required this.type,
    required this.swatch,
    this.processingStatus = 'completed',
  });

  final String id;
  final String name;
  final ClothingType type;
  final Color swatch;
  final String processingStatus;
}

class MockOutfit {
  const MockOutfit({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.aiRating,
    required this.avatar,
    required this.itemIds,
  });

  final String id;
  final String name;
  final DateTime savedAt;
  final double? aiRating;
  final AvatarKind avatar;
  final List<String> itemIds;
}

class MockData {
  const MockData._();

  static const List<MockClothingItem> clothing = <MockClothingItem>[
    MockClothingItem(
      id: 'c1',
      name: 'Navy Crew Tee',
      type: ClothingType.top,
      swatch: Color(0xFF1F2A55),
    ),
    MockClothingItem(
      id: 'c2',
      name: 'Cream Knit',
      type: ClothingType.top,
      swatch: Color(0xFFF1E4C6),
    ),
    MockClothingItem(
      id: 'c3',
      name: 'Slim Black Jeans',
      type: ClothingType.bottom,
      swatch: Color(0xFF111122),
      processingStatus: 'processing',
    ),
    MockClothingItem(
      id: 'c4',
      name: 'Olive Chinos',
      type: ClothingType.bottom,
      swatch: Color(0xFF6B7A3E),
    ),
    MockClothingItem(
      id: 'c5',
      name: 'Linen Summer Dress',
      type: ClothingType.dress,
      swatch: Color(0xFFE7C9B5),
    ),
    MockClothingItem(
      id: 'c6',
      name: 'Wool Overcoat',
      type: ClothingType.jacket,
      swatch: Color(0xFF3F4146),
    ),
  ];

  static List<MockOutfit> outfits() => <MockOutfit>[
        MockOutfit(
          id: 'o1',
          name: 'Casual Weekend',
          savedAt: DateTime(2026, 4, 22),
          aiRating: 8.2,
          avatar: AvatarKind.femaleAthletic,
          itemIds: const <String>['c1', 'c3'],
        ),
        MockOutfit(
          id: 'o2',
          name: 'Coffee Run',
          savedAt: DateTime(2026, 4, 18),
          aiRating: 7.4,
          avatar: AvatarKind.femaleAverage,
          itemIds: const <String>['c2', 'c4'],
        ),
        MockOutfit(
          id: 'o3',
          name: 'Sunday Brunch',
          savedAt: DateTime(2026, 4, 12),
          aiRating: 9.1,
          avatar: AvatarKind.femaleCurvy,
          itemIds: const <String>['c5'],
        ),
      ];
}
