import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/style_profile.dart';

class StyleProfileNotifier extends AsyncNotifier<StyleProfile?> {
  @override
  Future<StyleProfile?> build() => _fetch();

  Future<StyleProfile?> _fetch() async {
    try {
      final dio = ref.read(apiClientProvider);
      final res = await dio.get<Map<String, dynamic>>('users/me/style-profile');
      return StyleProfile.fromJson(res.data!);
    } catch (_) {
      return null;
    }
  }

  Future<void> patchProfile(Map<String, dynamic> data) async {
    final dio = ref.read(apiClientProvider);
    final res = await dio.patch<Map<String, dynamic>>('users/me/style-profile', data: data);
    state = AsyncData(StyleProfile.fromJson(res.data!));
  }

  Future<void> logInteraction({
    required String action,
    List<String>? clothingItemIds,
    String? outfitId,
  }) async {
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post<void>('interactions', data: {
        'action': action,
        'clothing_item_ids': clothingItemIds,
        'outfit_id': outfitId,
      });
    } catch (_) {
      // Interaction logging is best-effort — don't surface errors to the user
    }
  }
}

final styleProfileProvider = AsyncNotifierProvider<StyleProfileNotifier, StyleProfile?>(() {
  return StyleProfileNotifier();
});
