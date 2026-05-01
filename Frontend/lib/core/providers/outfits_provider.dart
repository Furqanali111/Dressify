import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/outfit.dart';
import '../utils/dio_retry.dart';

class OutfitsNotifier extends StateNotifier<AsyncValue<List<Outfit>>> {
  OutfitsNotifier(this._ref) : super(const AsyncValue<List<Outfit>>.loading()) {
    fetch();
  }

  final Ref _ref;
  String? _nextCursor;
  bool _isLoadingMore = false;

  bool get hasMore => _nextCursor != null;

  Future<void> fetch() async {
    state = const AsyncValue<List<Outfit>>.loading();
    _nextCursor = null;
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> response = await dioFetchWithRetry(
        () => dio.get<dynamic>('/outfits'),
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        _nextCursor = data['next_cursor'] as String?;
      }
      state = AsyncValue<List<Outfit>>.data(_parse(data));
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) {
        state = const AsyncValue<List<Outfit>>.data(<Outfit>[]);
        return;
      }
      state = AsyncValue<List<Outfit>>.error(e, st);
    } catch (e, st) {
      state = AsyncValue<List<Outfit>>.error(e, st);
    }
  }

  Future<void> fetchMore() async {
    if (_nextCursor == null || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> response = await dio.get<dynamic>(
        '/outfits',
        queryParameters: <String, dynamic>{'cursor': _nextCursor},
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        _nextCursor = data['next_cursor'] as String?;
      } else {
        _nextCursor = null;
      }
      final List<Outfit> newItems = _parse(data);
      final List<Outfit> current = state.value ?? <Outfit>[];
      state = AsyncValue<List<Outfit>>.data(<Outfit>[...current, ...newItems]);
    } catch (_) {
      // Silently fail; user can pull-to-refresh
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> rename(String id, String name) async {
    final Dio dio = _ref.read(apiClientProvider);
    await dio.patch<dynamic>('/outfits/$id', data: <String, dynamic>{'name': name});
    final List<Outfit> current = state.value ?? <Outfit>[];
    state = AsyncValue<List<Outfit>>.data(
      current.map((Outfit o) => o.id == id ? o.copyWith(name: name) : o).toList(),
    );
  }

  Future<void> toggleStar(String id) async {
    final List<Outfit> current = state.value ?? <Outfit>[];
    final Outfit? target = current.cast<Outfit?>().firstWhere(
          (Outfit? o) => o?.id == id,
          orElse: () => null,
        );
    if (target == null) return;
    final bool next = !target.isStarred;
    // Optimistic update
    state = AsyncValue<List<Outfit>>.data(
      current.map((Outfit o) => o.id == id ? o.copyWith(isStarred: next) : o).toList(),
    );
    try {
      final Dio dio = _ref.read(apiClientProvider);
      await dio.patch<dynamic>('/outfits/$id', data: <String, dynamic>{'is_starred': next});
    } catch (_) {
      // Roll back on failure
      state = AsyncValue<List<Outfit>>.data(
        (state.value ?? <Outfit>[])
            .map((Outfit o) => o.id == id ? o.copyWith(isStarred: !next) : o)
            .toList(),
      );
    }
  }

  Future<void> delete(String id) async {
    final Dio dio = _ref.read(apiClientProvider);
    await dio.delete<dynamic>('/outfits/$id');
    final List<Outfit> current = state.value ?? <Outfit>[];
    state = AsyncValue<List<Outfit>>.data(
      current.where((Outfit o) => o.id != id).toList(),
    );
  }

  static List<Outfit> _parse(dynamic data) {
    final List<dynamic> raw = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const <dynamic>[])
        : (data as List<dynamic>);
    return raw
        .map((dynamic e) => Outfit.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final StateNotifierProvider<OutfitsNotifier, AsyncValue<List<Outfit>>>
    outfitsProvider =
    StateNotifierProvider<OutfitsNotifier, AsyncValue<List<Outfit>>>(
  OutfitsNotifier.new,
);
