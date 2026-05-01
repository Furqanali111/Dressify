import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/wardrobe_analytics.dart';
import '../utils/dio_retry.dart';

class WardrobeAnalyticsNotifier extends AsyncNotifier<WardrobeAnalytics?> {
  @override
  Future<WardrobeAnalytics?> build() => _fetch();

  Future<WardrobeAnalytics?> _fetch() async {
    try {
      final dio = ref.read(apiClientProvider);
      final res = await dioFetchWithRetry(
        () => dio.get<Map<String, dynamic>>('analytics/wardrobe'),
      );
      return WardrobeAnalytics.fromJson(res.data!);
    } on RateLimitException {
      // Re-throw so the UI can render a specific "rate limited" message
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) throw const RateLimitException();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final wardrobeAnalyticsProvider =
    AsyncNotifierProvider<WardrobeAnalyticsNotifier, WardrobeAnalytics?>(() {
  return WardrobeAnalyticsNotifier();
});
