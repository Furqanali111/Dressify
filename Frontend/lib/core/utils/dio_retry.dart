/// Retry helper for transient network failures in Dio-based providers.
///
/// Retries on:
///  - No response (network unreachable, DNS failure, timeout)
///  - HTTP 5xx (server-side transient error)
///
/// Does NOT retry on 4xx responses (client errors are not transient).
/// Immediately throws [RateLimitException] on HTTP 429 (Too Many Requests).
library;

import 'package:dio/dio.dart';

/// Thrown when the server responds with HTTP 429 (rate limit exceeded).
class RateLimitException implements Exception {
  const RateLimitException([this.message = 'Too many requests — please wait a moment and try again.']);
  final String message;

  @override
  String toString() => message;
}

/// Calls [fn] up to [maxAttempts] times with exponential backoff (1 s, 2 s, 4 s …).
/// Rethrows the final exception if all attempts fail.
/// Immediately throws [RateLimitException] on HTTP 429 without retrying.
Future<T> dioFetchWithRetry<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;

      // Surface rate-limit errors immediately — retrying makes it worse
      if (status == 429) {
        throw const RateLimitException();
      }

      final bool noResponse = e.response == null;
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
