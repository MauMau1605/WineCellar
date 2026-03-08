import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

class ImportWinesFromCsvParams {
  final String csvContent;
  final CsvColumnMapping mapping;
  final bool hasHeader;

  const ImportWinesFromCsvParams({
    required this.csvContent,
    required this.mapping,
    this.hasHeader = true,
  });
}

class ImportWinesFromCsvUseCase
    implements UseCase<int, ImportWinesFromCsvParams> {
  final WineRepository _repository;

  const ImportWinesFromCsvUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(ImportWinesFromCsvParams params) async {
    try {
      if (params.csvContent.trim().isEmpty) {
        return const Left(ValidationFailure('Le fichier CSV est vide.'));
      }

      if (!params.mapping.hasMinimumFields) {
        return const Left(
          ValidationFailure('La colonne "Nom" est obligatoire pour l\'import.'),
        );
      }

      final importedCount = await _repository.importFromCsv(
        params.csvContent,
        params.mapping,
        hasHeader: params.hasHeader,
      );

      if (importedCount == 0) {
        return const Left(
          ValidationFailure('Aucun vin importé. Vérifiez le mapping des colonnes.'),
        );
      }

      return Right(importedCount);
    } catch (e) {
      return Left(CacheFailure('Échec de l\'import CSV.', cause: e));
    }
  }
}
