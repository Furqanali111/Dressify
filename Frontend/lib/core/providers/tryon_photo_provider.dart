import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// The user's saved full-body photo (stored server-side) used for AI try-on.
class TryOnPhoto {
  const TryOnPhoto({required this.hasPhoto, this.url});
  final bool hasPhoto;
  final String? url;

  factory TryOnPhoto.fromJson(Map<String, dynamic> j) =>
      TryOnPhoto(hasPhoto: j['has_photo'] == true, url: j['url'] as String?);
}

class TryOnPhotoNotifier extends StateNotifier<AsyncValue<TryOnPhoto>> {
  TryOnPhotoNotifier(this._dio)
    : super(const AsyncValue<TryOnPhoto>.loading()) {
    refresh();
  }

  final Dio _dio;

  Future<void> refresh() async {
    try {
      final Response<Map<String, dynamic>> r = await _dio
          .get<Map<String, dynamic>>('tryon/photo');
      state = AsyncValue<TryOnPhoto>.data(
        TryOnPhoto.fromJson(r.data ?? <String, dynamic>{}),
      );
    } catch (e, st) {
      state = AsyncValue<TryOnPhoto>.error(e, st);
    }
  }

  /// Uploads [jpegBytes] as the saved photo. Throws DioException on failure
  /// (e.g. 422 "photo too small") so callers can show the server's message.
  Future<void> save(Uint8List jpegBytes) async {
    final FormData form = FormData.fromMap(<String, dynamic>{
      'photo': MultipartFile.fromBytes(jpegBytes, filename: 'photo.jpg'),
    });
    final Response<Map<String, dynamic>> r = await _dio
        .put<Map<String, dynamic>>('tryon/photo', data: form);
    state = AsyncValue<TryOnPhoto>.data(
      TryOnPhoto.fromJson(r.data ?? <String, dynamic>{}),
    );
  }

  Future<void> remove() async {
    await _dio.delete<dynamic>('tryon/photo');
    state = const AsyncValue<TryOnPhoto>.data(TryOnPhoto(hasPhoto: false));
  }
}

final StateNotifierProvider<TryOnPhotoNotifier, AsyncValue<TryOnPhoto>>
tryOnPhotoProvider =
    StateNotifierProvider<TryOnPhotoNotifier, AsyncValue<TryOnPhoto>>(
      (Ref ref) => TryOnPhotoNotifier(ref.watch(apiClientProvider)),
    );
