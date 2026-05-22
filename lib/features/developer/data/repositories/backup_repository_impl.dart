import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/developer/data/datasources/backup_local_datasource.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';
import 'package:wine_cellar/features/developer/domain/repositories/backup_repository.dart';

class BackupRepositoryImpl implements BackupRepository {
  final BackupLocalDatasource _datasource;

  const BackupRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, void>> exportBackup(
    BackupData data,
    String password,
  ) async {
    try {
      final plain = _datasource.serialise(data);
      final envelope = _datasource.encrypt(plain, password);
      await _datasource.writeAndShare(envelope);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Échec de l\'export de la sauvegarde.', cause: e));
    }
  }

  @override
  Future<Either<Failure, BackupData>> importBackup(String password) async {
    try {
      final envelope = await _datasource.pickAndRead();
      if (envelope == null) {
        return const Left(
          ValidationFailure('Aucun fichier sélectionné.'),
        );
      }
      final plain = _datasource.decrypt(envelope, password);
      final data = _datasource.deserialise(plain);
      return Right(data);
    } on ArgumentError catch (e) {
      // encrypt package throws ArgumentError on wrong password / corrupt data
      return Left(
        ValidationFailure(
          'Mot de passe incorrect ou fichier corrompu.',
          cause: e,
        ),
      );
    } catch (e) {
      return Left(
        CacheFailure('Échec de la restauration de la sauvegarde.', cause: e),
      );
    }
  }
}
