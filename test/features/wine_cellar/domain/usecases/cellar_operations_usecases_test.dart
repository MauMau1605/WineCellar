import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/export_wines.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/move_bottles_in_cellar.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/place_wine_in_cellar.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/remove_bottle_placement.dart';

class _MockVirtualCellarRepository extends Mock
    implements VirtualCellarRepository {}

class _MockWineRepository extends Mock implements WineRepository {}

const _wine = WineEntity(
  id: 11,
  name: 'Riesling',
  color: WineColor.white,
  quantity: 2,
);

BottlePlacementEntity _placement({
  required int id,
  required int x,
  required int y,
}) {
  return BottlePlacementEntity(
    id: id,
    wineId: _wine.id!,
    cellarId: 7,
    positionX: x,
    positionY: y,
    createdAt: DateTime(2026),
    wine: _wine,
  );
}

void main() {
  group('cellar operation usecases', () {
    late _MockVirtualCellarRepository virtualRepository;
    late _MockWineRepository wineRepository;

    setUp(() {
      virtualRepository = _MockVirtualCellarRepository();
      wineRepository = _MockWineRepository();
    });

    test('PlaceWineInCellarUseCase délègue les coordonnées au repository', () async {
      when(
        () => virtualRepository.placeWine(
          11,
          cellarId: 7,
          positionX: 2,
          positionY: 3,
        ),
      ).thenAnswer((_) async => const Right(unit));

      final result = await PlaceWineInCellarUseCase(virtualRepository)(
        const PlaceWineParams(
          wineId: 11,
          cellarId: 7,
          positionX: 2,
          positionY: 3,
        ),
      );

      expect(result.isRight(), isTrue);
      verify(
        () => virtualRepository.placeWine(
          11,
          cellarId: 7,
          positionX: 2,
          positionY: 3,
        ),
      ).called(1);
    });

    test('RemoveBottlePlacementUseCase délègue la suppression au repository', () async {
      when(() => virtualRepository.removePlacement(21))
          .thenAnswer((_) async => const Right(unit));

      final result = await RemoveBottlePlacementUseCase(virtualRepository)(21);

      expect(result.isRight(), isTrue);
      verify(() => virtualRepository.removePlacement(21)).called(1);
    });

    test('ExportWinesUseCase exporte en JSON', () async {
      when(() => wineRepository.exportToJson())
          .thenAnswer((_) async => '{"count":1}');

      final result = await ExportWinesUseCase(wineRepository)(ExportFormat.json);

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => ''), '{"count":1}');
      verify(() => wineRepository.exportToJson()).called(1);
      verifyNever(() => wineRepository.exportToCsv());
    });

    test('ExportWinesUseCase exporte en CSV', () async {
      when(() => wineRepository.exportToCsv())
          .thenAnswer((_) async => 'name,color\nRiesling,white');

      final result = await ExportWinesUseCase(wineRepository)(ExportFormat.csv);

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => ''), 'name,color\nRiesling,white');
      verify(() => wineRepository.exportToCsv()).called(1);
      verifyNever(() => wineRepository.exportToJson());
    });

    test('ExportWinesUseCase retourne CacheFailure si le repository échoue', () async {
      when(() => wineRepository.exportToJson())
          .thenThrow(Exception('disk full'));

      final result = await ExportWinesUseCase(wineRepository)(ExportFormat.json);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<CacheFailure>());
          expect(failure.message, 'Échec de l\'export.');
        },
        (_) => fail('Doit retourner un CacheFailure'),
      );
    });

    test('MoveBottlesInCellar retourne immédiatement si la sélection est vide', () async {
      final result = await MoveBottlesInCellar(virtualRepository).call(
        allPlacements: [_placement(id: 1, x: 0, y: 0)],
        selectedPlacementIds: const {},
        anchorPlacementId: 1,
        targetAnchorX: 0,
        targetAnchorY: 0,
        maxColumns: 4,
        maxRows: 4,
      );

      expect(result.isRight(), isTrue);
      verifyNever(
        () => virtualRepository.moveBottleInCellar(
          placementId: any(named: 'placementId'),
          newPositionX: any(named: 'newPositionX'),
          newPositionY: any(named: 'newPositionY'),
        ),
      );
    });

    test('MoveBottlesInCellar échoue si l ancre est introuvable', () async {
      final result = await MoveBottlesInCellar(virtualRepository).call(
        allPlacements: [_placement(id: 1, x: 0, y: 0)],
        selectedPlacementIds: const {1},
        anchorPlacementId: 99,
        targetAnchorX: 1,
        targetAnchorY: 1,
        maxColumns: 4,
        maxRows: 4,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure.message,
          'Bouteille d ancrage introuvable.',
        ),
        (_) => fail('Doit retourner une erreur'),
      );
    });

    test('MoveBottlesInCellar échoue si le déplacement sort des limites', () async {
      final result = await MoveBottlesInCellar(virtualRepository).call(
        allPlacements: [_placement(id: 1, x: 0, y: 0)],
        selectedPlacementIds: const {1},
        anchorPlacementId: 1,
        targetAnchorX: -1,
        targetAnchorY: 0,
        maxColumns: 4,
        maxRows: 4,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure.message,
          'Déplacement hors des limites du cellier.',
        ),
        (_) => fail('Doit retourner une erreur'),
      );
    });

    test('MoveBottlesInCellar échoue si la cible est occupée par une autre bouteille', () async {
      final result = await MoveBottlesInCellar(virtualRepository).call(
        allPlacements: [
          _placement(id: 1, x: 0, y: 0),
          _placement(id: 2, x: 1, y: 0),
        ],
        selectedPlacementIds: const {1},
        anchorPlacementId: 1,
        targetAnchorX: 1,
        targetAnchorY: 0,
        maxColumns: 4,
        maxRows: 4,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure.message,
          'Impossible: emplacement cible occupé.',
        ),
        (_) => fail('Doit retourner une erreur'),
      );
    });

    test('MoveBottlesInCellar déplace les bouteilles sélectionnées avec succès', () async {
      when(
        () => virtualRepository.moveBottleInCellar(
          placementId: 2,
          newPositionX: 2,
          newPositionY: 1,
        ),
      ).thenAnswer((_) async => const Right(unit));
      when(
        () => virtualRepository.moveBottleInCellar(
          placementId: 1,
          newPositionX: 1,
          newPositionY: 1,
        ),
      ).thenAnswer((_) async => const Right(unit));

      final result = await MoveBottlesInCellar(virtualRepository).call(
        allPlacements: [
          _placement(id: 1, x: 0, y: 0),
          _placement(id: 2, x: 1, y: 0),
        ],
        selectedPlacementIds: const {1, 2},
        anchorPlacementId: 1,
        targetAnchorX: 1,
        targetAnchorY: 1,
        maxColumns: 4,
        maxRows: 4,
      );

      expect(result.isRight(), isTrue);
      verifyInOrder([
        () => virtualRepository.moveBottleInCellar(
          placementId: 2,
          newPositionX: 2,
          newPositionY: 1,
        ),
        () => virtualRepository.moveBottleInCellar(
          placementId: 1,
          newPositionX: 1,
          newPositionY: 1,
        ),
      ]);
    });

    test('MoveBottlesInCellar renvoie la première erreur repository rencontrée', () async {
      const failure = CacheFailure('slot blocked');
      when(
        () => virtualRepository.moveBottleInCellar(
          placementId: 1,
          newPositionX: 1,
          newPositionY: 0,
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await MoveBottlesInCellar(virtualRepository).call(
        allPlacements: [_placement(id: 1, x: 0, y: 0)],
        selectedPlacementIds: const {1},
        anchorPlacementId: 1,
        targetAnchorX: 1,
        targetAnchorY: 0,
        maxColumns: 4,
        maxRows: 4,
      );

      expect(result, const Left(failure));
    });
  });
}