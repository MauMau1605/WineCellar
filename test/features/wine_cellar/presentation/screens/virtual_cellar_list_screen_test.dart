import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/virtual_cellar_list_screen.dart';

class _FakeVirtualCellarRepository implements VirtualCellarRepository {
  _FakeVirtualCellarRepository([
    List<VirtualCellarEntity> initialCellars = const [],
  ]) : _cellars = initialCellars.toList(growable: true) {
    if (_cellars.isNotEmpty) {
      _nextId =
          _cellars
              .map((cellar) => cellar.id ?? 0)
              .reduce((left, right) => left > right ? left : right) +
          1;
    }
  }

  final List<VirtualCellarEntity> _cellars;
  final StreamController<List<VirtualCellarEntity>> _controller =
      StreamController<List<VirtualCellarEntity>>.broadcast();
  int _nextId = 1;

  List<VirtualCellarEntity> get currentCellars => List.unmodifiable(_cellars);

  void dispose() {
    _controller.close();
  }

  @override
  Future<Either<Failure, int>> create(VirtualCellarEntity cellar) async {
    final created = cellar.copyWith(id: _nextId++);
    _cellars.add(created);
    _emit();
    return Right(created.id!);
  }

  @override
  Future<Either<Failure, Unit>> delete(int id) async {
    _cellars.removeWhere((cellar) => cellar.id == id);
    _emit();
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<VirtualCellarEntity>>> getAll() async {
    return Right(List.unmodifiable(_cellars));
  }

  @override
  Future<Either<Failure, VirtualCellarEntity?>> getById(int id) async {
    for (final cellar in _cellars) {
      if (cellar.id == id) {
        return Right(cellar);
      }
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, int>> getPlacedBottleCount(int wineId) async {
    return const Right(0);
  }

  @override
  Future<Either<Failure, List<BottlePlacementEntity>>> getPlacementsByWineId(
    int wineId,
  ) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<WineEntity>>> getWinesByCellarId(
    int cellarId,
  ) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, Unit>> moveBottleInCellar({
    required int placementId,
    required int newPositionX,
    required int newPositionY,
  }) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> placeWine(
    int wineId, {
    required int cellarId,
    required int positionX,
    required int positionY,
  }) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> removePlacement(int placementId) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> trimPlacementsForWine({
    required int wineId,
    required int maxPlacements,
  }) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> update(VirtualCellarEntity cellar) async {
    final index = _cellars.indexWhere((current) => current.id == cellar.id);
    if (index >= 0) {
      _cellars[index] = cellar;
      _emit();
    }
    return const Right(unit);
  }

  @override
  Stream<List<VirtualCellarEntity>> watchAll() {
    return Stream.multi((multi) {
      multi.add(List.unmodifiable(_cellars));
      final subscription = _controller.stream.listen(multi.add);
      multi.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<BottlePlacementEntity>> watchPlacementsByCellarId(int cellarId) {
    return const Stream<List<BottlePlacementEntity>>.empty();
  }

  @override
  Stream<List<WineEntity>> watchWinesByCellarId(int cellarId) {
    return const Stream<List<WineEntity>>.empty();
  }

  void _emit() {
    _controller.add(List.unmodifiable(_cellars));
  }
}

void main() {
  group('VirtualCellarListScreen', () {
    testWidgets('affiche l etat vide puis cree un cellier', (tester) async {
      tester.view.physicalSize = const Size(1440, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeVirtualCellarRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            virtualCellarRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: VirtualCellarListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucun cellier créé'), findsOneWidget);
      expect(find.text('Créer un cellier'), findsOneWidget);

      await tester.tap(find.text('Créer un cellier'));
      await tester.pumpAndSettle();

      await tester.enterText(_findTextField('Nom du cellier'), 'Cellier test');
      await tester.tap(find.widgetWithText(FilledButton, 'Créer'));
      await tester.pumpAndSettle();

      expect(repository.currentCellars, hasLength(1));
      expect(repository.currentCellars.single.name, 'Cellier test');
      expect(repository.currentCellars.single.rows, 5);
      expect(repository.currentCellars.single.columns, 5);
      expect(find.text('Cellier test'), findsOneWidget);
    });

    testWidgets('supprime un cellier existant depuis le menu', (tester) async {
      tester.view.physicalSize = const Size(1440, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeVirtualCellarRepository([
        const VirtualCellarEntity(
          id: 1,
          name: 'Cellier principal',
          rows: 5,
          columns: 5,
        ),
      ]);
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            virtualCellarRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: VirtualCellarListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cellier principal'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer').first);
      await tester.pumpAndSettle();

      expect(find.text('Supprimer le cellier ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(repository.currentCellars, isEmpty);
      expect(find.text('Aucun cellier créé'), findsOneWidget);
    });
  });
}

Finder _findTextField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}
