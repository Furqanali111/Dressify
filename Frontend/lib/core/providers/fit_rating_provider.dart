import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

enum FitRating { perfect, mayBeSnug, runsLarge, unknown }

class FitResult {
  const FitResult({required this.rating, required this.confidence});
  final FitRating rating;
  final double confidence;

  static FitResult fromJson(Map<String, dynamic> json) {
    final r = switch (json['fit_rating'] as String? ?? '') {
      'perfect'     => FitRating.perfect,
      'may_be_snug' => FitRating.mayBeSnug,
      'runs_large'  => FitRating.runsLarge,
      _             => FitRating.unknown,
    };
    return FitResult(rating: r, confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0);
  }
}

/// Family provider — one per clothing item ID.
/// Lazily fetches GET /clothing/{id}/fit when first watched.
final fitRatingProvider = FutureProvider.family<FitResult, String>((ref, itemId) async {
  final dio = ref.read(apiClientProvider);
  final response = await dio.get<Map<String, dynamic>>('clothing/$itemId/fit');
  return FitResult.fromJson(response.data!);
});
