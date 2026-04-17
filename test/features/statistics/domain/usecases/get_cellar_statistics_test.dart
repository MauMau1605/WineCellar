import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:wine_cellar/features/statistics/domain/usecases/get_cellar_statistics.dart';

class _MockStatisticsRepository extends Mock implements StatisticsRepository {}

void main() {
  late _MockStatisticsRepository repository;
  late GetCellarStatisticsUseCase useCase;

  setUp(() {
    repository = _MockStatisticsRepository();
    useCase = GetCellarStatisticsUseCase(repository);
  });

  test('retourne CellarStatistics avec succès', () async {
    const stats = CellarStatistics(
      overview: OverviewStats(totalReferences: 5, totalBottles: 20),
      colorDistribution: [],
      maturityDistribution: [],
      regionDistribution: [],
      appellationDistribution: [],
      countryDistribution: [],
      vintageDistribution: [],
      grapeDistribution: [],
      ratingDistribution: [],
      priceStats: PriceStats.empty,
      producerDistribution: [],
    );

    when(() => repository.getCellarStatistics())
        .thenAnswer((_) async => stats);

    final result = await useCase(const NoParams());

    expect(result.isRight(), isTrue);
    result.fold(
      (failure) => fail('Doit retourner les statistiques'),
      (data) {
        expect(data.overview.totalReferences, 5);
        expect(data.overview.totalBottles, 20);
      },
    );
    verify(() => repository.getCellarStatistics()).called(1);
  });

  test('retourne CellarStatistics.empty quand la cave est vide', () async {
    when(() => repository.getCellarStatistics())
        .thenAnswer((_) async => CellarStatistics.empty);

    final result = await useCase(const NoParams());

    expect(result.isRight(), isTrue);
    result.fold(
      (failure) => fail('Doit retourner les statistiques vides'),
      (data) {
        expect(data.isEmpty, isTrue);
        expect(data.overview.totalBottles, 0);
      },
    );
  });

  test('retourne CacheFailure si le repository échoue', () async {
    when(() => repository.getCellarStatistics())
        .thenThrow(Exception('database locked'));

    final result = await useCase(const NoParams());

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) {
        expect(failure, isA<CacheFailure>());
        expect(
            failure.message, 'Impossible de calculer les statistiques.');
      },
      (_) => fail('Doit retourner un Failure'),
    );
  });
}
