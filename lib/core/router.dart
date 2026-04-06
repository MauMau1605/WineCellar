import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/widgets/shell_scaffold.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/screens/chat_screen.dart';
import 'package:wine_cellar/features/developer/presentation/screens/developer_screen.dart';
import 'package:wine_cellar/features/developer/presentation/screens/reevaluation_preview_screen.dart';
import 'package:wine_cellar/features/developer/presentation/screens/wine_reevaluation_screen.dart';
import 'package:wine_cellar/features/settings/presentation/screens/settings_screen.dart';
import 'package:wine_cellar/features/user_manual/presentation/screens/user_manual_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/virtual_cellar_detail_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/virtual_cellar_list_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_add_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_detail_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_edit_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_list_screen.dart';

/// Application router configuration
final GoRouter appRouter = GoRouter(
  initialLocation: '/cellar',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ShellScaffold(child: child),
      routes: [
        GoRoute(
          path: '/cellar',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WineListScreen()),
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
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ChatScreen()),
        ),
        GoRoute(
          path: '/cellars',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: VirtualCellarListScreen()),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                final wineIdStr = state.uri.queryParameters['wineId'];
                final preSelectedWineId = wineIdStr != null
                    ? int.tryParse(wineIdStr)
                    : null;
                final highlightWineIdStr = state.uri.queryParameters['highlightWineId'];
                final highlightWineId = highlightWineIdStr != null
                    ? int.tryParse(highlightWineIdStr)
                    : null;
                return VirtualCellarDetailScreen(
                  cellarId: id,
                  preSelectedWineId: preSelectedWineId,
                  highlightWineId: highlightWineId,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/developer',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DeveloperScreen()),
          routes: [
            GoRoute(
              path: 'reevaluate',
              builder: (context, state) => const WineReevaluationScreen(),
              routes: [
                GoRoute(
                  path: 'preview',
                  builder: (context, state) =>
                      const ReevaluationPreviewScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/manual',
      builder: (context, state) {
        final section = UserManualSection.fromQuery(
          state.uri.queryParameters['section'],
        );
        return UserManualScreen(initialSection: section);
      },
    ),
  ],
);
