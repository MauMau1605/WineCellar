import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/statistics/presentation/helpers/statistics_screen_helper.dart';
import 'package:wine_cellar/features/statistics/presentation/providers/statistics_providers.dart';

void main() {
  group('StatisticsScreenHelper', () {
    test('expose la configuration UI de toutes les categories', () {
      expect(
        StatisticsScreenHelper.categories.map((config) => config.category),
        StatCategory.values,
      );

      final color = StatisticsScreenHelper.configFor(StatCategory.color);
      expect(color.sectionTitle, 'Répartition par couleur');
      expect(color.icon, Icons.palette);
      expect(color.supportsChartToggle, isTrue);

      final ratingsPrice =
          StatisticsScreenHelper.configFor(StatCategory.ratingsPrice);
      expect(ratingsPrice.sectionTitle, 'Notes & Prix');
      expect(ratingsPrice.icon, Icons.star);
      expect(ratingsPrice.supportsChartToggle, isFalse);
    });

    test('retourne les regles de toggle et les tooltips attendus', () {
      expect(
        StatisticsScreenHelper.shouldShowChartToggle(StatCategory.overview),
        isFalse,
      );
      expect(
        StatisticsScreenHelper.shouldShowChartToggle(StatCategory.producers),
        isTrue,
      );
      expect(
        StatisticsScreenHelper.chartToggleTooltip(true),
        'Voir en barres',
      );
      expect(
        StatisticsScreenHelper.chartToggleTooltip(false),
        'Voir en camembert',
      );
    });

    test('expose les textes d etat globaux attendus', () {
      expect(
        StatisticsScreenHelper.errorTitle,
        'Impossible de charger les statistiques',
      );
      expect(StatisticsScreenHelper.emptyTitle, 'Aucun vin dans la cave');
      expect(
        StatisticsScreenHelper.emptyDescription,
        contains('Ajoutez des vins'),
      );
    });
  });
}