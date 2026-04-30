import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

class VirtualCellarListHelper {
  VirtualCellarListHelper._();

  static const String screenTitle = 'Mes Celliers';
  static const String newCellarLabel = 'Nouveau cellier';
  static const String createDialogTitle = 'Nouveau cellier';
  static const String editDialogTitle = 'Modifier le cellier';
  static const String createConfirmLabel = 'Créer';
  static const String saveConfirmLabel = 'Enregistrer';
  static const String emptyTitle = 'Aucun cellier créé';
  static const String emptyDescription =
      'Créez votre premier cellier virtuel pour placer\n'
      'vos bouteilles et les retrouver facilement.';
  static const String createCellarActionLabel = 'Créer un cellier';
  static const String modeLabel = 'Mode de creation';
  static const String renameLocationDialogTitle =
      'Mettre à jour la localisation ?';
  static const String keepOldLocationLabel = 'Non, garder l\'ancienne';
  static const String updateLocationLabel = 'Oui, mettre à jour';
  static const String deleteDialogTitle = 'Supprimer le cellier ?';
  static const String deleteCancelLabel = 'Annuler';
  static const String deleteConfirmLabel = 'Supprimer';
  static const String cellarsNotFoundErrorPrefix = 'Erreur : ';

  static String generateDefaultCellarName(List<String> existingNames) {
    final lowerNames = existingNames.map((name) => name.toLowerCase()).toSet();
    for (var index = 1;; index++) {
      final candidate = 'Cave $index';
      if (!lowerNames.contains(candidate.toLowerCase())) {
        return candidate;
      }
    }
  }

  static String cellarNameHint(List<String> existingNames) {
    if (existingNames.isEmpty) {
      return 'Ex : Cave principale';
    }
    return 'Par défaut : ${generateDefaultCellarName(existingNames)}';
  }

  static String normalizeCellarName(
    String rawName,
    List<String> existingNames,
  ) {
    final trimmed = rawName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return generateDefaultCellarName(existingNames);
  }

  static int clampSimplifiedRows(int rows) => rows.clamp(1, 12);

  static int clampSimplifiedColumns(int columns) => columns.clamp(1, 16);

  static String renameLocationDialogContent(
    int affectedBottles,
    String oldName,
    String newName,
  ) {
    return '$affectedBottles bouteille(s) ont la localisation '
        '"$oldName".\n\n'
        'Souhaitez-vous mettre à jour leur localisation en "$newName" ?';
  }

  static String renameLocationSuccessMessage(int affectedBottles) {
    return '$affectedBottles bouteille(s) mise(s) à jour.';
  }

  static String deleteDialogContent(String cellarName) {
    return 'Le cellier "$cellarName" sera supprimé. '
        'Les bouteilles qu\'il contient seront déplacées (non supprimées).';
  }

  static String cellarCardSubtitle(VirtualCellarEntity cellar) {
    return '${cellar.rows} rangée${cellar.rows > 1 ? 's' : ''} × '
        '${cellar.columns} colonne${cellar.columns > 1 ? 's' : ''} '
        '(${cellar.totalSlots} emplacements) • ${cellar.theme.label}';
  }

  static bool shouldAskToRenameLocations(int affectedBottles) {
    return affectedBottles > 0;
  }

  static bool shouldOpenExpertEditor(bool advancedMode) {
    return advancedMode;
  }
}