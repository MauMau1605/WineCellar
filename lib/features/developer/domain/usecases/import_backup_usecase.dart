import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';
import 'package:wine_cellar/features/developer/domain/repositories/backup_repository.dart';

/// Parameters required to import a backup.
class ImportBackupParams {
  /// Decryption password entered by the user.
  final String password;

  const ImportBackupParams({required this.password});
}

/// Lets the user pick a `.wce` backup file, decrypts it with [password] and
/// returns the deserialised [BackupData] ready to be applied by the provider.
class ImportBackupUseCase implements UseCase<BackupData, ImportBackupParams> {
  final BackupRepository _repository;

  const ImportBackupUseCase(this._repository);

  @override
  Future<Either<Failure, BackupData>> call(ImportBackupParams params) {
    if (params.password.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Le mot de passe ne peut pas être vide.')),
      );
    }
    return _repository.importBackup(params.password);
  }
}
