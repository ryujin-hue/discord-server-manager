import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/guilds/presentation/guild_list_screen.dart';
import '../features/media_sender/presentation/history_screen.dart';
import '../features/media_sender/presentation/send_screen.dart';
import '../features/server/presentation/server_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'shell.dart';

/// The routes of the app.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);

  ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (
    AsyncValue<AuthSession?>? previous,
    AsyncValue<AuthSession?> next,
  ) {
    refresh.notify();
  });

  return GoRouter(
    initialLocation: '/servers',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final session = ref.read(authControllerProvider);
      final isLoading = session.isLoading;
      final isSignedIn = session.value != null;
      final onLogin = state.matchedLocation == '/login';

      if (isLoading) {
        return null;
      }
      if (!isSignedIn && !onLogin) {
        return '/login';
      }
      if (isSignedIn && onLogin) {
        return '/servers';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/servers',
                builder: (BuildContext context, GoRouterState state) =>
                    const GuildListScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':guildId',
                    builder: (BuildContext context, GoRouterState state) =>
                        ServerScreen(
                          guildId: state.pathParameters['guildId'] ?? '',
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/send',
                builder: (BuildContext context, GoRouterState state) =>
                    const SendScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/history',
                builder: (BuildContext context, GoRouterState state) =>
                    const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Tells the router that the authentication state changed.
class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
