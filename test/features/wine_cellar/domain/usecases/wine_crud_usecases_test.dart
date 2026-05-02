import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/add_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/delete_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/get_wine_by_id.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';

class _MockWineRepository extends Mock implements WineRepository {}

const _wine = WineEntity(
  id: 1,
  name: 'Chardonnay',
  color: WineColor.white,
  quantity: 3,
);

const _wineWithoutId = WineEntity(
  name: 'Syrah',
  color: WineColor.red,
  quantity: 2,
);

const _invalidWine = WineEntity(
  id: 4,
  name: '   ',
  color: WineColor.red,
);

void main() {
  group('wine CRUD usecases', () {
    late _MockWineRepository repository;

    setUp(() {
      repository = _MockWineRepository();
    });

    test('AddWineUseCase ajoute un vin valide', () async {
      when(() => repository.addWine(_wineWithoutId)).thenAnswer((_) async => 42);

      final result = await AddWineUseCase(repository)(_wineWithoutId);

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => -1), 42);
      verify(() => repository.addWine(_wineWithoutId)).called(1);
    });

    test('AddWineUseCase rejette un nom vide', () async {
      final result = await AddWineUseCase(repository)(_invalidWine);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, 'Le nom du vin est obligatoire.');
        },
        (_) => fail('Doit retourner une erreur de validation'),
      );
      verifyNever(() => repository.addWine(_invalidWine));
    });

    test('AddWineUseCase retourne CacheFailure si le repository échoue', () async {
      when(() => repository.addWine(_wineWithoutId))
          .thenThrow(Exception('db down'));

      final result = await AddWineUseCase(repository)(_wineWithoutId);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<CacheFailure>());
          expect(failure.message, 'Impossible d\'ajouter le vin.');
        },
        (_) => fail('Doit retourner un CacheFailure'),
      );
    });

    test('UpdateWineUseCase modifie un vin valide', () async {
      when(() => repository.updateWine(_wine)).thenAnswer((_) async {});

      final result = await UpdateWineUseCase(repository)(_wine);

      expect(result.isRight(), isTrue);
      verify(() => repository.updateWine(_wine)).called(1);
    });

    test('UpdateWineUseCase rejette un vin sans identifiant', () async {
      final result = await UpdateWineUseCase(repository)(_wineWithoutId);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'Impossible de modifier un vin sans identifiant.',
          );
        },
        (_) => fail('Doit retourner une erreur de validation'),
      );
      verifyNever(() => repository.updateWine(_wineWithoutId));
    });

    test('UpdateWineUseCase rejette un nom vide', () async {
      final result = await UpdateWineUseCase(repository)(_invalidWine);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, 'Le nom du vin est obligatoire.');
        },
        (_) => fail('Doit retourner une erreur de validation'),
      );
      verifyNever(() => repository.updateWine(_invalidWine));
    });

    test('DeleteWineUseCase supprime un vin', () async {
      when(() => repository.deleteWine(7)).thenAnswer((_) async {});

      final result = await DeleteWineUseCase(repository)(7);

      expect(result.isRight(), isTrue);
      verify(() => repository.deleteWine(7)).called(1);
    });

    test('DeleteWineUseCase retourne CacheFailure si le repository échoue', () async {
      when(() => repository.deleteWine(7)).thenThrow(Exception('locked'));

      final result = await DeleteWineUseCase(repository)(7);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<CacheFailure>());
          expect(failure.message, 'Impossible de supprimer le vin.');
        },
        (_) => fail('Doit retourner un CacheFailure'),
      );
    });

    test('GetWineByIdUseCase récupère un vin existant', () async {
      when(() => repository.getWineById(1)).thenAnswer((_) async => _wine);

      final result = await GetWineByIdUseCase(repository)(1);

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => null), _wine);
      verify(() => repository.getWineById(1)).called(1);
    });

    test('GetWineByIdUseCase retourne CacheFailure si le repository échoue', () async {
      when(() => repository.getWineById(1)).thenThrow(Exception('db error'));

      final result = await GetWineByIdUseCase(repository)(1);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<CacheFailure>());
          expect(failure.message, 'Impossible de récupérer le vin.');
        },
        (_) => fail('Doit retourner un CacheFailure'),
      );
    });

    test('UpdateWineQuantityUseCase borne une quantité négative à zéro', () async {
      when(() => repository.updateQuantity(1, 0)).thenAnswer((_) async {});

      final result = await UpdateWineQuantityUseCase(repository)(
        const UpdateQuantityParams(wineId: 1, newQuantity: -3),
      );

      expect(result.isRight(), isTrue);
      verify(() => repository.updateQuantity(1, 0)).called(1);
    });

    test('UpdateWineQuantityUseCase supprime le vin si action delete à zéro', () async {
      when(() => repository.deleteWine(1)).thenAnswer((_) async {});

      final result = await UpdateWineQuantityUseCase(repository).callWithAction(
        const UpdateQuantityParams(wineId: 1, newQuantity: 0),
        ZeroQuantityAction.delete,
      );

      expect(result.isRight(), isTrue);
      verify(() => repository.deleteWine(1)).called(1);
      verifyNever(() => repository.updateQuantity(any(), any()));
    });

    test('UpdateWineQuantityUseCase garde le vin à zéro si action keep', () async {
      when(() => repository.updateQuantity(1, 0)).thenAnswer((_) async {});

      final result = await UpdateWineQuantityUseCase(repository).callWithAction(
        const UpdateQuantityParams(wineId: 1, newQuantity: 0),
        ZeroQuantityAction.keep,
      );

      expect(result.isRight(), isTrue);
      verify(() => repository.updateQuantity(1, 0)).called(1);
      verifyNever(() => repository.deleteWine(any()));
    });

    test('UpdateWineQuantityUseCase retourne CacheFailure si le repository échoue', () async {
      when(() => repository.updateQuantity(1, 2))
          .thenThrow(Exception('write failed'));

      final result = await UpdateWineQuantityUseCase(repository)(
        const UpdateQuantityParams(wineId: 1, newQuantity: 2),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<CacheFailure>());
          expect(failure.message, 'Impossible de mettre à jour la quantité.');
        },
        (_) => fail('Doit retourner un CacheFailure'),
      );
    });
  });
}