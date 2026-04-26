import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_flags.dart';
import '../providers/auth_provider.dart';
import 'auth_interceptor.dart';

final Provider<Dio> apiClientProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppFlags.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  dio.interceptors.add(AuthInterceptor(
    onUnauthorized: () => ref.read(authStateProvider.notifier).clearSession(),
  ));

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (Object obj) => debugPrint('[DIO] $obj'),
    ));
  }

  return dio;
});
