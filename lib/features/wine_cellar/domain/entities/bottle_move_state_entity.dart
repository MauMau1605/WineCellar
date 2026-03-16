/// State for managing bottle movement in the cellar.
class BottleMoveStateEntity {
  /// Whether we are in movement mode.
  final bool isMovementMode;

  /// Whether selection is locked and drag/drop is enabled.
  final bool isDragModeEnabled;

  /// Set of placement IDs currently selected for movement.
  final Set<int> selectedPlacementIds;

  /// The cellar ID we're working in.
  final int cellarId;

  const BottleMoveStateEntity({
    required this.isMovementMode,
    required this.isDragModeEnabled,
    required this.selectedPlacementIds,
    required this.cellarId,
  });

  /// Create a copy with optional field overrides.
  BottleMoveStateEntity copyWith({
    bool? isMovementMode,
    bool? isDragModeEnabled,
    Set<int>? selectedPlacementIds,
    int? cellarId,
  }) {
    return BottleMoveStateEntity(
      isMovementMode: isMovementMode ?? this.isMovementMode,
      isDragModeEnabled: isDragModeEnabled ?? this.isDragModeEnabled,
      selectedPlacementIds: selectedPlacementIds ?? this.selectedPlacementIds,
      cellarId: cellarId ?? this.cellarId,
    );
  }

  /// Create an initial state for a cellar.
  factory BottleMoveStateEntity.initial(int cellarId) {
    return BottleMoveStateEntity(
      isMovementMode: false,
      isDragModeEnabled: false,
      selectedPlacementIds: <int>{},
      cellarId: cellarId,
    );
  }

  /// Check if a placement is selected.
  bool isSelected(int placementId) => selectedPlacementIds.contains(placementId);

  /// Check if any placements are selected.
  bool get hasSelection => selectedPlacementIds.isNotEmpty;
}
