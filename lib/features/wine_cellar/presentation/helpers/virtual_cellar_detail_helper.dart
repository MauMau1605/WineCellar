import 'package:flutter/material.dart';

import 'package:wine_cellar/core/cellar_theme_data.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_move_state_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

class AvailableWinePlacementChoice {
  final WineEntity wine;
  final int unplacedCount;

  const AvailableWinePlacementChoice({
    required this.wine,
    required this.unplacedCount,
  });
}

enum VirtualCellarBackgroundKind { none, premium, stone, garage }

class VirtualCellarThemeMenuOption {
  final VirtualCellarTheme theme;
  final String label;
  final bool selected;

  const VirtualCellarThemeMenuOption({
    required this.theme,
    required this.label,
    required this.selected,
  });
}

class MovementControlsConfig {
  final bool showSelectionToggle;
  final IconData? selectionToggleIcon;
  final String? selectionToggleTooltip;
  final IconData modeIcon;
  final String modeTooltip;

  const MovementControlsConfig({
    required this.showSelectionToggle,
    required this.selectionToggleIcon,
    required this.selectionToggleTooltip,
    required this.modeIcon,
    required this.modeTooltip,
  });
}

class VirtualCellarDetailHelper {
  VirtualCellarDetailHelper._();

  static const String maturityFilterTitle =
      'Filtrer par fenêtre de dégustation';
  static const String resetFiltersLabel = 'Réinitialiser';
  static const String preselectedCancelLabel = 'Annuler';
  static const String preselectedStartLabel = 'Commencer';
  static const String placementCompleteTitle = 'Placement terminé !';
  static const String stayLabel = 'Rester';
  static const String returnToDetailsLabel = 'Retourner aux détails';
  static const String bottlePlacedTitle = 'Bouteille placée !';
  static const String stopPlacementLabel = 'Arrêter';
  static const String placeNextBottleLabel = 'Placer la suivante';
  static const String placementFinishedSnackBar = 'Placement terminé.';
  static const String noBottleAvailableSnackBar =
      'Aucune bouteille disponible à placer.';
  static const String placeBottleLabel = 'Placer';
  static const String changeRepresentationTooltip = 'Changer la representation';
  static const String editCellarTooltip = 'Modifier le cellier';
  static const String emptyZoneSnackBar =
      'Zone vide: emplacement inutilisable.';
  static const String occupiedSlotSnackBar = 'Emplacement occupé.';
  static const String missingAnchorSnackBar =
      'Bouteille d ancrage introuvable.';

  static VirtualCellarTheme? immersiveThemeFor(VirtualCellarTheme theme) {
    return CellarThemeData.overridesAppTheme(theme) ? theme : null;
  }

  static VirtualCellarBackgroundKind backgroundKindFor(
    VirtualCellarTheme theme,
  ) {
    return switch (theme) {
      VirtualCellarTheme.classic => VirtualCellarBackgroundKind.none,
      VirtualCellarTheme.premiumCave => VirtualCellarBackgroundKind.premium,
      VirtualCellarTheme.stoneCave => VirtualCellarBackgroundKind.stone,
      VirtualCellarTheme.garageIndustrial =>
          VirtualCellarBackgroundKind.garage,
    };
  }

  static List<VirtualCellarThemeMenuOption> buildThemeMenuOptions(
    VirtualCellarTheme currentTheme,
  ) {
    return VirtualCellarTheme.values
        .map(
          (theme) => VirtualCellarThemeMenuOption(
            theme: theme,
            label: theme.label,
            selected: theme == currentTheme,
          ),
        )
        .toList(growable: false);
  }

  static MovementControlsConfig movementControlsFor(
    BottleMoveStateEntity state,
  ) {
    final showSelectionToggle = state.isMovementMode && state.hasSelection;
    return MovementControlsConfig(
      showSelectionToggle: showSelectionToggle,
      selectionToggleIcon: showSelectionToggle
          ? (state.isDragModeEnabled
              ? Icons.playlist_add_check_circle_outlined
              : Icons.open_with)
          : null,
      selectionToggleTooltip: showSelectionToggle
          ? (state.isDragModeEnabled
              ? 'Revenir au mode sélection'
              : 'Passer au mode déplacement')
          : null,
      modeIcon: state.isMovementMode ? Icons.cancel : Icons.pan_tool_outlined,
      modeTooltip: state.isMovementMode
          ? 'Annuler le mode déplacement'
          : 'Activer le mode déplacement',
    );
  }

  static bool matchesMaturityFilter(
    Set<WineMaturity> filters,
    WineMaturity maturity,
  ) {
    if (filters.isEmpty) return true;
    return filters.contains(maturity);
  }

  static Set<WineMaturity> updateMaturityFilters(
    Set<WineMaturity> current,
    WineMaturity maturity,
    bool selected,
  ) {
    final updated = Set<WineMaturity>.from(current);
    if (selected) {
      updated.add(maturity);
    } else {
      updated.remove(maturity);
    }
    return updated;
  }

  static bool shouldShowMaturitySummary(Set<WineMaturity> filters) {
    return filters.isNotEmpty;
  }

  static String maturitySummaryText(int visibleCount, int totalCount) {
    return '$visibleCount / $totalCount bouteille(s) affichée(s)';
  }

  static String preselectedAlreadyPlacedMessage(String wineDisplayName) {
    return 'Toutes les bouteilles de $wineDisplayName sont déjà placées.';
  }

  static String preselectedPlacementTitle(String wineDisplayName) {
    return 'Placer $wineDisplayName';
  }

  static String preselectedPlacementContent(int unplacedCount) {
    return '$unplacedCount bouteille(s) à placer.\n'
        'Tapez sur les emplacements libres pour positionner chaque bouteille.';
  }

  static String remainingManualPlacementMessage(int remaining) {
    return '$remaining bouteille(s) restante(s). '
        'Choisissez les emplacements manuellement.';
  }

  static String placementCompletedDialogContent(String wineDisplayName) {
    return 'Toutes les bouteilles de $wineDisplayName ont été placées.\n'
        'Souhaitez-vous retourner aux détails du vin ?';
  }

  static String continuePlacementDialogContent(int left) {
    return '$left bouteille(s) restante(s).\n'
        'Souhaitez-vous placer la suivante ?';
  }

  static List<AvailableWinePlacementChoice> buildAvailableWineChoices(
    List<WineEntity> wines,
    Map<int, int> placedCountsByWineId,
  ) {
    final availableChoices = wines
        .where((wine) => wine.id != null)
        .map((wine) {
          final unplacedCount =
              wine.quantity - (placedCountsByWineId[wine.id!] ?? 0);
          return AvailableWinePlacementChoice(
            wine: wine,
            unplacedCount: unplacedCount,
          );
        })
        .where((choice) => choice.unplacedCount > 0)
        .toList(growable: false)
      ..sort((a, b) => a.wine.displayName.compareTo(b.wine.displayName));

    return availableChoices;
  }

  static bool shouldAskHowManyBottles(int maxCount) {
    return maxCount > 1;
  }

  static String askBottleCountTitle(String wineDisplayName) {
    return 'Combien placer pour $wineDisplayName ?';
  }
}