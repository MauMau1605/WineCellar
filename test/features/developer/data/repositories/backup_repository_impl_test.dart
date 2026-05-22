import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/developer/data/datasources/backup_local_datasource.dart';
import 'package:wine_cellar/features/developer/data/repositories/backup_repository_impl.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';

class _MockBackupLocalDatasource extends Mock implements BackupLocalDatasource {}

class _FakeBackupData extends Fake implements BackupData {}

final _backupData = BackupData(
  config: {'ai_provider': 'openai'},
  secrets: null,
  winesJson: '[]',
  createdAt: DateTime(2026, 5, 21),
  version: 1,
);

const _serialised = '{"version":1,"config":{}}';
const _envelope = {'salt': 'AAAA', 'iv': 'BBBB', 'data': 'CCCC'};

void main() {
  late _MockBackupLocalDatasource datasource;
  late BackupRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_FakeBackupData());
  });

  setUp(() {
    datasource = _MockBackupLocalDatasource();
    repository = BackupRepositoryImpl(datasource);
  });

  group('BackupRepositoryImpl — exportBackup', () {
    test('retourne Right(null) quand toutes les étapes réussissent', () async {
      when(() => datasource.serialise(any())).thenReturn(_serialised);
      when(() => datasource.encrypt(any(), any())).thenReturn(_envelope);
      when(() => datasource.writeAndShare(any())).thenAnswer((_) async {});

      final result = await repository.exportBackup(_backupData, 'motdepasse');

      expect(result.isRight(), isTrue);
      verify(() => datasource.serialise(_backupData)).called(1);
      verify(() => datasource.encrypt(_serialised, 'motdepasse')).called(1);
      verify(() => datasource.writeAndShare(_envelope)).called(1);
    });

    test('retourne Left(CacheFailure) quand serialise lève une exception', () async {
      when(() => datasource.serialise(any())).thenThrow(Exception('Erreur JSON'));

      final result = await repository.exportBackup(_backupData, 'motdepasse');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<CacheFailure>()),
        (_) => fail('Devrait être un Left'),
      );
    });

    test('retourne Left(CacheFailure) quand writeAndShare lève une exception',
        () async {
      when(() => datasource.serialise(any())).thenReturn(_serialised);
      when(() => datasource.encrypt(any(), any())).thenReturn(_envelope);
      when(() => datasource.writeAndShare(any())).thenThrow(Exception('I/O error'));

      final result = await repository.exportBackup(_backupData, 'motdepasse');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<CacheFailure>()),
        (_) => fail('Devrait être un Left'),
      );
    });
  });

  group('BackupRepositoryImpl — importBackup', () {
    test('retourne Left(ValidationFailure) quand l\'utilisateur annule (null)', () async {
      when(() => datasource.pickAndRead()).thenAnswer((_) async => null);

      final result = await repository.importBackup('motdepasse');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, equals('Aucun fichier sélectionné.'));
        },
        (_) => fail('Devrait être un Left'),
      );
      verifyNever(() => datasource.decrypt(any(), any()));
    });

    test(
        'retourne Left(ValidationFailure) quand ArgumentError est levée '
        '(mot de passe incorrect ou fichier corrompu)', () async {
      when(() => datasource.pickAndRead()).thenAnswer((_) async => {'salt': '', 'iv': '', 'data': ''});
      when(() => datasource.decrypt(any(), any()))
          .thenThrow(ArgumentError('Bad data'));

      final result = await repository.importBackup('mauvais');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            equals('Mot de passe incorrect ou fichier corrompu.'),
          );
        },
        (_) => fail('Devrait être un Left'),
      );
    });

    test('retourne Left(CacheFailure) pour toute autre exception', () async {
      when(() => datasource.pickAndRead())
          .thenThrow(Exception('Erreur lecture disque'));

      final result = await repository.importBackup('motdepasse');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<CacheFailure>()),
        (_) => fail('Devrait être un Left'),
      );
    });

    test('retourne Right(BackupData) quand tout se passe bien', () async {
      when(() => datasource.pickAndRead())
          .thenAnswer((_) async => {'salt': 'AAAA', 'iv': 'BBBB', 'data': 'CCCC'});
      when(() => datasource.decrypt(any(), any())).thenReturn(_serialised);
      when(() => datasource.deserialise(any())).thenReturn(_backupData);

      final result = await repository.importBackup('motdepasse');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Devrait être un Right'),
        (data) => expect(data, equals(_backupData)),
      );
      verify(
        () => datasource.decrypt({'salt': 'AAAA', 'iv': 'BBBB', 'data': 'CCCC'}, 'motdepasse'),
      ).called(1);
      verify(() => datasource.deserialise(_serialised)).called(1);
    });
  });
}
