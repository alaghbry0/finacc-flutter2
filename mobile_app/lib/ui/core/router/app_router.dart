import 'package:go_router/go_router.dart';

import '../../features/home/views/home_screen.dart';

/// Declarative routing configuration for the application.
///
/// Routes are declared as data (not code) so they can be guarded,
/// redirected and deep-linked consistently on every platform.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
