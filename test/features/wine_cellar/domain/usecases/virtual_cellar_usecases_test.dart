import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/create_virtual_cellar.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/delete_virtual_cellar.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/get_all_virtual_cellars.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/get_wine_placements.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_virtual_cellar.dart';

class _MockVirtualCellarRepository extends Mock
    implements VirtualCellarRepository {}

const _cellar = VirtualCellarEntity(
  id: 3,
  name: 'Mur nord',
  rows: 4,
  columns: 5,
  theme: VirtualCellarTheme.classic,
);

const _wine = WineEntity(
  id: 8,
  name: 'Pinot Noir',
  color: WineColor.red,
  quantity: 2,
);

final _placement = BottlePlacementEntity(
  id: 9,
  wineId: 8,
  cellarId: 3,
  positionX: 1,
  positionY: 2,
  createdAt: DateTime(2026),
  wine: _wine,
);

void main() {
  group('virtual cellar usecases', () {
    late _MockVirtualCellarRepository repository;

    setUp(() {
      repository = _MockVirtualCellarRepository();
    });

    test('CreateVirtualCellarUseCase délègue la création au repository', () async {
      when(() => repository.create(_cellar)).thenAnswer((_) async => const Right(12));

      final result = await CreateVirtualCellarUseCase(repository)(_cellar);

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => -1), 12);
      verify(() => repository.create(_cellar)).called(1);
    });

    test('CreateVirtualCellarUseCase propage l échec du repository', () async {
      const failure = CacheFailure('create failed');
      when(() => repository.create(_cellar))
          .thenAnswer((_) async => const Left(failure));

      final result = await CreateVirtualCellarUseCase(repository)(_cellar);

      expect(result, const Left(failure));
    });

    test('UpdateVirtualCellarUseCase délègue la mise à jour au repository', () async {
      when(() => repository.update(_cellar)).thenAnswer((_) async => const Right(unit));

      final result = await UpdateVirtualCellarUseCase(repository)(_cellar);

      expect(result.isRight(), isTrue);
      verify(() => repository.update(_cellar)).called(1);
    });

    test('DeleteVirtualCellarUseCase délègue la suppression au repository', () async {
      when(() => repository.delete(3)).thenAnswer((_) async => const Right(unit));

      final result = await DeleteVirtualCellarUseCase(repository)(3);

      expect(result.isRight(), isTrue);
      verify(() => repository.delete(3)).called(1);
    });

    test('GetAllVirtualCellarsUseCase retourne la liste et expose le stream', () async {
      when(() => repository.getAll())
          .thenAnswer((_) async => const Right([_cellar]));
      when(() => repository.watchAll())
          .thenAnswer((_) => Stream.value(const [_cellar]));

      final result = await GetAllVirtualCellarsUseCase(repository).call();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => const []), const [_cellar]);
      await expectLater(
        GetAllVirtualCellarsUseCase(repository).watch(),
        emits(const [_cellar]),
      );
    });

    test('GetWinePlacementsUseCase retourne les placements du repository', () async {
      when(() => repository.getPlacementsByWineId(8))
          .thenAnswer((_) async => Right([_placement]));

      final result = await GetWinePlacementsUseCase(repository)(8);

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => const []), [_placement]);
      verify(() => repository.getPlacementsByWineId(8)).called(1);
    });

    test('GetWinePlacementsUseCase propage l échec du repository', () async {
      const failure = CacheFailure('placements failed');
      when(() => repository.getPlacementsByWineId(8))
          .thenAnswer((_) async => const Left(failure));

      final result = await GetWinePlacementsUseCase(repository)(8);

      expect(result, const Left(failure));
    });
  });
}