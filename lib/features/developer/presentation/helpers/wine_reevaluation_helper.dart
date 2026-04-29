import 'package:flutter/material.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/developer/domain/entities/reevaluation_options.dart';
import 'package:wine_cellar/features/developer/presentation/providers/reevaluation_provider.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

class ReevaluationTypeOptionUi {
  final ReevaluationType type;
  final String title;
  final String subtitle;

  const ReevaluationTypeOptionUi({
    required this.type,
    required this.title,
    required this.subtitle,
  });
}

class VisibleWineSelectionState {
  final Set<int> visibleIds;
  final bool allSelected;
  final int selectedCount;

  const VisibleWineSelectionState({
    required this.visibleIds,
    required this.allSelected,
    required this.selectedCount,
  });
}

class WineReevaluationHelper {
  WineReevaluationHelper._();

  static const List<ReevaluationTypeOptionUi> options = [
    ReevaluationTypeOptionUi(
      type: ReevaluationType.drinkingWindow,
      title: 'Fenêtres de dégustation',
      subtitle: 'Mettre à jour drinkFromYear / drinkUntilYear',
    ),
    ReevaluationTypeOptionUi(
      type: ReevaluationType.foodPairings,
      title: 'Accords mets et vins',
      subtitle: 'Mettre à jour les catégories alimentaires',
    ),
  ];

  static List<WineEntity> applySearch(List<WineEntity> wines, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return wines;

    return wines.where((wine) {
      return wine.name.toLowerCase().contains(normalizedQuery) ||
          (wine.producer?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (wine.appellation?.toLowerCase().contains(normalizedQuery) ?? false);
    }).toList(growable: false);
  }

  static VisibleWineSelectionState buildVisibleSelectionState(
    List<WineEntity> wines,
    Set<int> selectedWineIds,
  ) {
    final visibleIds = wines
        .where((wine) => wine.id != null)
        .map((wine) => wine.id!)
        .toSet();

    return VisibleWineSelectionState(
      visibleIds: visibleIds,
      allSelected: visibleIds.isNotEmpty &&
          visibleIds.every(selectedWineIds.contains),
      selectedCount: selectedWineIds.length,
    );
  }

  static bool canLaunch(
    Set<int> selectedWineIds,
    Set<ReevaluationType> selectedTypes,
    ReevaluationState state,
  ) {
    return selectedWineIds.isNotEmpty &&
        selectedTypes.isNotEmpty &&
        state is ReevaluationIdle;
  }

  static String launchButtonLabel(int selectedCount) {
    if (selectedCount == 0) {
      return 'Sélectionnez des vins';
    }
    return 'Lancer la réévaluation ($selectedCount vin(s))';
  }

  static Color wineColorDotColor(WineColor color) {
    return switch (color) {
      WineColor.red => const Color(0xFF8B0000),
      WineColor.white => const Color(0xFFE8D87A),
      WineColor.rose => const Color(0xFFFFB6C1),
      WineColor.sparkling => const Color(0xFFDAA520),
      WineColor.sweet => const Color(0xFFD4A017),
    };
  }

  static String processingStatusText(ReevaluationProcessing state) {
    return 'Lot ${state.currentBatch} / ${state.totalBatches}  '
        '— ${state.processedWines} / ${state.totalWines} vins traités';
  }

  static double processingProgressValue(ReevaluationProcessing state) {
    if (state.totalWines <= 0) return 0;
    return state.processedWines / state.totalWines;
  }
}