/// Retry helper for transient network failures in Dio-based providers.
///
/// Retries on:
///  - No response (network unreachable, DNS failure, timeout)
///  - HTTP 5xx (server-side transient error)
///
/// Does NOT retry on 4xx responses (client errors are not transient).
library;

import 'package:dio/dio.dart';

/// Calls [fn] up to [maxAttempts] times with exponential backoff (1 s, 2 s, 4 s …).
/// Rethrows the final exception if all attempts fail.
Future<T> dioFetchWithRetry<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } on DioException catch (e) {
      final bool noResponse = e.response == null;
      final int? status = e.response?.statusCode;
      final bool serverError = status != null && status >= 500;
      final bool isTransient = noResponse || serverError;

      if (!isTransient || attempt == maxAttempts) rethrow;

      // Exponential backoff: 1 s, 2 s, 4 s …
      await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
    }
  }
  // Unreachable — loop always rethrows or returns.
  throw StateError('dioFetchWithRetry: unreachable');
}
