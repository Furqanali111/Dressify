import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/app_enums.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_colors.dart';

/// Renders the user's profile photo (uploaded), avatar illustration, or a
/// person-icon fallback — whichever is available — in a circular container.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = context.colors;
    final user = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final String? avatarKind = profile?.avatarKind;

    Widget child;
    if (user?.profileUrl != null) {
      child = CachedNetworkImage(
        imageUrl: user!.profileUrl!,
        cacheKey: 'profile_photo_${user.id}',
        fit: BoxFit.cover,
        placeholder: (_, _) => Icon(Icons.person, color: c.primary, size: size * 0.55),
        errorWidget: (_, _, _) => Icon(Icons.person, color: c.primary, size: size * 0.55),
      );
    } else if (avatarKind != null) {
      final AvatarKind? kind = AvatarKind.values
          .where((AvatarKind e) => e.name == avatarKind)
          .firstOrNull;
      child = kind != null
          ? Image.asset(kind.assetPath, fit: BoxFit.cover)
          : Icon(Icons.person, color: c.primary, size: size * 0.55);
    } else {
      child = Icon(Icons.person, color: c.primary, size: size * 0.55);
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}
