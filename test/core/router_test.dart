import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wine_cellar/core/router.dart';

void main() {
  group('appRouter', () {
    test('déclare les routes top-level et imbriquées attendues', () {
      final routes = appRouter.configuration.routes;

      expect(routes, hasLength(2));
      expect(routes.first, isA<ShellRoute>());
      expect(routes.last, isA<GoRoute>());
      expect((routes.last as GoRoute).path, '/manual');

      final shell = routes.first as ShellRoute;
      final shellPaths = shell.routes.whereType<GoRoute>().map((route) => route.path).toList();
      expect(
        shellPaths,
        ['/cellar', '/chat', '/cellars', '/statistics', '/settings', '/developer'],
      );

      final cellarRoute = shell.routes.whereType<GoRoute>().firstWhere(
            (route) => route.path == '/cellar',
          );
      expect(
        cellarRoute.routes.whereType<GoRoute>().map((route) => route.path).toList(),
        ['add', 'wine/:id'],
      );

      final wineDetailRoute = cellarRoute.routes.whereType<GoRoute>().firstWhere(
            (route) => route.path == 'wine/:id',
          );
      expect(wineDetailRoute.routes.whereType<GoRoute>().single.path, 'edit');

      final settingsRoute = shell.routes.whereType<GoRoute>().firstWhere(
            (route) => route.path == '/settings',
          );
      expect(
        settingsRoute.routes.whereType<GoRoute>().map((route) => route.path).toList(),
        ['ai', 'display'],
      );
    });

    test('match correctement le détail et l édition d un vin', () {
      final match = appRouter.configuration.findMatch(
        Uri.parse('/cellar/wine/42/edit'),
      );

      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], '42');
      expect(
        match.routes.whereType<GoRoute>().map((route) => route.path).toList(),
        ['/cellar', 'wine/:id', 'edit'],
      );
    });

    test('match correctement les routes avec query params', () {
      final cellarMatch = appRouter.configuration.findMatch(
        Uri.parse('/cellars/12?wineId=4&highlightWineId=7'),
      );
      final manualMatch = appRouter.configuration.findMatch(
        Uri.parse('/manual?section=developer'),
      );

      expect(cellarMatch.isError, isFalse);
      expect(cellarMatch.pathParameters['id'], '12');
      expect(cellarMatch.uri.queryParameters['wineId'], '4');
      expect(cellarMatch.uri.queryParameters['highlightWineId'], '7');
      expect(
        cellarMatch.routes.whereType<GoRoute>().map((route) => route.path).toList(),
        ['/cellars', ':id'],
      );

      expect(manualMatch.isError, isFalse);
      expect(manualMatch.uri.queryParameters['section'], 'developer');
      expect(
        manualMatch.routes.whereType<GoRoute>().map((route) => route.path).toList(),
        ['/manual'],
      );
    });

    test('retourne une erreur de matching pour une route inconnue', () {
      final match = appRouter.configuration.findMatch(Uri.parse('/inconnu'));

      expect(match.isError, isTrue);
      expect(match.error, isNotNull);
    });
  });
}