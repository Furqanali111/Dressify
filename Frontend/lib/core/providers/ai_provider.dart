import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/ai_feedback.dart';
import '../models/outfit.dart';

final aiProvider = Provider<AiService>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AiService(dio);
});

class AiService {
  final Dio _dio;

  AiService(this._dio);

  Future<Outfit> generateOutfit({
    required String occasion,
    String? avatarKind,
    double? lat,
    double? lon,
    String? seedItemId,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/outfits/generate',
      data: <String, dynamic>{
        'occasion': occasion,
        'avatar_kind': ?avatarKind,
        'lat': ?lat,
        'lon': ?lon,
        'seed_item_id': ?seedItemId,
      },
      cancelToken: cancelToken,
    );
    return Outfit.fromJson(response.data!);
  }

  Future<AiFeedbackResponse> generateFeedback({
    String? outfitId,
    List<String>? clothingItemIds,
    String? occasion,
    double? lat,
    double? lon,
  }) async {
    assert(outfitId != null || (clothingItemIds != null && clothingItemIds.isNotEmpty),
        'Must provide either outfitId or clothingItemIds');

    final response = await _dio.post<Map<String, dynamic>>(
      '/feedback',
      data: {
        'outfit_id': ?outfitId,
        'clothing_item_ids': ?clothingItemIds,
        'occasion': ?occasion,
        'lat': ?lat,
        'lon': ?lon,
      },
    );
    return AiFeedbackResponse.fromJson(response.data!);
  }
}
