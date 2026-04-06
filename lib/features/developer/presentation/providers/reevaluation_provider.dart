import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/developer/domain/entities/reevaluation_options.dart';
import 'package:wine_cellar/features/developer/domain/entities/wine_reevaluation_change.dart';
import 'package:wine_cellar/features/developer/domain/usecases/reevaluate_batch_usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

// ============================================================
//  State
// ============================================================

sealed class ReevaluationState {
  const ReevaluationState();
}

class ReevaluationIdle extends ReevaluationState {
  const ReevaluationIdle();
}

class ReevaluationProcessing extends ReevaluationState {
  final int currentBatch;
  final int totalBatches;
  final int processedWines;
  final int totalWines;

  const ReevaluationProcessing({
    required this.currentBatch,
    required this.totalBatches,
    required this.processedWines,
    required this.totalWines,
  });
}

class ReevaluationPreview extends ReevaluationState {
  final List<WineReevaluationChange> changes;

  /// IDs of wines whose changes are selected for applying.
  final Set<int> selectedWineIds;

  const ReevaluationPreview({
    required this.changes,
    required this.selectedWineIds,
  });

  int get changesCount => changes.where((c) => c.hasAnyChange).length;
  int get unchangedCount => changes.where((c) => c.unchanged).length;
  int get errorCount => changes.where((c) => c.hasError).length;
  int get selectedCount => selectedWineIds.length;

  ReevaluationPreview copyWith({Set<int>? selectedWineIds}) =>
      ReevaluationPreview(
        changes: changes,
        selectedWineIds: selectedWineIds ?? this.selectedWineIds,
      );
}

class ReevaluationApplying extends ReevaluationState {
  const ReevaluationApplying();
}

class ReevaluationApplied extends ReevaluationState {
  final int appliedCount;
  final int unchangedCount;
  final int errorCount;

  const ReevaluationApplied({
    required this.appliedCount,
    required this.unchangedCount,
    required this.errorCount,
  });
}

class ReevaluationError extends ReevaluationState {
  final String message;
  const ReevaluationError(this.message);
}

// ============================================================
//  Notifier
// ============================================================

class ReevaluationNotifier extends StateNotifier<ReevaluationState> {
  final ReevaluateBatchUseCase _useCase;
  final Ref _ref;

  bool _cancelled = false;

  ReevaluationNotifier(this._useCase, this._ref)
      : super(const ReevaluationIdle());

  /// Start the re-evaluation workflow.
  ///
  /// Splits [wines] into batches of 10, calls the use case for each batch,
  /// and reports progress. When done, transitions to [ReevaluationPreview].
  Future<void> startReevaluation(
    List<WineEntity> wines,
    ReevaluationOptions options,
  ) async {
    if (wines.isEmpty) {
      state = const ReevaluationError('Aucun vin sélectionné.');
      return;
    }
    if (!options.isValid) {
      state = const ReevaluationError(
        'Sélectionnez au moins un type de réévaluation.',
      );
      return;
    }

    final aiService = _ref.read(aiServiceProvider);
    if (aiService == null) {
      state = const ReevaluationError(
        'Aucun service IA configuré. Configurez une clé API dans les paramètres.',
      );
      return;
    }

    final webSearchService = _ref.read(geminiWebSearchServiceProvider);
    final foodCategoryRepo = _ref.read(foodCategoryRepositoryProvider);
    final foodCategories = await foodCategoryRepo.getAllCategories();

    _cancelled = false;

    const batchSize = 10;
    final batches = <List<WineEntity>>[];
    for (var i = 0; i < wines.length; i += batchSize) {
      batches.add(
        wines.sublist(
          i,
          (i + batchSize).clamp(0, wines.length),
        ),
      );
    }

    final allChanges = <WineReevaluationChange>[];

    for (var batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      if (_cancelled) break;

      final batch = batches[batchIndex];
      state = ReevaluationProcessing(
        currentBatch: batchIndex + 1,
        totalBatches: batches.length,
        processedWines: allChanges.length,
        totalWines: wines.length,
      );

      final result = await _useCase(
        ReevaluateBatchParams(
          wines: batch,
          options: options,
          aiService: aiService,
          webSearchService: webSearchService,
          foodCategories: foodCategories,
        ),
      );

      result.fold(
        (failure) {
          // On failure for a batch, mark every wine as errored and continue.
          allChanges.addAll(
            batch
                .map(
                  (w) => WineReevaluationChange.error(w, failure.message),
                )
                .toList(),
          );
        },
        allChanges.addAll,
      );
    }

    if (_cancelled) {
      state = const ReevaluationIdle();
      return;
    }

    // Pre-select only wines that have actual changes.
    final selectedIds = allChanges
        .where((c) => c.hasAnyChange && c.originalWine.id != null)
        .map((c) => c.originalWine.id!)
        .toSet();

    state = ReevaluationPreview(
      changes: allChanges,
      selectedWineIds: selectedIds,
    );
  }

  /// Toggle whether a specific wine's changes are included in the apply step.
  void toggleWineSelection(int wineId) {
    final current = state;
    if (current is! ReevaluationPreview) return;

    final updated = Set<int>.from(current.selectedWineIds);
    if (updated.contains(wineId)) {
      updated.remove(wineId);
    } else {
      updated.add(wineId);
    }
    state = current.copyWith(selectedWineIds: updated);
  }

  /// Select all wines that have actual changes.
  void selectAll() {
    final current = state;
    if (current is! ReevaluationPreview) return;

    final allWithChanges = current.changes
        .where((c) => c.hasAnyChange && c.originalWine.id != null)
        .map((c) => c.originalWine.id!)
        .toSet();
    state = current.copyWith(selectedWineIds: allWithChanges);
  }

  /// Deselect all wines.
  void deselectAll() {
    final current = state;
    if (current is! ReevaluationPreview) return;
    state = current.copyWith(selectedWineIds: {});
  }

  /// Apply changes for the selected wines to the database.
  Future<void> applySelected() async {
    final current = state;
    if (current is! ReevaluationPreview) return;
    if (current.selectedWineIds.isEmpty) return;

    state = const ReevaluationApplying();

    final updateUseCase = _ref.read(updateWineUseCaseProvider);
    var appliedCount = 0;

    for (final change in current.changes) {
      final wineId = change.originalWine.id;
      if (wineId == null) continue;
      if (!current.selectedWineIds.contains(wineId)) continue;
      if (!change.hasAnyChange) continue;

      final original = change.originalWine;

      final updated = original.copyWith(
        drinkFromYear: change.hasDrinkingWindowChange &&
                change.newDrinkFromYear != null
            ? change.newDrinkFromYear
            : original.drinkFromYear,
        drinkUntilYear: change.hasDrinkingWindowChange &&
                change.newDrinkUntilYear != null
            ? change.newDrinkUntilYear
            : original.drinkUntilYear,
        aiSuggestedDrinkFromYear: change.hasDrinkingWindowChange
            ? true
            : original.aiSuggestedDrinkFromYear,
        aiSuggestedDrinkUntilYear: change.hasDrinkingWindowChange
            ? true
            : original.aiSuggestedDrinkUntilYear,
        foodCategoryIds: change.hasFoodPairingsChange
            ? change.newFoodCategoryIds!
            : original.foodCategoryIds,
        aiSuggestedFoodPairings: change.hasFoodPairingsChange
            ? true
            : original.aiSuggestedFoodPairings,
      );

      final result = await updateUseCase(updated);
      result.fold((_) {}, (_) => appliedCount++);
    }

    state = ReevaluationApplied(
      appliedCount: appliedCount,
      unchangedCount: current.unchangedCount,
      errorCount: current.errorCount,
    );
  }

  /// Cancel the ongoing processing.
  void cancel() {
    _cancelled = true;
  }

  /// Reset to idle state.
  void reset() {
    _cancelled = false;
    state = const ReevaluationIdle();
  }
}

// ============================================================
//  Providers
// ============================================================

final reevaluateBatchUseCaseProvider = Provider<ReevaluateBatchUseCase>((ref) {
  return const ReevaluateBatchUseCase();
});

final reevaluationNotifierProvider =
    StateNotifierProvider.autoDispose<ReevaluationNotifier, ReevaluationState>(
  (ref) => ReevaluationNotifier(
    ref.watch(reevaluateBatchUseCaseProvider),
    ref,
  ),
);
