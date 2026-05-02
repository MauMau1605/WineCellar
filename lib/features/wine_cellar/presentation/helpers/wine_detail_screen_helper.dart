import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';

class WineDetailScreenHelper {
  WineDetailScreenHelper._();

  static const String notFoundTitle = 'Vin non trouvé';
  static const String notFoundMessage = 'Ce vin n\'existe pas.';
  static const String aiGuardInfoText = '🤖 = information proposée par l\'IA';
  static const String noFoodPairingText = 'Aucune proposition disponible.';
  static const String aiFoodPairingText = '🤖 = accord proposé par l\'IA';
  static const String noPlacedBottleText = 'Aucune bouteille placée en cellier.';
  static const String showPlacementsText = 'Afficher les emplacements en cave';
  static const String placeInCellarLabel = 'Placer en cave';
  static const String removePlacedBottleDialogTitle =
      'Quelle bouteille a été retirée ?';
  static const String zeroQuantityDialogTitle = 'Dernière bouteille !';
  static const String zeroQuantityCancelLabel = 'Annuler';
  static const String zeroQuantityKeepLabel = 'Garder à 0';
  static const String zeroQuantityDeleteLabel = 'Supprimer';
  static const String deleteWineDialogTitle = 'Supprimer ce vin ?';
  static const String deleteWineSuccessMessage = 'Vin supprimé';

  static String displayValue(String? value) {
    if (value == null) return '';
    return value.trim();
  }

  static String displayInt(int? value) {
    return value?.toString() ?? '';
  }

  static bool isAiSuggestedGuardValue(WineEntity wine, int? value) {
    if (value == null) return false;
    return (value == wine.drinkFromYear && wine.aiSuggestedDrinkFromYear) ||
        (value == wine.drinkUntilYear && wine.aiSuggestedDrinkUntilYear);
  }

  static bool isAiGuardInfoPresent(WineEntity wine) {
    return (wine.drinkFromYear != null && wine.aiSuggestedDrinkFromYear) ||
        (wine.drinkUntilYear != null && wine.aiSuggestedDrinkUntilYear);
  }

  static String quantityLabel(int quantity) {
    return '$quantity bouteille${quantity > 1 ? 's' : ''}';
  }

  static String quantityFabLabel(int quantity) {
    return quantityLabel(quantity);
  }

  static String purchasePriceLabel(double? purchasePrice) {
    if (purchasePrice == null) return '';
    return '${purchasePrice.toStringAsFixed(2)} €';
  }

  static String ratingLabel(int? rating) {
    if (rating == null) return '';
    return '${'★' * rating}${'☆' * (5 - rating)}';
  }

  static String placedBottlesLabel(int placedCount, int totalQuantity) {
    return '$placedCount / $totalQuantity';
  }

  static String placementsSummaryText(int placedCount) {
    return placedCount == 0 ? noPlacedBottleText : showPlacementsText;
  }

  static bool shouldShowPlacementsButton(int placedCount) {
    return placedCount > 0;
  }

  static int unplacedCount({
    required int totalQuantity,
    required int placedCount,
  }) {
    return totalQuantity - placedCount;
  }

  static bool shouldShowPlaceInCellarButton({
    required int totalQuantity,
    required int placedCount,
  }) {
    return unplacedCount(
          totalQuantity: totalQuantity,
          placedCount: placedCount,
        ) > 0;
  }

  static String placeInCellarButtonLabel({
    required int totalQuantity,
    required int placedCount,
  }) {
    final remaining = unplacedCount(
      totalQuantity: totalQuantity,
      placedCount: placedCount,
    );
    if (remaining == totalQuantity) {
      return placeInCellarLabel;
    }
    return 'Placer les $remaining bouteille(s) non placée(s)';
  }

  static String cellarChoiceSubtitle(VirtualCellarEntity cellar) {
    return '${cellar.rows} × ${cellar.columns} — '
        '${cellar.totalSlots} emplacements';
  }

  static String placementsDialogTitle(String wineDisplayName) {
    return 'Placements de $wineDisplayName';
  }

  static String cellarPlacementHeader(String cellarName, int placedCount) {
    return '$cellarName - $placedCount bouteille(s)';
  }

  static String placementPositionText(BottlePlacementEntity placement) {
    return 'Rangée ${placement.positionY + 1}, '
        'Colonne ${placement.positionX + 1}';
  }

  static String removedBottleCellarName(
    BottlePlacementEntity placement,
    String? cellarName,
  ) {
    return cellarName ?? 'Cellier ${placement.cellarId}';
  }

  static bool shouldAskWhichPlacedBottleWasRemoved({
    required int currentQuantity,
    required int newQuantity,
    required int placedCount,
  }) {
    return newQuantity >= 0 &&
        placedCount > newQuantity &&
        placedCount > 0 &&
        placedCount == currentQuantity;
  }

  static bool shouldPromptForZeroQuantity(int newQuantity) {
    return newQuantity <= 0;
  }

  static String zeroQuantityDialogContent(String wineDisplayName) {
    return 'La quantité de "$wineDisplayName" va passer à 0.\n'
        'Que souhaitez-vous faire ?';
  }

  static ZeroQuantityAction zeroQuantityActionFromChoice(String action) {
    return action == 'delete'
        ? ZeroQuantityAction.delete
        : ZeroQuantityAction.keep;
  }

  static bool shouldAbortQuantityUpdate(String? action) {
    return action == null || action == 'cancel';
  }

  static bool shouldNavigateAfterZeroQuantityChoice(String action) {
    return action == 'delete';
  }

  static String deleteWineDialogContent(String wineDisplayName) {
    return 'Voulez-vous vraiment supprimer "$wineDisplayName" ?';
  }
}