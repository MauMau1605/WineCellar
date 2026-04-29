import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_filter.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_sort.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/helpers/wine_list_screen_helper.dart';

const _wineReady = WineEntity(
  id: 1,
  name: 'Alpha',
  color: WineColor.red,
  location: 'Cave A',
  drinkFromYear: 2010,
  drinkUntilYear: 2030,
  quantity: 2,
);

const _winePastPeak = WineEntity(
  id: 2,
  name: 'Beta',
  color: WineColor.white,
  location: 'Cave B',
  drinkFromYear: 2000,
  drinkUntilYear: 2010,
  quantity: 1,
);

void main() {
  group('WineListScreenHelper.computeIsMasterDetail', () {
    test('retourne la bonne valeur selon le layout et la largeur', () {
      expect(
        WineListScreenHelper.computeIsMasterDetail(WineListLayout.list, 1200),
        isFalse,
      );
      expect(
        WineListScreenHelper.computeIsMasterDetail(
          WineListLayout.masterDetail,
          400,
        ),
        isTrue,
      );
      expect(
        WineListScreenHelper.computeIsMasterDetail(WineListLayout.auto, 899),
        isFalse,
      );
      expect(
        WineListScreenHelper.computeIsMasterDetail(WineListLayout.auto, 900),
        isTrue,
      );
    });
  });

  group('WineListScreenHelper.updateSearchFilter', () {
    test('vide la recherche ou remplace le filtre de texte', () {
      const base = WineFilter(
        color: WineColor.red,
        maturity: WineMaturity.ready,
      );

      final updated = WineListScreenHelper.updateSearchFilter(base, 'bdx');
      expect(updated.searchQuery, 'bdx');
      expect(updated.color, isNull);
      expect(updated.maturity, isNull);

      final cleared = WineListScreenHelper.updateSearchFilter(updated, '');
      expect(cleared.searchQuery, isNull);
    });
  });

  group('WineListScreenHelper.applyClientSideFiltersAndSort', () {
    test('applique les filtres de maturite, localisation et tri', () {
      final filtered = WineListScreenHelper.applyClientSideFiltersAndSort(
        const [_wineReady, _winePastPeak],
        const WineFilter(
          maturity: WineMaturity.pastPeak,
          locations: {'Cave B'},
        ),
        const WineSort(field: WineSortField.name, ascending: false),
      );

      expect(filtered, [_winePastPeak]);
    });

    test('retourne les vins tries quand il n y a pas de filtre client', () {
      final filtered = WineListScreenHelper.applyClientSideFiltersAndSort(
        const [_wineReady, _winePastPeak],
        const WineFilter(),
        const WineSort(field: WineSortField.name, ascending: false),
      );

      expect(filtered.map((wine) => wine.name), ['Beta', 'Alpha']);
    });
  });

  group('WineListScreenHelper labels and empty state', () {
    test('construit les labels de chips et les textes statiques', () {
      expect(
        WineListScreenHelper.colorFilterLabel(WineColor.red),
        '${WineColor.red.emoji} ${WineColor.red.label}',
      );
      expect(
        WineListScreenHelper.maturityFilterLabel(WineMaturity.ready),
        '${WineMaturity.ready.emoji} ${WineMaturity.ready.label}',
      );
      expect(WineListScreenHelper.searchHint, 'Rechercher...');
      expect(WineListScreenHelper.emptyTitle, 'Aucun vin dans votre cave');
      expect(
        WineListScreenHelper.emptySubtitle,
        contains('assistant IA'),
      );
    });

    test('affiche le clear des localisations seulement si necessaire', () {
      expect(
        WineListScreenHelper.shouldShowLocationClearAction({}),
        isFalse,
      );
      expect(
        WineListScreenHelper.shouldShowLocationClearAction({'Cave A'}),
        isTrue,
      );
    });
  });
}