import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({this.onUnauthorized});

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final void Function()? onUnauthorized;

  static const String jwtKey = 'auth_jwt';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final String? token = await _storage.read(key: jwtKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Fire-and-forget storage clear; state reset handled by callback
      _storage.delete(key: jwtKey);
      onUnauthorized?.call();
    }
    return super.onError(err, handler);
  }
}
