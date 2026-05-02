import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/helpers/wine_detail_screen_helper.dart';

const _wine = WineEntity(
  id: 7,
  name: 'Chablis',
  color: WineColor.white,
  vintage: 2020,
  quantity: 4,
  drinkFromYear: 2024,
  aiSuggestedDrinkFromYear: true,
  drinkUntilYear: 2028,
  aiSuggestedDrinkUntilYear: false,
  location: ' Cave nord ',
  rating: 4,
  purchasePrice: 18.5,
);

final _placement = BottlePlacementEntity(
  id: 10,
  wineId: 7,
  cellarId: 3,
  positionX: 2,
  positionY: 1,
  createdAt: DateTime(2024),
  wine: _wine,
);

const _cellar = VirtualCellarEntity(
  id: 3,
  name: 'Mur du fond',
  rows: 5,
  columns: 6,
  theme: VirtualCellarTheme.stoneCave,
);

void main() {
  group('WineDetailScreenHelper', () {
    test('normalise les affichages texte et entiers', () {
      expect(WineDetailScreenHelper.displayValue('  Test  '), 'Test');
      expect(WineDetailScreenHelper.displayValue(null), '');
      expect(WineDetailScreenHelper.displayInt(2020), '2020');
      expect(WineDetailScreenHelper.displayInt(null), '');
    });

    test('détecte correctement les informations de garde issues de l IA', () {
      expect(
        WineDetailScreenHelper.isAiSuggestedGuardValue(
          _wine,
          _wine.drinkFromYear,
        ),
        isTrue,
      );
      expect(
        WineDetailScreenHelper.isAiSuggestedGuardValue(
          _wine,
          _wine.drinkUntilYear,
        ),
        isFalse,
      );
      expect(WineDetailScreenHelper.isAiGuardInfoPresent(_wine), isTrue);
    });

    test('formate les libellés de quantité, prix et note', () {
      expect(WineDetailScreenHelper.quantityLabel(1), '1 bouteille');
      expect(WineDetailScreenHelper.quantityLabel(4), '4 bouteilles');
      expect(WineDetailScreenHelper.quantityFabLabel(4), '4 bouteilles');
      expect(WineDetailScreenHelper.purchasePriceLabel(18.5), '18.50 €');
      expect(WineDetailScreenHelper.purchasePriceLabel(null), '');
      expect(WineDetailScreenHelper.ratingLabel(4), '★★★★☆');
      expect(WineDetailScreenHelper.ratingLabel(null), '');
    });

    test('résume correctement l état des placements en cave', () {
      expect(
        WineDetailScreenHelper.placedBottlesLabel(2, 4),
        '2 / 4',
      );
      expect(
        WineDetailScreenHelper.placementsSummaryText(0),
        'Aucune bouteille placée en cellier.',
      );
      expect(
        WineDetailScreenHelper.placementsSummaryText(2),
        'Afficher les emplacements en cave',
      );
      expect(WineDetailScreenHelper.shouldShowPlacementsButton(0), isFalse);
      expect(WineDetailScreenHelper.shouldShowPlacementsButton(1), isTrue);
      expect(
        WineDetailScreenHelper.unplacedCount(
          totalQuantity: 4,
          placedCount: 1,
        ),
        3,
      );
      expect(
        WineDetailScreenHelper.shouldShowPlaceInCellarButton(
          totalQuantity: 4,
          placedCount: 4,
        ),
        isFalse,
      );
      expect(
        WineDetailScreenHelper.placeInCellarButtonLabel(
          totalQuantity: 4,
          placedCount: 0,
        ),
        'Placer en cave',
      );
      expect(
        WineDetailScreenHelper.placeInCellarButtonLabel(
          totalQuantity: 4,
          placedCount: 1,
        ),
        'Placer les 3 bouteille(s) non placée(s)',
      );
    });

    test('formate les textes liés aux celliers et positions', () {
      expect(
        WineDetailScreenHelper.cellarChoiceSubtitle(_cellar),
        '5 × 6 — 30 emplacements',
      );
      expect(
        WineDetailScreenHelper.placementsDialogTitle(_wine.displayName),
        'Placements de Chablis 2020',
      );
      expect(
        WineDetailScreenHelper.cellarPlacementHeader('Mur du fond', 2),
        'Mur du fond - 2 bouteille(s)',
      );
      expect(
        WineDetailScreenHelper.placementPositionText(_placement),
        'Rangée 2, Colonne 3',
      );
      expect(
        WineDetailScreenHelper.removedBottleCellarName(_placement, 'Mur du fond'),
        'Mur du fond',
      );
      expect(
        WineDetailScreenHelper.removedBottleCellarName(_placement, null),
        'Cellier 3',
      );
    });

    test('détermine quand demander quelle bouteille placée a été retirée', () {
      expect(
        WineDetailScreenHelper.shouldAskWhichPlacedBottleWasRemoved(
          currentQuantity: 3,
          newQuantity: 2,
          placedCount: 3,
        ),
        isTrue,
      );
      expect(
        WineDetailScreenHelper.shouldAskWhichPlacedBottleWasRemoved(
          currentQuantity: 4,
          newQuantity: 3,
          placedCount: 2,
        ),
        isFalse,
      );
      expect(
        WineDetailScreenHelper.shouldAskWhichPlacedBottleWasRemoved(
          currentQuantity: 3,
          newQuantity: -1,
          placedCount: 3,
        ),
        isFalse,
      );
    });

    test('centralise la logique du passage à quantité zéro', () {
      expect(WineDetailScreenHelper.shouldPromptForZeroQuantity(0), isTrue);
      expect(WineDetailScreenHelper.shouldPromptForZeroQuantity(2), isFalse);
      expect(
        WineDetailScreenHelper.zeroQuantityDialogContent(_wine.displayName),
        'La quantité de "Chablis 2020" va passer à 0.\n'
        'Que souhaitez-vous faire ?',
      );
      expect(
        WineDetailScreenHelper.zeroQuantityActionFromChoice('delete'),
        ZeroQuantityAction.delete,
      );
      expect(
        WineDetailScreenHelper.zeroQuantityActionFromChoice('zero'),
        ZeroQuantityAction.keep,
      );
      expect(WineDetailScreenHelper.shouldAbortQuantityUpdate(null), isTrue);
      expect(
        WineDetailScreenHelper.shouldAbortQuantityUpdate('cancel'),
        isTrue,
      );
      expect(
        WineDetailScreenHelper.shouldAbortQuantityUpdate('delete'),
        isFalse,
      );
      expect(
        WineDetailScreenHelper.shouldNavigateAfterZeroQuantityChoice('delete'),
        isTrue,
      );
      expect(
        WineDetailScreenHelper.shouldNavigateAfterZeroQuantityChoice('zero'),
        isFalse,
      );
    });

    test('centralise les textes de suppression du vin', () {
      expect(
        WineDetailScreenHelper.deleteWineDialogContent(_wine.displayName),
        'Voulez-vous vraiment supprimer "Chablis 2020" ?',
      );
      expect(
        WineDetailScreenHelper.deleteWineSuccessMessage,
        'Vin supprimé',
      );
    });
  });
}