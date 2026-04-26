import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../api/api_client.dart';

class ProfileStateNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final Ref _ref;

  ProfileStateNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> fetchProfile() async {
    try {
      state = const AsyncValue.loading();
      final dio = _ref.read(apiClientProvider);
      final response = await dio.get<Map<String, dynamic>>('/profile');
      final profile = Profile.fromJson(response.data!);
      state = AsyncValue.data(profile);
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(e, st);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      final dio = _ref.read(apiClientProvider);
      final response = await dio.patch<Map<String, dynamic>>('/profile', data: data);
      final profile = Profile.fromJson(response.data!);
      state = AsyncValue.data(profile);
    } catch (e) {
      // On error, let the caller handle it, state remains previous
      rethrow;
    }
  }

  void clearProfile() {
    state = const AsyncValue.data(null);
  }
}

final profileProvider = StateNotifierProvider<ProfileStateNotifier, AsyncValue<Profile?>>((ref) {
  return ProfileStateNotifier(ref);
});
