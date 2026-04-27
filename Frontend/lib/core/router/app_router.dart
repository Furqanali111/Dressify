import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/outfit.dart';
import '../../core/models/user.dart';
import '../../core/providers/auth_provider.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/avatar/avatar_selection_screen.dart';
import '../../features/camera_try_on/camera_try_on_screen.dart';
import '../../features/feedback/ai_feedback_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile_setup/profile_setup_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/try_on/try_on_screen.dart';
import '../../features/upload/upload_screen.dart';
import '../../features/wardrobe/wardrobe_screen.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Routes accessible without a valid JWT.
const Set<String> _publicPaths = <String>{
  '/splash',
  '/onboarding',
  '/sign-in',
  '/profile-setup',
  '/avatar-selection',
};

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<bool> refreshNotifier = ValueNotifier<bool>(false);

  ref.listen<User?>(authStateProvider, (_, _) {
    refreshNotifier.value = !refreshNotifier.value;
  });

  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoute.splash.path,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final User? user = ref.read(authStateProvider);
      final String location = state.matchedLocation;
      final bool isPublic = _publicPaths.contains(location);

      if (user == null && !isPublic) {
        return AppRoute.signIn.path;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.onboarding.path,
        name: AppRoute.onboarding.name,
        builder: (_, _) => const OnboardingScreen(),
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
        builder: (_, GoRouterState state) => AvatarSelectionScreen(
          gender: state.extra as String?,
        ),
      ),
      // ── Shell: bottom-nav tabs ──────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, StatefulNavigationShell shell) =>
            HomeShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          // Tab 0 — Home
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.home.path,
                name: AppRoute.home.name,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 1 — Camera (Live Try-On)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.camera.path,
                name: AppRoute.camera.name,
                builder: (_, _) => const CameraTryOnScreen(tabMode: true),
              ),
            ],
          ),
          // Tab 2 — Profile
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.profile.path,
                name: AppRoute.profile.name,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // ── Modal routes (pushed above shell) ──────────────────────────────
      GoRoute(
        path: AppRoute.wardrobe.path,
        name: AppRoute.wardrobe.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WardrobeScreen(),
      ),
      GoRoute(
        path: AppRoute.upload.path,
        name: AppRoute.upload.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const UploadScreen(),
      ),
      GoRoute(
        path: AppRoute.tryOn.path,
        name: AppRoute.tryOn.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, GoRouterState state) {
          final outfit = state.extra as Outfit?;
          return TryOnScreen(outfit: outfit);
        },
      ),
      GoRoute(
        path: AppRoute.cameraTryOn.path,
        name: AppRoute.cameraTryOn.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, GoRouterState state) {
          final outfit = state.extra as Outfit?;
          return CameraTryOnScreen(outfit: outfit);
        },
      ),
      GoRoute(
        path: AppRoute.aiFeedback.path,
        name: AppRoute.aiFeedback.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const AiFeedbackScreen(),
      ),
    ],
  );
});
