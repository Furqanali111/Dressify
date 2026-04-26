import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class AuthStateNotifier extends StateNotifier<User?> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthStateNotifier() : super(null);

  Future<void> init() async {
    // TODO: Verify token with backend, fetch /me
    // If successful, set state = user
    // If fail, clear token
  }

  Future<void> signInWithGoogle(String idToken) async {
    // TODO: Call API client POST /auth/google
    // Store returned JWT to _storage
    // Set state = returned User
  }

  Future<void> signOut() async {
    await _storage.delete(key: 'auth_jwt');
    state = null;
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, User?>((ref) {
  return AuthStateNotifier();
});
