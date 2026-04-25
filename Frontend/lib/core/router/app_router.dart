import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/sign_in_screen.dart';
import '../../features/avatar/avatar_selection_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile_setup/profile_setup_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/try_on/try_on_screen.dart';
import '../../features/upload/upload_screen.dart';
import '../../features/wardrobe/wardrobe_screen.dart';
import 'app_routes.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: AppRoute.splash.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.signIn.path,
        name: AppRoute.signIn.name,
        builder: (_, _) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoute.profileSetup.path,
        name: AppRoute.profileSetup.name,
        builder: (_, _) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoute.avatarSelection.path,
        name: AppRoute.avatarSelection.name,
        builder: (_, _) => const AvatarSelectionScreen(),
      ),
      GoRoute(
        path: AppRoute.home.path,
        name: AppRoute.home.name,
        builder: (_, _) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoute.upload.path,
        name: AppRoute.upload.name,
        builder: (_, _) => const UploadScreen(),
      ),
      GoRoute(
        path: AppRoute.tryOn.path,
        name: AppRoute.tryOn.name,
        builder: (_, _) => const TryOnScreen(),
      ),
      GoRoute(
        path: AppRoute.wardrobe.path,
        name: AppRoute.wardrobe.name,
        builder: (_, _) => const WardrobeScreen(),
      ),
      GoRoute(
        path: AppRoute.profile.path,
        name: AppRoute.profile.name,
        builder: (_, _) => const ProfileScreen(),
      ),
    ],
  );
});
