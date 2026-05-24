import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'state/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      if (auth == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }
      if (auth == AuthStatus.signedOut) {
        return loc == '/login' ? null : '/login';
      }
      // signedIn
      if (loc == '/login' || loc == '/splash') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (_, _) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthStatus>(authStateProvider, (_, _) => notifyListeners());
  }
}
