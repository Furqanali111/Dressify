import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

enum TryOnStatus { idle, loading, done, error }

class TryOnState {
  const TryOnState({
    this.status = TryOnStatus.idle,
    this.resultUrl,
    this.errorMessage,
  });

  final TryOnStatus status;
  final String? resultUrl;
  final String? errorMessage;

  bool get isLoading => status == TryOnStatus.loading;
}

class TryOnNotifier extends StateNotifier<TryOnState> {
  TryOnNotifier(this._dio) : super(const TryOnState());

  final Dio _dio;

  Future<void> generate({
    required Uint8List personImageBytes,
    required String clothingItemId,
  }) async {
    state = const TryOnState(status: TryOnStatus.loading);
    try {
      final FormData form = FormData.fromMap(<String, dynamic>{
        'person_image':     MultipartFile.fromBytes(personImageBytes, filename: 'person.jpg'),
        'clothing_item_id': clothingItemId,
      });
      final Response<Map<String, dynamic>> resp =
          await _dio.post<Map<String, dynamic>>('tryon', data: form);
      final String? url = resp.data?['result_url'] as String?;
      state = TryOnState(status: TryOnStatus.done, resultUrl: url);
    } on DioException catch (e) {
      final String msg = (e.response?.data as Map?)?['detail'] as String? ??
          'Try-on failed. Please try again.';
      state = TryOnState(status: TryOnStatus.error, errorMessage: msg);
    } catch (_) {
      state = const TryOnState(
        status: TryOnStatus.error,
        errorMessage: 'Something went wrong.',
      );
    }
  }

  void reset() => state = const TryOnState();
}

final tryOnProvider = StateNotifierProvider<TryOnNotifier, TryOnState>(
  (ref) => TryOnNotifier(ref.watch(apiClientProvider)),
);
