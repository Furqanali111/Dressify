import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/clothing_item.dart';
import '../utils/dio_retry.dart';
import '../utils/json_cache.dart';

class WardrobeNotifier extends StateNotifier<AsyncValue<List<ClothingItem>>> {
  WardrobeNotifier(this._ref)
    : super(const AsyncValue<List<ClothingItem>>.loading()) {
    fetch();
  }

  final Ref _ref;
  String? _nextCursor;
  bool _isLoadingMore = false;
  String _sortBy = 'newest';
  bool _polling = false;

  bool get hasMore => _nextCursor != null;
  String get sortBy => _sortBy;

  void setSortBy(String sortBy) {
    if (_sortBy == sortBy) return;
    _sortBy = sortBy;
    fetch();
  }

  Future<void> fetch() async {
    final String cacheKey = 'wardrobe_$_sortBy';
    // Show the last known list immediately while the network call runs.
    List<ClothingItem>? cached;
    if (state.value == null) {
      final dynamic raw = await JsonCache.get(cacheKey);
      if (raw != null) {
        try {
          cached = _parse(raw);
        } catch (_) {
          /* stale/incompatible cache: ignore */
        }
      }
    }
    state = cached != null
        ? AsyncValue<List<ClothingItem>>.data(cached)
        : (state.value != null
              ? state
              : const AsyncValue<List<ClothingItem>>.loading());
    _nextCursor = null;
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> response = await dioFetchWithRetry(
        () => dio.get<dynamic>(
          'clothing',
          queryParameters: <String, dynamic>{'sort_by': _sortBy},
        ),
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        _nextCursor = data['next_cursor'] as String?;
      }
      state = AsyncValue<List<ClothingItem>>.data(_parse(data));
      JsonCache.put(cacheKey, data).ignore();
      _resumePolling();
    } on DioException catch (e, st) {
      // Treat 404 ("no resource yet") as an empty list rather than an error.
      if (e.response?.statusCode == 404) {
        state = const AsyncValue<List<ClothingItem>>.data(<ClothingItem>[]);
        return;
      }
      // Offline/failed refresh: keep showing what we have instead of an error.
      if (state.value == null)
        state = AsyncValue<List<ClothingItem>>.error(e, st);
    } catch (e, st) {
      if (state.value == null)
        state = AsyncValue<List<ClothingItem>>.error(e, st);
    }
  }

  Future<bool> fetchMore() async {
    if (_nextCursor == null || _isLoadingMore) return true;
    _isLoadingMore = true;
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> response = await dio.get<dynamic>(
        'clothing',
        queryParameters: <String, dynamic>{
          'cursor': _nextCursor,
          'sort_by': _sortBy,
        },
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        _nextCursor = data['next_cursor'] as String?;
      } else {
        _nextCursor = null;
      }
      final List<ClothingItem> newItems = _parse(data);
      final List<ClothingItem> current = state.value ?? <ClothingItem>[];
      state = AsyncValue<List<ClothingItem>>.data(<ClothingItem>[
        ...current,
        ...newItems,
      ]);
      return true;
    } catch (_) {
      _nextCursor = null;
      final List<ClothingItem> current = state.value ?? <ClothingItem>[];
      state = AsyncValue<List<ClothingItem>>.data(current);
      return false;
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    final Dio dio = _ref.read(apiClientProvider);
    final Response<dynamic> resp = await dio.patch<dynamic>(
      'clothing/$id',
      data: data,
    );
    final ClothingItem updated = ClothingItem.fromJson(
      resp.data as Map<String, dynamic>,
    );
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

  /// Items still processing after a (re)load — e.g. the app was reopened or the
  /// earlier poll gave up — keep updating on their own, no manual refresh.
  void _resumePolling() {
    final List<String> pending = (state.value ?? <ClothingItem>[])
        .where((ClothingItem it) => it.processingStatus == 'processing')
        .map((ClothingItem it) => it.id)
        .toList();
    if (pending.isNotEmpty) pollUntilComplete(pending).ignore();
  }

  /// Polls each item in [itemIds] until its processing_status leaves
  /// "processing": every 3 s for the first 15 s, then every 6 s, for about
  /// 2.5 minutes in total. Only one poll loop runs at a time.
  /// Returns false if the items could not be polled (network issue).
  Future<bool> pollUntilComplete(List<String> itemIds) async {
    if (_polling) return true;
    _polling = true;
    try {
      return await _poll(itemIds);
    } finally {
      _polling = false;
    }
  }

  Future<bool> _poll(List<String> itemIds) async {
    const int maxAttempts = 25;
    final Set<String> pending = Set<String>.from(itemIds);
    final Map<String, int> failCount = <String, int>{};

    for (
      int attempt = 0;
      attempt < maxAttempts && pending.isNotEmpty;
      attempt++
    ) {
      await Future<void>.delayed(Duration(seconds: attempt < 5 ? 3 : 6));
      if (!mounted) return true;
      final Dio dio = _ref.read(apiClientProvider);
      await Future.wait<void>(
        List<String>.from(pending).map((String id) async {
          try {
            final Response<dynamic> resp = await dio.get<dynamic>(
              'clothing/$id',
            );
            final ClothingItem updated = ClothingItem.fromJson(
              resp.data as Map<String, dynamic>,
            );
            if (updated.processingStatus != 'processing') pending.remove(id);
            failCount.remove(id);
            if (!mounted) return;
            final List<ClothingItem> current = state.value ?? <ClothingItem>[];
            state = AsyncValue<List<ClothingItem>>.data(
              current
                  .map((ClothingItem it) => it.id == id ? updated : it)
                  .toList(),
            );
          } catch (_) {
            failCount[id] = (failCount[id] ?? 0) + 1;
          }
        }),
      );

      // If every pending item has failed 3+ times in a row, give up early.
      if (pending.isNotEmpty &&
          pending.every((String id) => (failCount[id] ?? 0) >= 3)) {
        return false;
      }
    }

    return true;
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
