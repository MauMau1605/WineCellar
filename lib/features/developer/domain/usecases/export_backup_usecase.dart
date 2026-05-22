import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';
import 'package:wine_cellar/features/developer/domain/repositories/backup_repository.dart';

/// Parameters required to export a backup.
class ExportBackupParams {
  /// Encryption password chosen by the user.
  final String password;

  /// The full backup payload to serialise and encrypt.
  final BackupData data;

  const ExportBackupParams({required this.password, required this.data});
}

/// Encrypts and exports the full application backup (cave + config + optional
/// secrets) to a user-chosen location.
///
/// The [BackupData.secrets] field must already be populated (or null) by the
/// caller before invoking this use case — the use case itself does not decide
/// whether secrets are included.
class ExportBackupUseCase implements UseCase<void, ExportBackupParams> {
  final BackupRepository _repository;

  const ExportBackupUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ExportBackupParams params) {
    if (params.password.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Le mot de passe ne peut pas être vide.')),
      );
    }
    return _repository.exportBackup(params.data, params.password);
  }
}
