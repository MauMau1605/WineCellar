import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

/// Supported export formats.
enum ExportFormat { json, csv }

/// Export the entire wine cellar as a formatted string (JSON or CSV).
class ExportWinesUseCase implements UseCase<String, ExportFormat> {
  final WineRepository _repository;

  const ExportWinesUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(ExportFormat format) async {
    try {
      switch (format) {
        case ExportFormat.json:
          final data = await _repository.exportToJson();
          return Right(data);
        case ExportFormat.csv:
          final data = await _repository.exportToCsv();
          return Right(data);
      }
    } catch (e) {
      return Left(CacheFailure('Échec de l\'export.', cause: e));
    }
  }
}
