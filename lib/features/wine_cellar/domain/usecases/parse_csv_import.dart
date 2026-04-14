import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_import_row.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

class ParseCsvImportParams {
  final String csvContent;
  final CsvColumnMapping mapping;
  final int? headerLine;

  const ParseCsvImportParams({
    required this.csvContent,
    required this.mapping,
    this.headerLine,
  });
}

class ParseCsvImportUseCase
    implements UseCase<List<CsvImportRow>, ParseCsvImportParams> {
  final WineRepository _repository;

  const ParseCsvImportUseCase(this._repository);

  @override
  Future<Either<Failure, List<CsvImportRow>>> call(
    ParseCsvImportParams params,
  ) async {
    try {
      if (params.csvContent.trim().isEmpty) {
        return const Left(ValidationFailure('Le fichier CSV est vide.'));
      }

      if (!params.mapping.hasMinimumFields) {
        return const Left(
          ValidationFailure('La colonne "Nom" est obligatoire pour l\'import.'),
        );
      }

      final rows = await _repository.parseCsvRows(
        params.csvContent,
        params.mapping,
        headerLine: params.headerLine,
      );

      if (rows.isEmpty) {
        return const Left(ValidationFailure('Aucune ligne exploitable trouvée dans le CSV.'));
      }

      return Right(rows);
    } catch (e) {
      return Left(CacheFailure('Échec de l\'analyse du fichier CSV.', cause: e));
    }
  }
}
