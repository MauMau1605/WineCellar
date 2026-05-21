import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Right;
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/cellar_cell_position.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/helpers/expert_cellar_editor_helper.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/expert_cellar_editor_screen.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockVirtualCellarRepository extends Mock
    implements VirtualCellarRepository {}

class _AutoPushHost extends StatefulWidget {
  const _AutoPushHost({required this.targetRoute});

  final String targetRoute;

  @override
  State<_AutoPushHost> createState() => _AutoPushHostState();
}

class _AutoPushHostState extends State<_AutoPushHost> {
  bool _pushed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pushed) return;
    _pushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.push(widget.targetRoute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Écran retour expert')));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const VirtualCellarEntity(name: 'Fallback', rows: 1, columns: 1),
    );
  });

  group('ExpertCellarEditorScreen', () {
    late _MockSecureStorage storage;
    late _MockVirtualCellarRepository repository;

    setUp(() {
      storage = _MockSecureStorage();
      repository = _MockVirtualCellarRepository();

      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => storage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Right(1));
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => const Right(<VirtualCellarEntity>[]));
    });

    testWidgets('reprend un brouillon expert detecte au demarrage', (
      tester,
    ) async {
      final draft = ExpertCellarDraftPayload(
        name: 'Brouillon cave',
        rows: 3,
        cols: 4,
        emptyCells: {const CellarCellPosition(row: 1, col: 2)},
      ).toJsonString();

      when(
        () => storage.read(key: AppConstants.keyExpertCellarDraft),
      ).thenAnswer((_) async => draft);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            virtualCellarRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: ExpertCellarEditorScreen(
              initialName: 'Cave test',
              initialRows: 2,
              initialColumns: 2,
              initialTheme: VirtualCellarTheme.classic,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Un brouillon expert existe. Reprendre ou recommencer ?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Reprendre'));
      await tester.pumpAndSettle();

      expect(find.text('Brouillon cave'), findsOneWidget);
      expect(find.text('3 x 4 - 0 selection'), findsOneWidget);
      expect(
        find.text('Un brouillon expert existe. Reprendre ou recommencer ?'),
        findsNothing,
      );
    });

    testWidgets(
      'valide la cave puis efface le brouillon et revient en arriere',
      (tester) async {
        when(
          () => storage.read(key: AppConstants.keyExpertCellarDraft),
        ).thenAnswer((_) async => null);

        await _pumpExpertScreen(
          tester,
          storage: storage,
          repository: repository,
        );

        await tester.drag(
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is SingleChildScrollView &&
                    widget.scrollDirection == Axis.horizontal,
              )
              .first,
          const Offset(-900, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();

        expect(find.text('Recapitulatif'), findsOneWidget);
        expect(find.text('Dimensions: 2 x 2'), findsOneWidget);
        expect(find.text('Casiers actifs: 4'), findsOneWidget);
        expect(find.text('Zones vides: 0'), findsOneWidget);

        await tester.tap(find.text('Confirmer'));
        await tester.pumpAndSettle();

        final created =
            verify(() => repository.create(captureAny())).captured.single
                as VirtualCellarEntity;
        expect(created.name, 'Ma cave');
        expect(created.rows, 2);
        expect(created.columns, 2);

        verify(
          () => storage.delete(key: AppConstants.keyExpertCellarDraft),
        ).called(1);
        expect(find.text('Écran retour expert'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpExpertScreen(
  WidgetTester tester, {
  required FlutterSecureStorage storage,
  required VirtualCellarRepository repository,
}) async {
  final router = GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) =>
            const _AutoPushHost(targetRoute: '/expert'),
      ),
      GoRoute(
        path: '/expert',
        builder: (context, state) => const ExpertCellarEditorScreen(
          initialName: 'Ma cave',
          initialRows: 2,
          initialColumns: 2,
          initialTheme: VirtualCellarTheme.classic,
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        virtualCellarRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
