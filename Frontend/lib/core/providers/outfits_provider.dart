import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/outfit.dart';

class OutfitsNotifier extends StateNotifier<AsyncValue<List<Outfit>>> {
  OutfitsNotifier(this._ref) : super(const AsyncValue<List<Outfit>>.loading()) {
    fetch();
  }

  final Ref _ref;

  Future<void> fetch() async {
    state = const AsyncValue<List<Outfit>>.loading();
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> response = await dio.get<dynamic>('/outfits');
      state = AsyncValue<List<Outfit>>.data(_parse(response.data));
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
