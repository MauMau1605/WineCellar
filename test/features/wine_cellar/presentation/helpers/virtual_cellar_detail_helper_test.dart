import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_move_state_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/helpers/virtual_cellar_detail_helper.dart';

const _wineA = WineEntity(
  id: 1,
  name: 'Alpha',
  vintage: 2020,
  color: WineColor.red,
  quantity: 3,
);

const _wineB = WineEntity(
  id: 2,
  name: 'Beta',
  color: WineColor.white,
  quantity: 1,
);

const _wineWithoutId = WineEntity(
  name: 'Gamma',
  color: WineColor.rose,
  quantity: 2,
);

final _placementA = BottlePlacementEntity(
  id: 11,
  wineId: 1,
  cellarId: 9,
  positionX: 0,
  positionY: 0,
  createdAt: DateTime(2024),
  wine: _wineA,
);

final _placementB = BottlePlacementEntity(
  id: 12,
  wineId: 2,
  cellarId: 9,
  positionX: 2,
  positionY: 3,
  createdAt: DateTime(2024),
  wine: _wineB,
);

void main() {
  group('VirtualCellarDetailHelper immersive theme', () {
    test('retourne null pour classic et le theme pour les themes immersifs', () {
      expect(
        VirtualCellarDetailHelper.immersiveThemeFor(VirtualCellarTheme.classic),
        isNull,
      );
      expect(
        VirtualCellarDetailHelper.immersiveThemeFor(
          VirtualCellarTheme.premiumCave,
        ),
        VirtualCellarTheme.premiumCave,
      );
      expect(
        VirtualCellarDetailHelper.immersiveThemeFor(
          VirtualCellarTheme.stoneCave,
        ),
        VirtualCellarTheme.stoneCave,
      );
      expect(
        VirtualCellarDetailHelper.backgroundKindFor(
          VirtualCellarTheme.classic,
        ),
        VirtualCellarBackgroundKind.none,
      );
      expect(
        VirtualCellarDetailHelper.backgroundKindFor(
          VirtualCellarTheme.garageIndustrial,
        ),
        VirtualCellarBackgroundKind.garage,
      );
    });

    test('construit les options de menu de theme avec le theme courant', () {
      final options = VirtualCellarDetailHelper.buildThemeMenuOptions(
        VirtualCellarTheme.stoneCave,
      );

      expect(
        options.map((option) => option.theme),
        VirtualCellarTheme.values,
      );
      expect(
        options.where((option) => option.selected).single.theme,
        VirtualCellarTheme.stoneCave,
      );
    });
  });

  group('VirtualCellarDetailHelper movement controls', () {
    test('retourne la bonne configuration selon l etat de deplacement', () {
      final idle = VirtualCellarDetailHelper.movementControlsFor(
        BottleMoveStateEntity.initial(1),
      );
      expect(idle.showSelectionToggle, isFalse);
      expect(idle.modeIcon, Icons.pan_tool_outlined);
      expect(idle.modeTooltip, 'Activer le mode déplacement');

      const selectionMode = BottleMoveStateEntity(
        cellarId: 1,
        isMovementMode: true,
        isDragModeEnabled: false,
        selectedPlacementIds: {10},
      );
      final selectionControls = VirtualCellarDetailHelper.movementControlsFor(
        selectionMode,
      );
      expect(selectionControls.showSelectionToggle, isTrue);
      expect(selectionControls.selectionToggleIcon, Icons.open_with);
      expect(
        selectionControls.selectionToggleTooltip,
        'Passer au mode déplacement',
      );
      expect(selectionControls.modeIcon, Icons.cancel);

      const dragMode = BottleMoveStateEntity(
        cellarId: 1,
        isMovementMode: true,
        isDragModeEnabled: true,
        selectedPlacementIds: {10},
      );
      final dragControls = VirtualCellarDetailHelper.movementControlsFor(
        dragMode,
      );
      expect(
        dragControls.selectionToggleIcon,
        Icons.playlist_add_check_circle_outlined,
      );
      expect(
        dragControls.selectionToggleTooltip,
        'Revenir au mode sélection',
      );
    });
  });

  group('VirtualCellarDetailHelper maturity filters', () {
    test('applique et met a jour les filtres de maturite', () {
      expect(
        VirtualCellarDetailHelper.matchesMaturityFilter(
          {},
          WineMaturity.ready,
        ),
        isTrue,
      );

      final selected = VirtualCellarDetailHelper.updateMaturityFilters(
        {},
        WineMaturity.ready,
        true,
      );
      expect(selected, {WineMaturity.ready});
      expect(
        VirtualCellarDetailHelper.matchesMaturityFilter(
          selected,
          WineMaturity.ready,
        ),
        isTrue,
      );
      expect(
        VirtualCellarDetailHelper.matchesMaturityFilter(
          selected,
          WineMaturity.pastPeak,
        ),
        isFalse,
      );

      final cleared = VirtualCellarDetailHelper.updateMaturityFilters(
        selected,
        WineMaturity.ready,
        false,
      );
      expect(cleared, isEmpty);
      expect(
        VirtualCellarDetailHelper.shouldShowMaturitySummary(cleared),
        isFalse,
      );
    });

    test('construit le resume de filtres attendu', () {
      expect(
        VirtualCellarDetailHelper.maturitySummaryText(3, 8),
        '3 / 8 bouteille(s) affichée(s)',
      );
      expect(
        VirtualCellarDetailHelper.maturityFilterTitle,
        'Filtrer par fenêtre de dégustation',
      );
      expect(
        VirtualCellarDetailHelper.resetFiltersLabel,
        'Réinitialiser',
      );
    });
  });

  group('VirtualCellarDetailHelper placement texts', () {
    test('construit les messages du parcours de placement', () {
      expect(
        VirtualCellarDetailHelper.preselectedAlreadyPlacedMessage('Alpha 2020'),
        'Toutes les bouteilles de Alpha 2020 sont déjà placées.',
      );
      expect(
        VirtualCellarDetailHelper.preselectedPlacementTitle('Alpha 2020'),
        'Placer Alpha 2020',
      );
      expect(
        VirtualCellarDetailHelper.preselectedPlacementContent(2),
        '2 bouteille(s) à placer.\nTapez sur les emplacements libres pour positionner chaque bouteille.',
      );
      expect(
        VirtualCellarDetailHelper.remainingManualPlacementMessage(2),
        '2 bouteille(s) restante(s). Choisissez les emplacements manuellement.',
      );
      expect(
        VirtualCellarDetailHelper.placementCompletedDialogContent('Alpha 2020'),
        'Toutes les bouteilles de Alpha 2020 ont été placées.\nSouhaitez-vous retourner aux détails du vin ?',
      );
      expect(
        VirtualCellarDetailHelper.continuePlacementDialogContent(1),
        '1 bouteille(s) restante(s).\nSouhaitez-vous placer la suivante ?',
      );
      expect(
        VirtualCellarDetailHelper.placementFinishedSnackBar,
        'Placement terminé.',
      );
      expect(
        VirtualCellarDetailHelper.noBottleAvailableSnackBar,
        'Aucune bouteille disponible à placer.',
      );
      expect(VirtualCellarDetailHelper.placeBottleLabel, 'Placer');
      expect(
        VirtualCellarDetailHelper.changeRepresentationTooltip,
        'Changer la representation',
      );
      expect(
        VirtualCellarDetailHelper.editCellarTooltip,
        'Modifier le cellier',
      );
      expect(
        VirtualCellarDetailHelper.emptyZoneSnackBar,
        'Zone vide: emplacement inutilisable.',
      );
      expect(
        VirtualCellarDetailHelper.occupiedSlotSnackBar,
        'Emplacement occupé.',
      );
      expect(
        VirtualCellarDetailHelper.missingAnchorSnackBar,
        'Bouteille d ancrage introuvable.',
      );
    });

    test('calcule les choix de bouteilles encore placables et le dialogue de quantité', () {
      final choices = VirtualCellarDetailHelper.buildAvailableWineChoices(
        const [_wineB, _wineA, _wineWithoutId],
        const {1: 1, 2: 1},
      );

      expect(choices, hasLength(1));
      expect(choices.first.wine, _wineA);
      expect(choices.first.unplacedCount, 2);
      expect(
        VirtualCellarDetailHelper.shouldAskHowManyBottles(1),
        isFalse,
      );
      expect(
        VirtualCellarDetailHelper.shouldAskHowManyBottles(2),
        isTrue,
      );
      expect(
        VirtualCellarDetailHelper.askBottleCountTitle(_wineA.displayName),
        'Combien placer pour ${_wineA.displayName} ?',
      );
    });

    test('construit les options du dialogue d insertion', () {
      expect(
        VirtualCellarDetailHelper.insertPositionDialogTitle('Rangées', 2),
        'Où ajouter 2 Rangées?',
      );
      expect(
        VirtualCellarDetailHelper.insertPositionDialogContent('Colonnes', 1),
        'Sélectionnez la position d\'insertion pour les 1 nouvelles Colonnes:',
      );

      final options = VirtualCellarDetailHelper.buildInsertPositionOptions(
        'Rangées',
        2,
      );
      expect(options.map((option) => option.position), [0, 1, 2, 2]);
      expect(options.first.title, 'Au début');
      expect(options[1].title, 'Entre rangées 1 et 2');
      expect(options.last.title, 'À la fin');
    });

    test('réindexe réellement les placements après insertion', () {
      final reindexed = VirtualCellarDetailHelper.buildReindexedPlacements(
        placements: [_placementA, _placementB],
        rowInsertPos: 1,
        colInsertPos: 2,
        addedRows: 2,
        addedCols: 1,
      );

      expect(reindexed, hasLength(1));
      expect(reindexed.single.placementId, 12);
      expect(reindexed.single.newPositionX, 3);
      expect(reindexed.single.newPositionY, 5);
    });

    test('n ajoute aucune réindexation si aucune insertion ne touche le placement', () {
      final reindexed = VirtualCellarDetailHelper.buildReindexedPlacements(
        placements: [_placementA],
        rowInsertPos: 2,
        colInsertPos: 1,
        addedRows: 1,
        addedCols: 1,
      );

      expect(reindexed, isEmpty);
    });
  });
}