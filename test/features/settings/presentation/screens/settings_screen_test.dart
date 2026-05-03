import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/settings/presentation/screens/settings_screen.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('SettingsScreen', () {
    late _MockSecureStorage storage;

    setUp(() {
      storage = _MockSecureStorage();
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => storage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
    });

    testWidgets('affiche les tuiles et navigue vers les sous-ecrans', (
      tester,
    ) async {
      final router = await _pumpScreen(
        tester,
        storage: storage,
        storedValues: {
          AppConstants.keyAiProvider: AiProvider.gemini.name,
          AppConstants.keyWineListLayout: WineListLayout.list.name,
          AppConstants.keyDeveloperMode: 'true',
        },
      );

      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Intelligence artificielle'), findsOneWidget);
      expect(find.text('Google Gemini'), findsOneWidget);
      expect(find.text('Affichage'), findsOneWidget);
      expect(find.text('Outils développeur'), findsOneWidget);

      await tester.tap(find.text('Intelligence artificielle'));
      await tester.pumpAndSettle();

      expect(find.text('Écran IA factice'), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Affichage'));
      await tester.pumpAndSettle();

      expect(find.text('Écran affichage factice'), findsOneWidget);
    });

    testWidgets('active le mode developpeur et persiste le changement', (
      tester,
    ) async {
      await _pumpScreen(tester, storage: storage);

      expect(find.text('Outils développeur'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      verify(
        () => storage.write(key: AppConstants.keyDeveloperMode, value: 'true'),
      ).called(1);
      expect(find.text('Outils développeur'), findsOneWidget);

      await tester.tap(find.text('Outils développeur'));
      await tester.pumpAndSettle();

      expect(find.text('Écran développeur factice'), findsOneWidget);
    });
  });
}

Future<GoRouter> _pumpScreen(
  WidgetTester tester, {
  required _MockSecureStorage storage,
  Map<String, String?> storedValues = const {},
}) async {
  when(() => storage.read(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    final key = invocation.namedArguments[#key] as String;
    return storedValues[key];
  });

  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'ai',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Écran IA factice'))),
          ),
          GoRoute(
            path: 'display',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Écran affichage factice')),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/developer',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Écran développeur factice')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [secureStorageProvider.overrideWithValue(storage)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return router;
}
