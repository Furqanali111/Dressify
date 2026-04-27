import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/clothing_item.dart';

class WardrobeNotifier extends StateNotifier<AsyncValue<List<ClothingItem>>> {
  WardrobeNotifier(this._ref) : super(const AsyncValue<List<ClothingItem>>.loading()) {
    fetch();
  }

  final Ref _ref;
  String? _nextCursor;
  bool _isLoadingMore = false;

  bool get hasMore => _nextCursor != null;

  Future<void> fetch() async {
    state = const AsyncValue<List<ClothingItem>>.loading();
    _nextCursor = null;
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> response = await dio.get<dynamic>('clothing');
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        _nextCursor = data['next_cursor'] as String?;
      }
      state = AsyncValue<List<ClothingItem>>.data(_parse(data));
    } on DioException catch (e, st) {
      // Treat 404 ("no resource yet") as an empty list rather than an error.
      if (e.response?.statusCode == 404) {
        state = const AsyncValue<List<ClothingItem>>.data(<ClothingItem>[]);
        return;
      }
      state = AsyncValue<List<ClothingItem>>.error(e, st);
    } catch (e, st) {
      state = AsyncValue<List<ClothingItem>>.error(e, st);
    }
  }

  Future<void> fetchMore() async {
    if (_nextCursor == null || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> response = await dio.get<dynamic>(
        'clothing',
        queryParameters: <String, dynamic>{'cursor': _nextCursor},
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        _nextCursor = data['next_cursor'] as String?;
      } else {
        _nextCursor = null;
      }
      final List<ClothingItem> newItems = _parse(data);
      final List<ClothingItem> current = state.value ?? <ClothingItem>[];
      state = AsyncValue<List<ClothingItem>>.data(<ClothingItem>[...current, ...newItems]);
    } catch (_) {
      // Silently fail; user can pull-to-refresh
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    final Dio dio = _ref.read(apiClientProvider);
    final Response<dynamic> resp =
        await dio.patch<dynamic>('clothing/$id', data: data);
    final ClothingItem updated =
        ClothingItem.fromJson(resp.data as Map<String, dynamic>);
    final List<ClothingItem> current = state.value ?? <ClothingItem>[];
    state = AsyncValue<List<ClothingItem>>.data(
      current.map((ClothingItem it) => it.id == id ? updated : it).toList(),
    );
  }

  Future<void> delete(String id) async {
    final Dio dio = _ref.read(apiClientProvider);
    await dio.delete<dynamic>('clothing/$id');
    final List<ClothingItem> current = state.value ?? <ClothingItem>[];
    state = AsyncValue<List<ClothingItem>>.data(
      current.where((ClothingItem it) => it.id != id).toList(),
    );
  }

  /// Polls each item in [itemIds] every 3 s until its processing_status
  /// leaves "processing", or until 30 s have elapsed (10 attempts).
  Future<void> pollUntilComplete(List<String> itemIds) async {
    const Duration interval = Duration(seconds: 3);
    const int maxAttempts = 10;
    final Set<String> pending = Set<String>.from(itemIds);

    for (int attempt = 0; attempt < maxAttempts && pending.isNotEmpty; attempt++) {
      await Future<void>.delayed(interval);
      final Dio dio = _ref.read(apiClientProvider);
      for (final String id in List<String>.from(pending)) {
        try {
          final Response<dynamic> resp =
              await dio.get<dynamic>('clothing/$id');
          final ClothingItem updated =
              ClothingItem.fromJson(resp.data as Map<String, dynamic>);
          if (updated.processingStatus != 'processing') pending.remove(id);
          final List<ClothingItem> current = state.value ?? <ClothingItem>[];
          state = AsyncValue<List<ClothingItem>>.data(
            current
                .map((ClothingItem it) => it.id == id ? updated : it)
                .toList(),
          );
        } catch (_) {
          // Skip individual failures; keep polling the others
        }
      }
    }
  }

  /// Backend may return `{ items: [...] }` (with cursor) or `[...]` directly.
  /// Tolerate both so the UI doesn't break across iterations.
  static List<ClothingItem> _parse(dynamic data) {
    final List<dynamic> raw = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const <dynamic>[])
        : (data as List<dynamic>);
    return raw
        .map((dynamic e) => ClothingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final StateNotifierProvider<WardrobeNotifier, AsyncValue<List<ClothingItem>>>
    wardrobeProvider =
    StateNotifierProvider<WardrobeNotifier, AsyncValue<List<ClothingItem>>>(
  WardrobeNotifier.new,
);
