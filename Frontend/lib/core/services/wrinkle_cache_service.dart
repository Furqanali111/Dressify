import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';

import '../models/clothing_item.dart';

/// Downloads and decodes wrinkle map PNGs for a garment into GPU-ready
/// [ui.Image] objects (S4.2.1 / S6.6 pre-blit).
///
/// Returns a map of {pose: ui.Image} for all poses that have a signed URL in
/// [item.wrinkleMaps]. Poses missing from the API response are simply absent
/// from the result — the painter falls back to no wrinkle effect for those.
class WrinkleCacheService {
  WrinkleCacheService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// Downloads and decodes all wrinkle maps for [item].
  /// Returns null if the item has no wrinkle maps.
  /// Individual download failures are skipped silently.
  static Future<Map<String, ui.Image>?> loadForItem(ClothingItem item) async {
    final Map<String, String>? urls = item.wrinkleMaps;
    if (urls == null || urls.isEmpty) return null;

    final Map<String, ui.Image> result = <String, ui.Image>{};

    await Future.wait(
      urls.entries.map((MapEntry<String, String> e) async {
        try {
          final ui.Image img = await _downloadAndDecode(e.value);
          result[e.key] = img;
        } catch (_) {
          // Missing/broken wrinkle map → pose falls back to no overlay
        }
      }),
    );

    return result.isEmpty ? null : result;
  }

  static Future<ui.Image> _downloadAndDecode(String url) async {
    final Response<List<int>> resp = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final Uint8List bytes = Uint8List.fromList(resp.data ?? <int>[]);
    if (bytes.isEmpty) throw Exception('empty wrinkle map response');
    final Completer<ui.Image> c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, c.complete);
    return c.future;
  }
}
