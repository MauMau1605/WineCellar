import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/developer/domain/entities/reevaluation_options.dart';
import 'package:wine_cellar/features/developer/presentation/helpers/wine_reevaluation_helper.dart';
import 'package:wine_cellar/features/developer/presentation/providers/reevaluation_provider.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

const _wineA = WineEntity(
  id: 1,
  name: 'Chateau Demo',
  producer: 'Maison Rouge',
  appellation: 'Bordeaux',
  color: WineColor.red,
);

const _wineB = WineEntity(
  id: 2,
  name: 'Clos Blanc',
  producer: 'Domaine Clair',
  appellation: 'Chablis',
  color: WineColor.white,
);

void main() {
  group('WineReevaluationHelper options', () {
    test('expose les deux types de reevaluation attendus', () {
      expect(WineReevaluationHelper.options, hasLength(2));
      expect(
        WineReevaluationHelper.options.map((option) => option.type),
        {
          ReevaluationType.drinkingWindow,
          ReevaluationType.foodPairings,
        },
      );
    });
  });

  group('WineReevaluationHelper.applySearch', () {
    test('filtre sur le nom, le producteur et l appellation', () {
      expect(
        WineReevaluationHelper.applySearch([_wineA, _wineB], 'chablis'),
        [_wineB],
      );
      expect(
        WineReevaluationHelper.applySearch([_wineA, _wineB], 'maison'),
        [_wineA],
      );
      expect(
        WineReevaluationHelper.applySearch([_wineA, _wineB], 'clos'),
        [_wineB],
      );
    });

    test('ignore les espaces autour de la requete et retourne tout si vide', () {
      expect(
        WineReevaluationHelper.applySearch([_wineA, _wineB], '  demo  '),
        [_wineA],
      );
      expect(
        WineReevaluationHelper.applySearch([_wineA, _wineB], '   '),
        [_wineA, _wineB],
      );
    });
  });

  group('WineReevaluationHelper selection and launch', () {
    test('calcule correctement l etat visible de selection', () {
      final state = WineReevaluationHelper.buildVisibleSelectionState(
        [_wineA, _wineB],
        {1, 2, 99},
      );

      expect(state.visibleIds, {1, 2});
      expect(state.allSelected, isTrue);
      expect(state.selectedCount, 3);
    });

    test('bloque le lancement si selection vide, types vides ou etat non idle', () {
      expect(
        WineReevaluationHelper.canLaunch(
          {},
          {ReevaluationType.drinkingWindow},
          const ReevaluationIdle(),
        ),
        isFalse,
      );
      expect(
        WineReevaluationHelper.canLaunch(
          {1},
          {},
          const ReevaluationIdle(),
        ),
        isFalse,
      );
      expect(
        WineReevaluationHelper.canLaunch(
          {1},
          {ReevaluationType.drinkingWindow},
          const ReevaluationProcessing(
            currentBatch: 1,
            totalBatches: 2,
            processedWines: 0,
            totalWines: 10,
          ),
        ),
        isFalse,
      );
      expect(
        WineReevaluationHelper.canLaunch(
          {1},
          {ReevaluationType.drinkingWindow},
          const ReevaluationIdle(),
        ),
        isTrue,
      );
    });

    test('retourne le bon libelle d action', () {
      expect(
        WineReevaluationHelper.launchButtonLabel(0),
        'Sélectionnez des vins',
      );
      expect(
        WineReevaluationHelper.launchButtonLabel(3),
        'Lancer la réévaluation (3 vin(s))',
      );
    });
  });

  group('WineReevaluationHelper presentation details', () {
    test('retourne une couleur de pastille par type de vin', () {
      expect(
        WineReevaluationHelper.wineColorDotColor(WineColor.red),
        const Color(0xFF8B0000),
      );
      expect(
        WineReevaluationHelper.wineColorDotColor(WineColor.white),
        const Color(0xFFE8D87A),
      );
    });

    test('construit le texte et la progression d overlay', () {
      const state = ReevaluationProcessing(
        currentBatch: 2,
        totalBatches: 4,
        processedWines: 5,
        totalWines: 20,
      );

      expect(
        WineReevaluationHelper.processingStatusText(state),
        'Lot 2 / 4  — 5 / 20 vins traités',
      );
      expect(WineReevaluationHelper.processingProgressValue(state), 0.25);
      expect(
        WineReevaluationHelper.processingProgressValue(
          const ReevaluationProcessing(
            currentBatch: 1,
            totalBatches: 1,
            processedWines: 0,
            totalWines: 0,
          ),
        ),
        0,
      );
    });
  });
}