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
    double? lat,
    double? lon,
    String? seedItemId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/outfits/generate',
      data: {
        'occasion': occasion,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (seedItemId != null) 'seed_item_id': seedItemId,
      },
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
        if (outfitId != null) 'outfit_id': outfitId,
        if (clothingItemIds != null) 'clothing_item_ids': clothingItemIds,
        if (occasion != null) 'occasion': occasion,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
      },
    );
    return AiFeedbackResponse.fromJson(response.data!);
  }
}
