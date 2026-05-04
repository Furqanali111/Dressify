import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../api/api_client.dart';
import '../api/auth_interceptor.dart';
import '../config/app_flags.dart';
import 'fit_rating_provider.dart';
import 'fit_scale_provider.dart';
import 'outfits_provider.dart';
import 'profile_provider.dart';
import 'style_profile_provider.dart';
import 'wardrobe_analytics_provider.dart';
import 'wardrobe_provider.dart';

class AuthStateNotifier extends StateNotifier<User?> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: AppFlags.googleWebClientId,
  );

  AuthStateNotifier(this._ref) : super(null);

  Future<bool> init() async {
    final String? token = await _storage.read(key: 'auth_jwt');
    if (token == null || token.isEmpty) return false;

    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> response = await dio.get<dynamic>('me');
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      state = User.fromJson(data['user'] as Map<String, dynamic>);
      final profileJson = data['profile'] as Map<String, dynamic>?;
      if (profileJson != null) {
        _ref.read(profileProvider.notifier).setProfileData(profileJson);
      }
      return true;
    } on DioException catch (e) {
      // 401 = JWT invalid/expired — clear it
      if (e.response?.statusCode == 401) {
        await _storage.delete(key: 'auth_jwt');
        state = null;
        return false;
      }
      // Network error — keep token, let user retry
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> signInWithGoogle() async {
    try {
      String idToken;
      
      if (AppFlags.bypassAuth) {
        idToken = 'BYPASS_AUTH_FURQAN_54321';
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // User canceled

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final String? googleIdToken = googleAuth.idToken;

        if (googleIdToken == null) throw Exception('Google ID token is null');
        idToken = googleIdToken;
      }

      final dio = _ref.read(apiClientProvider);
      final response = await dio.post<dynamic>('auth/google', data: {
        'id_token': idToken,
      });

      final data = response.data as Map<String, dynamic>? ?? <String, dynamic>{};
      final jwt = data['jwt'] as String? ?? '';
      if (jwt.isEmpty) throw Exception('No JWT in auth response');
      await _storage.write(key: 'auth_jwt', value: jwt);

      final userJson = data['user'] as Map<String, dynamic>?;
      if (userJson != null) state = User.fromJson(userJson);

      return data['has_profile'] as bool? ?? false;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      rethrow;
    }
  }

  Future<void> uploadAvatar(File imageFile) async {
    final dio = _ref.read(apiClientProvider);
    final form = FormData.fromMap(<String, dynamic>{
      'image': await MultipartFile.fromFile(imageFile.path),
    });
    final response = await dio.post<Map<String, dynamic>>(
      'users/me/avatar',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = response.data;
    if (data != null) state = User.fromJson(data);
  }

  void clearSession() => state = null;

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _storage.delete(key: 'auth_jwt');
    _ref.read(apiClientProvider).interceptors
        .whereType<AuthInterceptor>()
        .firstOrNull
        ?.updateCache(null);
    state = null;
    _ref.invalidate(profileProvider);
    _ref.invalidate(wardrobeProvider);
    _ref.invalidate(outfitsProvider);
    _ref.invalidate(styleProfileProvider);
    _ref.invalidate(wardrobeAnalyticsProvider);
    _ref.invalidate(fitRatingProvider);
    _ref.invalidate(fitScalesProvider);
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, User?>((ref) {
  return AuthStateNotifier(ref);
});
