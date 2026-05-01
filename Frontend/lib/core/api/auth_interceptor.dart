import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({this.onUnauthorized});

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final void Function()? onUnauthorized;

  static const String jwtKey = 'auth_jwt';

  // In-memory cache — avoids a secure-storage round-trip on every request.
  // Cleared on 401 so the next request fetches a fresh token.
  String? _cachedToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    _cachedToken ??= await _storage.read(key: jwtKey);
    final String? token = _cachedToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _cachedToken = null;
      _storage.delete(key: jwtKey);
      onUnauthorized?.call();
    }
    return super.onError(err, handler);
  }

  /// Called by [auth_provider] after writing a new token so the cache stays
  /// in sync without waiting for the next request to trigger a miss.
  void updateCache(String? token) => _cachedToken = token;
}
