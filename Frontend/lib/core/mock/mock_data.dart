import 'package:flutter/material.dart';

/// Temporary in-memory mock data. Delete once the backend client + Riverpod
/// providers replace it. All shapes are intentionally lightweight (plain
/// classes, no freezed) to avoid coupling to a model layer that's still TBD.

enum AvatarKind { slim, athletic, average, curvy, plus }

extension AvatarKindX on AvatarKind {
  String get label {
    switch (this) {
      case AvatarKind.slim:
        return 'Slim';
      case AvatarKind.athletic:
        return 'Athletic';
      case AvatarKind.average:
        return 'Average';
      case AvatarKind.curvy:
        return 'Curvy';
      case AvatarKind.plus:
        return 'Plus';
    }
  }

  Color get accent {
    switch (this) {
      case AvatarKind.slim:
        return const Color(0xFF8E85FF);
      case AvatarKind.athletic:
        return const Color(0xFF63B4FF);
      case AvatarKind.average:
        return const Color(0xFFFF8FA3);
      case AvatarKind.curvy:
        return const Color(0xFFFFB266);
      case AvatarKind.plus:
        return const Color(0xFF66D9A8);
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
  });

  final String id;
  final String name;
  final ClothingType type;
  final Color swatch;
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
          avatar: AvatarKind.athletic,
          itemIds: const <String>['c1', 'c3'],
        ),
        MockOutfit(
          id: 'o2',
          name: 'Coffee Run',
          savedAt: DateTime(2026, 4, 18),
          aiRating: 7.4,
          avatar: AvatarKind.average,
          itemIds: const <String>['c2', 'c4'],
        ),
        MockOutfit(
          id: 'o3',
          name: 'Sunday Brunch',
          savedAt: DateTime(2026, 4, 12),
          aiRating: 9.1,
          avatar: AvatarKind.curvy,
          itemIds: const <String>['c5'],
        ),
      ];
}
