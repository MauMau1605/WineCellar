import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_move_state_entity.dart';

/// State notifier for managing bottle movement mode.
class BottleMoveStateNotifier extends StateNotifier<BottleMoveStateEntity> {
  BottleMoveStateNotifier(int cellarId)
      : super(BottleMoveStateEntity.initial(cellarId));

  /// Toggle movement mode on/off.
  void toggleMovementMode() {
    state = state.copyWith(
      isMovementMode: !state.isMovementMode,
      isDragModeEnabled: false,
    );
    // Clear selection when exiting movement mode
    if (!state.isMovementMode) {
      state = state.copyWith(
        selectedPlacementIds: <int>{},
        isDragModeEnabled: false,
      );
    }
  }

  /// Toggle selection of a bottle placement.
  void togglePlacementSelection(int placementId) {
    final newSelection = Set<int>.from(state.selectedPlacementIds);
    if (newSelection.contains(placementId)) {
      newSelection.remove(placementId);
    } else {
      newSelection.add(placementId);
    }
    state = state.copyWith(
      selectedPlacementIds: newSelection,
      isDragModeEnabled: false,
    );
  }

  /// Clear all selections.
  void clearSelection() {
    state = state.copyWith(
      selectedPlacementIds: <int>{},
      isDragModeEnabled: false,
    );
  }

  /// Enter movement mode and select one bottle immediately.
  void startMoving(int placementId) {
    state = state.copyWith(
      isMovementMode: true,
      isDragModeEnabled: false,
      selectedPlacementIds: <int>{placementId},
    );
  }

  /// Enable explicit drag mode after selection is complete.
  void enableDragMode() {
    if (state.selectedPlacementIds.isEmpty) return;
    state = state.copyWith(isDragModeEnabled: true);
  }

  /// Return to selection mode while keeping current selection.
  void enableSelectionMode() {
    state = state.copyWith(isDragModeEnabled: false);
  }

  /// Exit movement mode and clear selection.
  void exitMovementMode() {
    state = state.copyWith(
      isMovementMode: false,
      isDragModeEnabled: false,
      selectedPlacementIds: <int>{},
    );
  }
}

/// Provider for managing bottle movement state for a specific cellar.
// Scoped per cellar - parameter is cellarId
final bottleMoveStateProvider =
    StateNotifierProvider.family<BottleMoveStateNotifier, BottleMoveStateEntity, int>(
  (ref, cellarId) => BottleMoveStateNotifier(cellarId),
);
