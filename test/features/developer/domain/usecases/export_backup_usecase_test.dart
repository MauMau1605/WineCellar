import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';
import 'package:wine_cellar/features/developer/domain/repositories/backup_repository.dart';
import 'package:wine_cellar/features/developer/domain/usecases/export_backup_usecase.dart';

class _MockBackupRepository extends Mock implements BackupRepository {}

class _FakeBackupData extends Fake implements BackupData {}

final _backupData = BackupData(
  config: {'ai_provider': 'openai', 'wine_list_layout': 'auto'},
  secrets: null,
  winesJson: '[]',
  createdAt: DateTime(2026, 5, 21),
  version: 1,
);

void main() {
  late _MockBackupRepository repository;
  late ExportBackupUseCase useCase;

  setUpAll(() {
    registerFallbackValue(_FakeBackupData());
  });

  setUp(() {
    repository = _MockBackupRepository();
    useCase = ExportBackupUseCase(repository);
  });

  group('ExportBackupUseCase', () {
    test('retourne ValidationFailure quand le mot de passe est vide', () async {
      final result = await useCase(
        ExportBackupParams(password: '', data: _backupData),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Devrait être un Left'),
      );
      verifyNever(
        () => repository.exportBackup(any(), any()),
      );
    });

    test('délègue au repository quand le mot de passe est valide', () async {
      when(
        () => repository.exportBackup(any(), any()),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(
        ExportBackupParams(password: 'motdepasse', data: _backupData),
      );

      expect(result.isRight(), isTrue);
      verify(() => repository.exportBackup(_backupData, 'motdepasse')).called(1);
    });

    test('propage le Left du repository en cas d\'échec', () async {
      when(
        () => repository.exportBackup(any(), any()),
      ).thenAnswer(
        (_) async => const Left(CacheFailure('Échec de l\'export.')),
      );

      final result = await useCase(
        ExportBackupParams(password: 'motdepasse', data: _backupData),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<CacheFailure>()),
        (_) => fail('Devrait être un Left'),
      );
    });

    test('transmet exactement les params au repository', () async {
      final dataWithSecrets = BackupData(
        config: {'ai_provider': 'gemini'},
        secrets: {'openai_api_key': 'sk-test'},
        winesJson: '[{"id":1}]',
        createdAt: DateTime(2026, 5, 21),
        version: 1,
      );

      when(
        () => repository.exportBackup(any(), any()),
      ).thenAnswer((_) async => const Right(null));

      await useCase(
        ExportBackupParams(password: 'secret42', data: dataWithSecrets),
      );

      final captured = verify(
        () => repository.exportBackup(captureAny(), captureAny()),
      ).captured;
      expect(captured[0], dataWithSecrets);
      expect(captured[1], 'secret42');
    });
  });
}
