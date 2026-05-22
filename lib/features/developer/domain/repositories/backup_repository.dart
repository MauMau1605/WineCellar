import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';

/// Contract for saving and restoring an encrypted application backup.
abstract class BackupRepository {
  /// Serialises [data] to JSON, encrypts it with [password] (AES-256-CBC /
  /// PBKDF2) and writes the result to a user-chosen location via the platform
  /// share / save dialog.
  ///
  /// Returns [Right(null)] on success, or a [CacheFailure] / [ValidationFailure]
  /// on error.
  Future<Either<Failure, void>> exportBackup(
    BackupData data,
    String password,
  );

  /// Asks the user to pick a `.wce` file, decrypts its content using [password]
  /// and deserialises it back to a [BackupData].
  ///
  /// Returns [Right(BackupData)] on success, or a failure otherwise.
  Future<Either<Failure, BackupData>> importBackup(String password);
}
