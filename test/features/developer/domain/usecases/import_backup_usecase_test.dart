import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';
import 'package:wine_cellar/features/developer/domain/repositories/backup_repository.dart';
import 'package:wine_cellar/features/developer/domain/usecases/import_backup_usecase.dart';

class _MockBackupRepository extends Mock implements BackupRepository {}

final _backupData = BackupData(
  config: {'ai_provider': 'openai'},
  secrets: null,
  winesJson: '[]',
  createdAt: DateTime(2026, 5, 21),
  version: 1,
);

void main() {
  late _MockBackupRepository repository;
  late ImportBackupUseCase useCase;

  setUp(() {
    repository = _MockBackupRepository();
    useCase = ImportBackupUseCase(repository);
  });

  group('ImportBackupUseCase', () {
    test('retourne ValidationFailure quand le mot de passe est vide', () async {
      final result = await useCase(ImportBackupParams(password: ''));

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Devrait être un Left'),
      );
      verifyNever(() => repository.importBackup(any()));
    });

    test('retourne Right(BackupData) quand le repository réussit', () async {
      when(
        () => repository.importBackup(any()),
      ).thenAnswer((_) async => Right(_backupData));

      final result = await useCase(ImportBackupParams(password: 'motdepasse'));

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Devrait être un Right'),
        (data) => expect(data, _backupData),
      );
      verify(() => repository.importBackup('motdepasse')).called(1);
    });

    test('propage le Left du repository en cas d\'échec', () async {
      when(
        () => repository.importBackup(any()),
      ).thenAnswer(
        (_) async =>
            const Left(CacheFailure('Échec de la restauration.')),
      );

      final result = await useCase(ImportBackupParams(password: 'motdepasse'));

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<CacheFailure>()),
        (_) => fail('Devrait être un Left'),
      );
    });

    test('transmet le mot de passe exact au repository', () async {
      when(
        () => repository.importBackup(any()),
      ).thenAnswer((_) async => Right(_backupData));

      await useCase(ImportBackupParams(password: 'MonMotDePasseSecret!99'));

      verify(
        () => repository.importBackup('MonMotDePasseSecret!99'),
      ).called(1);
    });
  });
}
