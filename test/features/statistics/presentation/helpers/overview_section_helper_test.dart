import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/helpers/overview_section_helper.dart';

void main() {
  group('OverviewSectionHelper.buildCards', () {
    test('construit les KPI obligatoires et optionnels', () {
      const stats = OverviewStats(
        totalReferences: 12,
        totalBottles: 34,
        totalValue: 560,
        averagePrice: 16.4,
        averageRating: 4.2,
        oldestVintage: 1998,
        newestVintage: 2022,
      );

      final cards = OverviewSectionHelper.buildCards(
        stats,
        Colors.red,
        Colors.blue,
      );

      expect(cards, hasLength(6));
      expect(cards[0].label, 'Références');
      expect(cards[0].value, '12');
      expect(cards[0].color, Colors.red);
      expect(cards[1].label, 'Bouteilles');
      expect(cards[1].value, '34');
      expect(cards[1].color, Colors.blue);
      expect(cards[2].value, '560 €');
      expect(cards[3].value, '16.4 €');
      expect(cards[4].value, '4.2 / 5');
      expect(cards[5].value, '1998 – 2022');
    });

    test('omet les KPI optionnels sans donnees associees', () {
      const stats = OverviewStats(
        totalReferences: 3,
        totalBottles: 7,
      );

      final cards = OverviewSectionHelper.buildCards(
        stats,
        Colors.green,
        Colors.orange,
      );

      expect(cards, hasLength(2));
      expect(cards.map((card) => card.label), ['Références', 'Bouteilles']);
    });
  });

  group('OverviewSectionHelper.crossAxisCountForWidth', () {
    test('retourne 2 colonnes jusqu a 600 et 3 au dela', () {
      expect(OverviewSectionHelper.crossAxisCountForWidth(320), 2);
      expect(OverviewSectionHelper.crossAxisCountForWidth(600), 2);
      expect(OverviewSectionHelper.crossAxisCountForWidth(601), 3);
    });
  });
}