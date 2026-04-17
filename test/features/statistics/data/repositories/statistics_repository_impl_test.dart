import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/statistics/data/repositories/statistics_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

class _MockWineRepository extends Mock implements WineRepository {}

void main() {
  late _MockWineRepository wineRepository;
  late StatisticsRepositoryImpl repository;

  setUp(() {
    wineRepository = _MockWineRepository();
    repository = StatisticsRepositoryImpl(wineRepository);
  });

  WineEntity makeWine({
    String name = 'Test',
    WineColor color = WineColor.red,
    int quantity = 1,
    String? region,
    String? appellation,
    String country = 'France',
    int? vintage,
    double? purchasePrice,
    int? rating,
    String? producer,
    List<String> grapeVarieties = const [],
    int? drinkFromYear,
    int? drinkUntilYear,
  }) {
    return WineEntity(
      id: null,
      name: name,
      color: color,
      quantity: quantity,
      country: country,
      region: region,
      appellation: appellation,
      vintage: vintage,
      purchasePrice: purchasePrice,
      rating: rating,
      producer: producer,
      grapeVarieties: grapeVarieties,
      foodCategoryIds: const [],
      drinkFromYear: drinkFromYear,
      drinkUntilYear: drinkUntilYear,
      aiSuggestedFoodPairings: false,
      aiSuggestedDrinkFromYear: false,
      aiSuggestedDrinkUntilYear: false,
    );
  }

  test('retourne empty quand pas de vins', () async {
    when(() => wineRepository.getAllWines()).thenAnswer((_) async => []);

    final stats = await repository.getCellarStatistics();

    expect(stats.isEmpty, isTrue);
    expect(stats.overview.totalBottles, 0);
  });

  test('calcule les statistiques de base correctement', () async {
    final wines = [
      makeWine(
        name: 'Margaux',
        color: WineColor.red,
        quantity: 3,
        region: 'Bordeaux',
        country: 'France',
        vintage: 2018,
        purchasePrice: 25.0,
        rating: 4,
        producer: 'Ch. Margaux',
      ),
      makeWine(
        name: 'Chablis',
        color: WineColor.white,
        quantity: 2,
        region: 'Bourgogne',
        country: 'France',
        vintage: 2020,
        purchasePrice: 15.0,
        rating: 3,
        producer: 'Dom. Laroche',
        grapeVarieties: ['Chardonnay'],
      ),
    ];

    when(() => wineRepository.getAllWines()).thenAnswer((_) async => wines);

    final stats = await repository.getCellarStatistics();

    // Overview
    expect(stats.overview.totalReferences, 2);
    expect(stats.overview.totalBottles, 5);
    expect(stats.overview.oldestVintage, 2018);
    expect(stats.overview.newestVintage, 2020);

    // Color distribution
    expect(stats.colorDistribution.length, 2);
    expect(stats.colorDistribution.first.bottles, 3); // red: most bottles

    // Region distribution
    expect(stats.regionDistribution.length, 2);

    // Country distribution
    expect(stats.countryDistribution.length, 1);
    expect(stats.countryDistribution.first.bottles, 5);

    // Vintage
    expect(stats.vintageDistribution.length, 2);

    // Grapes
    expect(stats.grapeDistribution.length, 1);
    expect(stats.grapeDistribution.first.grape, 'Chardonnay');

    // Ratings
    expect(stats.ratingDistribution.length, 6); // 0-5

    // Price
    expect(stats.priceStats.hasData, isTrue);
    expect(stats.priceStats.minPrice, 15.0);
    expect(stats.priceStats.maxPrice, 25.0);

    // Producer
    expect(stats.producerDistribution.length, 2);
  });

  test('gère les valeurs nulles dans les champs optionnels', () async {
    final wines = [
      makeWine(name: 'Vin inconnu', color: WineColor.red, quantity: 1),
    ];

    when(() => wineRepository.getAllWines()).thenAnswer((_) async => wines);

    final stats = await repository.getCellarStatistics();

    expect(stats.overview.totalReferences, 1);
    expect(stats.overview.totalBottles, 1);
    expect(stats.overview.averagePrice, isNull);
    expect(stats.overview.averageRating, isNull);
    expect(stats.overview.oldestVintage, isNull);
    expect(stats.vintageDistribution, isEmpty);
    expect(stats.grapeDistribution, isEmpty);
    expect(stats.priceStats.hasData, isFalse);
    expect(stats.producerDistribution, isEmpty);
    expect(stats.regionDistribution, isEmpty);
    expect(stats.appellationDistribution, isEmpty);
  });

  test('calcule les pourcentages correctement', () async {
    final wines = [
      makeWine(name: 'Rouge', color: WineColor.red, quantity: 3),
      makeWine(name: 'Blanc', color: WineColor.white, quantity: 1),
    ];

    when(() => wineRepository.getAllWines()).thenAnswer((_) async => wines);

    final stats = await repository.getCellarStatistics();

    final red =
        stats.colorDistribution.firstWhere((c) => c.colorName == 'Rouge');
    final white =
        stats.colorDistribution.firstWhere((c) => c.colorName == 'Blanc');

    expect(red.percentage, 75.0);
    expect(white.percentage, 25.0);
  });

  test('trie les distributions par ordre décroissant', () async {
    final wines = [
      makeWine(
          name: 'A', color: WineColor.red, quantity: 1, region: 'Alsace'),
      makeWine(
          name: 'B', color: WineColor.red, quantity: 5, region: 'Bordeaux'),
      makeWine(
          name: 'C', color: WineColor.red, quantity: 3, region: 'Bourgogne'),
    ];

    when(() => wineRepository.getAllWines()).thenAnswer((_) async => wines);

    final stats = await repository.getCellarStatistics();

    expect(stats.regionDistribution[0].region, 'Bordeaux');
    expect(stats.regionDistribution[1].region, 'Bourgogne');
    expect(stats.regionDistribution[2].region, 'Alsace');
  });
}
