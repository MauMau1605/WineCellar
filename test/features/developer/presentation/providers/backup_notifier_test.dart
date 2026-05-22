import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';
import 'package:wine_cellar/features/developer/domain/usecases/export_backup_usecase.dart';
import 'package:wine_cellar/features/developer/domain/usecases/import_backup_usecase.dart';
import 'package:wine_cellar/features/developer/presentation/providers/backup_provider.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class _MockExportBackupUseCase extends Mock implements ExportBackupUseCase {}

class _MockImportBackupUseCase extends Mock implements ImportBackupUseCase {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockWineRepository extends Mock implements WineRepository {}

// ── Fakes (pour registerFallbackValue) ──────────────────────────────────────

class _FakeExportBackupParams extends Fake implements ExportBackupParams {}

class _FakeImportBackupParams extends Fake implements ImportBackupParams {}

// ── Fixtures ─────────────────────────────────────────────────────────────────

final _restoredData = BackupData(
  // Config vide → _applyConfig ne positionne que setTheme(null)
  config: {},
  secrets: null,
  winesJson: '[]', // '[]' → _applyWines retourne immédiatement sans appel de use case
  createdAt: DateTime(2026, 5, 21),
  version: 1,
);

// ── Helper ────────────────────────────────────────────────────────────────────

ProviderContainer _createContainer({
  required _MockExportBackupUseCase exportUseCase,
  required _MockImportBackupUseCase importUseCase,
  required _MockSecureStorage storage,
  required _MockWineRepository wineRepository,
}) {
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      wineRepositoryProvider.overrideWith((ref) => wineRepository),
      exportBackupUseCaseProvider.overrideWith((ref) => exportUseCase),
      importBackupUseCaseProvider.overrideWith((ref) => importUseCase),
    ],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeExportBackupParams());
    registerFallbackValue(_FakeImportBackupParams());
  });

  late _MockExportBackupUseCase exportUseCase;
  late _MockImportBackupUseCase importUseCase;
  late _MockSecureStorage storage;
  late _MockWineRepository wineRepository;
  late ProviderContainer container;

  setUp(() {
    exportUseCase = _MockExportBackupUseCase();
    importUseCase = _MockImportBackupUseCase();
    storage = _MockSecureStorage();
    wineRepository = _MockWineRepository();

    // Stubs universels pour FlutterSecureStorage
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});

    container = _createContainer(
      exportUseCase: exportUseCase,
      importUseCase: importUseCase,
      storage: storage,
      wineRepository: wineRepository,
    );
  });

  tearDown(() => container.dispose());

  group('BackupNotifier', () {
    test('état initial est BackupIdle', () {
      expect(container.read(backupNotifierProvider), isA<BackupIdle>());
    });

    test('reset() remet l\'état à BackupIdle', () async {
      when(() => exportUseCase(any())).thenAnswer(
        (_) async => const Left(CacheFailure('Erreur')),
      );
      when(() => wineRepository.exportToJson()).thenAnswer((_) async => '[]');

      await container
          .read(backupNotifierProvider.notifier)
          .exportBackup('motdepasse');

      expect(container.read(backupNotifierProvider), isA<BackupError>());

      container.read(backupNotifierProvider.notifier).reset();

      expect(container.read(backupNotifierProvider), isA<BackupIdle>());
    });

    group('exportBackup', () {
      setUp(() {
        when(() => wineRepository.exportToJson()).thenAnswer((_) async => '[]');
      });

      test('passe à BackupSuccess quand le use case réussit', () async {
        when(() => exportUseCase(any()))
            .thenAnswer((_) async => const Right(null));

        await container
            .read(backupNotifierProvider.notifier)
            .exportBackup('motdepasse');

        expect(container.read(backupNotifierProvider), isA<BackupSuccess>());
        verify(() => exportUseCase(any())).called(1);
      });

      test('passe à BackupError quand le use case retourne Left', () async {
        when(() => exportUseCase(any())).thenAnswer(
          (_) async => const Left(CacheFailure('Échec de l\'export.')),
        );

        await container
            .read(backupNotifierProvider.notifier)
            .exportBackup('motdepasse');

        final state = container.read(backupNotifierProvider);
        expect(state, isA<BackupError>());
        expect((state as BackupError).message, equals('Échec de l\'export.'));
      });

      test(
          'le message de succès mentionne les secrets quand le mode dev est actif',
          () async {
        // Simuler le mode développeur actif via la valeur du provider
        when(() => storage.read(key: any(named: 'key')))
            .thenAnswer((_) async => null);
        // Forcer developerModeProvider à true via override direct
        final devContainer = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            wineRepositoryProvider.overrideWith((ref) => wineRepository),
            exportBackupUseCaseProvider.overrideWith(
              (ref) => exportUseCase,
            ),
            importBackupUseCaseProvider.overrideWith(
              (ref) => importUseCase,
            ),
            developerModeProvider.overrideWith(
              (ref) => SecureBoolNotifier(storage, 'developer_mode',
                  defaultValue: true),
            ),
          ],
        );
        addTearDown(devContainer.dispose);

        when(() => exportUseCase(any()))
            .thenAnswer((_) async => const Right(null));

        await devContainer
            .read(backupNotifierProvider.notifier)
            .exportBackup('motdepasse');

        final state = devContainer.read(backupNotifierProvider);
        expect(state, isA<BackupSuccess>());
        expect(
          (state as BackupSuccess).message,
          contains('secrets'),
        );
      });
    });

    group('importBackup', () {
      test('passe à BackupSuccess quand le use case réussit', () async {
        when(() => importUseCase(any()))
            .thenAnswer((_) async => Right(_restoredData));

        await container
            .read(backupNotifierProvider.notifier)
            .importBackup('motdepasse');

        expect(container.read(backupNotifierProvider), isA<BackupSuccess>());
        verify(() => importUseCase(any())).called(1);
      });

      test(
          'le message de succès ne mentionne pas les secrets '
          'quand BackupData.secrets est null', () async {
        when(() => importUseCase(any()))
            .thenAnswer((_) async => Right(_restoredData));

        await container
            .read(backupNotifierProvider.notifier)
            .importBackup('motdepasse');

        final state = container.read(backupNotifierProvider);
        expect(state, isA<BackupSuccess>());
        expect((state as BackupSuccess).message, isNot(contains('secrets')));
      });

      test('passe à BackupError quand le use case retourne Left', () async {
        when(() => importUseCase(any())).thenAnswer(
          (_) async =>
              const Left(ValidationFailure('Aucun fichier sélectionné.')),
        );

        await container
            .read(backupNotifierProvider.notifier)
            .importBackup('motdepasse');

        final state = container.read(backupNotifierProvider);
        expect(state, isA<BackupError>());
        expect(
          (state as BackupError).message,
          equals('Aucun fichier sélectionné.'),
        );
      });

      test(
          'le message de succès mentionne les secrets '
          'quand BackupData.secrets est non null', () async {
        final dataWithSecrets = BackupData(
          config: {},
          secrets: {'openai_api_key': 'sk-test'},
          winesJson: '[]',
          createdAt: DateTime(2026, 5, 21),
          version: 1,
        );

        when(() => importUseCase(any()))
            .thenAnswer((_) async => Right(dataWithSecrets));

        await container
            .read(backupNotifierProvider.notifier)
            .importBackup('motdepasse');

        final state = container.read(backupNotifierProvider);
        expect(state, isA<BackupSuccess>());
        expect((state as BackupSuccess).message, contains('secrets inclus'));
      });
    });
  });
}
