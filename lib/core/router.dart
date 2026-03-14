import 'package:go_router/go_router.dart';

import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_list_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_detail_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_edit_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_add_screen.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/screens/chat_screen.dart';
import 'package:wine_cellar/features/settings/presentation/screens/settings_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/virtual_cellar_list_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/virtual_cellar_detail_screen.dart';
import 'package:wine_cellar/core/widgets/shell_scaffold.dart';

/// Application router configuration
final GoRouter appRouter = GoRouter(
  initialLocation: '/cellar',
  routes: [
    // Shell route for bottom navigation
    ShellRoute(
      builder: (context, state, child) => ShellScaffold(child: child),
      routes: [
        GoRoute(
          path: '/cellar',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: WineListScreen(),
          ),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const WineAddScreen(),
            ),
            GoRoute(
              path: 'wine/:id',
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                return WineDetailScreen(wineId: id);
              },
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) {
                    final id = int.parse(state.pathParameters['id']!);
                    return WineEditScreen(wineId: id);
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/chat',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ChatScreen(),
          ),
        ),
        GoRoute(
          path: '/cellars',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: VirtualCellarListScreen(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                return VirtualCellarDetailScreen(cellarId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
  ],
);
