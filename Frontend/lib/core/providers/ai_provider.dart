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
    final Map<String, dynamic> data = <String, dynamic>{
      'occasion': occasion,
    };
    if (avatarKind != null) data['avatar_kind'] = avatarKind;
    if (lat != null) data['lat'] = lat;
    if (lon != null) data['lon'] = lon;
    if (seedItemId != null) data['seed_item_id'] = seedItemId;

    final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
      '/outfits/generate',
      data: data,
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

    final Map<String, dynamic> data = <String, dynamic>{};
    if (outfitId != null) data['outfit_id'] = outfitId;
    if (clothingItemIds != null) data['clothing_item_ids'] = clothingItemIds;
    if (occasion != null) data['occasion'] = occasion;
    if (lat != null) data['lat'] = lat;
    if (lon != null) data['lon'] = lon;

    final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
      '/feedback',
      data: data,
    );
    return AiFeedbackResponse.fromJson(response.data!);
  }
}
