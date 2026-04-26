import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/clothing_item.dart';

class WardrobeNotifier extends StateNotifier<AsyncValue<List<ClothingItem>>> {
  WardrobeNotifier(this._ref) : super(const AsyncValue<List<ClothingItem>>.loading()) {
    fetch();
  }

  final Ref _ref;

  Future<void> fetch() async {
    state = const AsyncValue<List<ClothingItem>>.loading();
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> response = await dio.get<dynamic>('/clothing');
      state = AsyncValue<List<ClothingItem>>.data(_parse(response.data));
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

  Future<void> delete(String id) async {
    final Dio dio = _ref.read(apiClientProvider);
    await dio.delete<dynamic>('/clothing/$id');
    final List<ClothingItem> current = state.value ?? <ClothingItem>[];
    state = AsyncValue<List<ClothingItem>>.data(
      current.where((ClothingItem it) => it.id != id).toList(),
    );
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
