/// هيكل التنقل — go_router (SRS §6.4).
///
/// الحراسة المركزية عبر أطوار الجلسة:
/// initializing → Splash، needsOnboarding → Onboarding، locked → Lock،
/// ready → الهيكل الرئيسي بخمسة تبويبات (الرئيسية/المخزون/البيع/النقدية/
/// المزيد) مع زر البيع البارز في الوسط.
library;

import 'package:go_router/go_router.dart';

import '../../features/home/views/home_screen.dart';
import '../../features/onboarding_auth/views/lock_screen.dart';
import '../../features/onboarding_auth/views/onboarding_screen.dart';
import '../../features/placeholders/coming_soon_screen.dart';
import '../../features/settings/views/change_pin_screen.dart';
import '../../features/settings/views/settings_screen.dart';
import '../../features/splash/views/splash_screen.dart';
import '../session/app_controller.dart';
import '../widgets/app_shell.dart';

/// يبني الموجّه فوق متحكم الجلسة (refreshListenable = تغيّر الطور).
GoRouter buildAppRouter(AppController controller) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: controller,
    redirect: (context, state) {
      final phase = controller.phase;
      final location = state.matchedLocation;
      switch (phase) {
        case AppPhase.initializing:
        case AppPhase.error:
          return location == '/splash' ? null : '/splash';
        case AppPhase.needsOnboarding:
          return location == '/onboarding' ? null : '/onboarding';
        case AppPhase.locked:
          return location == '/lock' ? null : '/lock';
        case AppPhase.ready:
          if (location == '/splash' ||
              location == '/onboarding' ||
              location == '/lock') {
            return '/home';
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) =>
                    const ComingSoonScreen(feature: ComingFeature.inventory),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sell',
                builder: (context, state) =>
                    const ComingSoonScreen(feature: ComingFeature.sell),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cash',
                builder: (context, state) =>
                    const ComingSoonScreen(feature: ComingFeature.cash),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'change-pin',
                    builder: (context, state) => const ChangePinScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
