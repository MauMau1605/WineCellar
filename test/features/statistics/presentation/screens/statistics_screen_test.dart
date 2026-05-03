import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:wine_cellar/features/statistics/presentation/screens/statistics_screen.dart';

void main() {
  group('StatisticsScreen', () {
    testWidgets('affiche un etat vide quand la cave est vide', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cellarStatisticsProvider.overrideWith((ref) async {
              return CellarStatistics.empty;
            }),
          ],
          child: const MaterialApp(home: StatisticsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucun vin dans la cave'), findsOneWidget);
      expect(
        find.text('Ajoutez des vins pour voir les statistiques de votre cave.'),
        findsOneWidget,
      );
    });

    testWidgets('affiche un etat d erreur quand le chargement echoue', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cellarStatisticsProvider.overrideWith((ref) async {
              throw Exception('boom');
            }),
          ],
          child: const MaterialApp(home: StatisticsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Impossible de charger les statistiques'),
        findsOneWidget,
      );
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('change de categorie et bascule le mode de graphique', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cellarStatisticsProvider.overrideWith((ref) async {
              return _sampleStatistics;
            }),
          ],
          child: const MaterialApp(home: StatisticsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vue d\'ensemble'), findsWidgets);

      await tester.tap(find.text('Couleur'));
      await tester.pumpAndSettle();

      expect(find.text('Répartition par couleur'), findsOneWidget);
      expect(find.byTooltip('Voir en barres'), findsOneWidget);

      await tester.tap(find.byTooltip('Voir en barres'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Voir en camembert'), findsOneWidget);
    });
  });
}

const _sampleStatistics = CellarStatistics(
  overview: OverviewStats(
    totalReferences: 2,
    totalBottles: 6,
    totalValue: 120,
    averagePrice: 20,
    averageRating: 4,
    oldestVintage: 2018,
    newestVintage: 2021,
  ),
  colorDistribution: [
    ColorStat(colorName: 'Rouge', emoji: '🍷', bottles: 4, percentage: 66.7),
    ColorStat(colorName: 'Blanc', emoji: '🥂', bottles: 2, percentage: 33.3),
  ],
  maturityDistribution: [
    MaturityStat(maturityName: 'Pret', emoji: '⏳', bottles: 6, percentage: 100),
  ],
  regionDistribution: [
    RegionStat(region: 'Bordeaux', bottles: 6, percentage: 100),
  ],
  appellationDistribution: [
    AppellationStat(appellation: 'Medoc', bottles: 6, percentage: 100),
  ],
  countryDistribution: [
    CountryStat(country: 'France', bottles: 6, percentage: 100),
  ],
  vintageDistribution: [
    VintageStat(vintage: 2018, bottles: 3),
    VintageStat(vintage: 2021, bottles: 3),
  ],
  grapeDistribution: [
    GrapeVarietyStat(grape: 'Merlot', bottles: 6, percentage: 100),
  ],
  ratingDistribution: [RatingStat(rating: 4, bottles: 6)],
  priceStats: PriceStats(
    minPrice: 15,
    maxPrice: 25,
    averagePrice: 20,
    medianPrice: 20,
    totalValue: 120,
    priceRanges: [
      PriceRangeStat(label: '10-20', minPrice: 10, maxPrice: 20, bottles: 3),
      PriceRangeStat(label: '20-30', minPrice: 20, maxPrice: 30, bottles: 3),
    ],
  ),
  producerDistribution: [
    ProducerStat(producer: 'Chateau Test', bottles: 6, percentage: 100),
  ],
);
