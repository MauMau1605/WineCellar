import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/domain/repositories/statistics_repository.dart';

/// Retrieve computed statistics for the entire cellar.
class GetCellarStatisticsUseCase implements UseCase<CellarStatistics, NoParams> {
  final StatisticsRepository _repository;

  const GetCellarStatisticsUseCase(this._repository);

  @override
  Future<Either<Failure, CellarStatistics>> call(NoParams params) async {
    try {
      final stats = await _repository.getCellarStatistics();
      return Right(stats);
    } catch (e) {
      return Left(
        CacheFailure('Impossible de calculer les statistiques.', cause: e),
      );
    }
  }
}
