import 'package:csv/csv.dart';
import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Use case that exports a filtered list of wines as a CSV string.
///
/// This is a **pure transformation** — no repository is involved.
/// The CSV column order matches [WineRepositoryImpl.exportToCsv] so the
/// resulting file is fully compatible with the existing import flow.
///
/// Returns [Right] with the CSV string on success, or [Left] with a
/// [CacheFailure] if conversion fails unexpectedly.
class ExportFilteredWinesCsvUseCase
    implements UseCase<String, List<WineEntity>> {
  const ExportFilteredWinesCsvUseCase();

  @override
  Future<Either<Failure, String>> call(List<WineEntity> params) async {
    try {
      final rows = <List<dynamic>>[
        // Header row — must stay in sync with WineRepositoryImpl.exportToCsv
        [
          'Nom',
          'Appellation',
          'Producteur',
          'Région',
          'Pays',
          'Couleur',
          'Millésime',
          'Cépages',
          'Quantité',
          'Prix achat',
          'Boire à partir de',
          'Boire jusqu\'à',
          'Notes',
          'Note (/5)',
          'Localisation',
          'Position cave X',
          'Position cave Y',
          'IA: accords mets-vins',
          'IA: boire dès',
          'IA: boire jusqu\'à',
        ],
        // Data rows
        ...params.map(
          (w) => [
            w.name,
            w.appellation ?? '',
            w.producer ?? '',
            w.region ?? '',
            w.country,
            w.color.label,
            w.vintage?.toString() ?? '',
            w.grapeVarieties.join(', '),
            w.quantity,
            w.purchasePrice?.toStringAsFixed(2) ?? '',
            w.drinkFromYear?.toString() ?? '',
            w.drinkUntilYear?.toString() ?? '',
            w.tastingNotes ?? '',
            w.rating?.toString() ?? '',
            w.location ?? '',
            w.cellarPositionX?.toString() ?? '',
            w.cellarPositionY?.toString() ?? '',
            w.aiSuggestedFoodPairings ? 'true' : 'false',
            w.aiSuggestedDrinkFromYear ? 'true' : 'false',
            w.aiSuggestedDrinkUntilYear ? 'true' : 'false',
          ],
        ),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      return Right(csv);
    } catch (e, st) {
      return Left(
        CacheFailure(
          'Failed to generate CSV: $e',
          cause: st,
        ),
      );
    }
  }
}
