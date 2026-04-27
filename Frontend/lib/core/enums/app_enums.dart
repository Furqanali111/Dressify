import 'package:flutter/material.dart';

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

  static Color accentForKind(String kind, {required Color fallback}) {
    try {
      return AvatarKind.values.firstWhere((AvatarKind e) => e.name == kind).accent;
    } catch (_) {
      return fallback;
    }
  }

  String get assetPath {
    switch (this) {
      case AvatarKind.femaleSlim:
        return 'assets/avatars/02_avatar_slim_female.png';
      case AvatarKind.femaleAthletic:
        return 'assets/avatars/02_avatar_athletic_female.png';
      case AvatarKind.femaleAverage:
        return 'assets/avatars/02_avatar_average_female.png';
      case AvatarKind.femaleCurvy:
        return 'assets/avatars/02_avatar_curvy_female.png';
      case AvatarKind.femalePlus:
        return 'assets/avatars/02_avatar_plus_female.png';
      case AvatarKind.maleSlim:
        return 'assets/avatars/02_avatar_slim_male.png';
      case AvatarKind.maleAthletic:
        return 'assets/avatars/02_avatar_athletic_male.png';
      case AvatarKind.maleAverage:
        return 'assets/avatars/02_avatar_average_male.png';
      case AvatarKind.maleCurvy:
        return 'assets/avatars/02_avatar_curvy_male.png';
      case AvatarKind.malePlus:
        return 'assets/avatars/02_avatar_plus_male.png';
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
