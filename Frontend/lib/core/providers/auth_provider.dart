import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../api/api_client.dart';

class AuthStateNotifier extends StateNotifier<User?> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthStateNotifier(this._ref) : super(null);

  Future<bool> init() async {
    final token = await _storage.read(key: 'auth_jwt');
    if (token == null || token.isEmpty) return false;

    try {
      final dio = _ref.read(apiClientProvider);
      await dio.get('/profile');
      state = User(
        id: 'mock',
        email: 'cached@example.com',
        createdAt: DateTime.now(),
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
         state = User(
           id: 'mock',
           email: 'cached@example.com',
           createdAt: DateTime.now(),
         );
         return true;
      }
      await _storage.delete(key: 'auth_jwt');
      state = null;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) throw Exception('Google ID token is null');

      final dio = _ref.read(apiClientProvider);
      final response = await dio.post('/auth/google', data: {
        'id_token': idToken,
      });

      final jwt = response.data['jwt'] as String;
      await _storage.write(key: 'auth_jwt', value: jwt);

      final userJson = response.data['user'] as Map<String, dynamic>;
      state = User.fromJson(userJson);

      return response.data['has_profile'] as bool;
    } catch (e) {
      print('Google sign in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _storage.delete(key: 'auth_jwt');
    state = null;
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, User?>((ref) {
  return AuthStateNotifier(ref);
});
