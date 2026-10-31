import 'package:dio/dio.dart';

/// Replaces Dio's technical messages with ones that are safe to show users.
/// Read it via `e.message` (or `friendlyMessage(e)`) in UI error states.
class FriendlyErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(message: friendlyMessage(err)));
  }
}

String friendlyMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
      return "You're offline or the server can't be reached. Check your connection and retry.";
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'This is taking too long. Please try again.';
    default:
      final int? code = e.response?.statusCode;
      if (code == 429) return "You're doing that too fast. Wait a moment and retry.";
      if (code != null && code >= 500) return 'Something went wrong on our side. Try again shortly.';
      final Object? data = e.response?.data;
      if (data is Map && data['detail'] is String) return data['detail'] as String;
      return 'Something went wrong. Please try again.';
  }
}

/// Message for any caught error: friendly text for network errors, else [fallback].
String errorMessage(Object e, [String fallback = 'Something went wrong. Please try again.']) =>
    e is DioException ? friendlyMessage(e) : fallback;
