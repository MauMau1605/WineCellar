import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/cellar_theme_data.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_move_state_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/place_wine_in_cellar.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/helpers/virtual_cellar_detail_helper.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/providers/bottle_move_state_provider.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/premium_cave_screen_background.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/premium_cave_wrapper.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/stone_cave_screen_background.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/stone_cave_wrapper.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/garage_industrial_screen_background.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/garage_industrial_wrapper.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/virtual_cellar_theme_selector.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/wine_consumption_highlight.dart';

class VirtualCellarDetailScreen extends ConsumerStatefulWidget {
  final int cellarId;
  final int? preSelectedWineId;
  final int? highlightWineId;

  const VirtualCellarDetailScreen({
    super.key,
    required this.cellarId,
    this.preSelectedWineId,
    this.highlightWineId,
  });

  @override
  ConsumerState<VirtualCellarDetailScreen> createState() =>
      _VirtualCellarDetailScreenState();
}

class _VirtualCellarDetailScreenState
    extends ConsumerState<VirtualCellarDetailScreen> {
  VirtualCellarEntity? _cellar;
  List<BottlePlacementEntity> _placedBottles = [];
  bool _loading = true;
  _PendingPlacement? _pendingPlacement;
  _MoveUndoSnapshot? _lastMoveUndo;
  final Set<WineMaturity> _maturityFilters = <WineMaturity>{};

  @override
  void initState() {
    super.initState();
    _loadCellar();
  }

  @override
  void dispose() {
    // Clear immersive theme when leaving this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(immersiveCellarThemeProvider.notifier).state = null;
    });
    super.dispose();
  }

  Future<void> _loadCellar() async {
    final result = await ref
        .read(virtualCellarRepositoryProvider)
        .getById(widget.cellarId);
    result.fold((_) => setState(() => _loading = false), (cellar) {
      setState(() {
        _cellar = cellar;
        _loading = false;
      });
      if (cellar != null) {
        _applyImmersiveTheme(cellar.theme);
      }
      if (widget.preSelectedWineId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startPreSelectedPlacement(widget.preSelectedWineId!);
        });
      }
    });
  }

  void _applyImmersiveTheme(VirtualCellarTheme theme) {
    ref.read(immersiveCellarThemeProvider.notifier).state =
        VirtualCellarDetailHelper.immersiveThemeFor(theme);
  }

  Future<void> _startPreSelectedPlacement(int wineId) async {
    final wineResult = await ref.read(getWineByIdUseCaseProvider).call(wineId);
    if (!mounted) return;

    final wine = wineResult.fold((_) => null, (value) => value);
    if (wine == null) return;

    final countResult = await ref
        .read(virtualCellarRepositoryProvider)
        .getPlacedBottleCount(wineId);
    if (!mounted) return;

    final placedCount = countResult.getOrElse((_) => 0);
    final unplaced = wine.quantity - placedCount;

    if (unplaced <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              VirtualCellarDetailHelper.preselectedAlreadyPlacedMessage(
                wine.displayName,
              ),
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          VirtualCellarDetailHelper.preselectedPlacementTitle(
            wine.displayName,
          ),
        ),
        content: Text(
          VirtualCellarDetailHelper.preselectedPlacementContent(unplaced),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(VirtualCellarDetailHelper.preselectedCancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(VirtualCellarDetailHelper.preselectedStartLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _pendingPlacement = _PendingPlacement(
        wine: wine,
        remaining: unplaced,
        returnToWineId: wineId,
      );
    });
  }

  /// Handle long press on a bottle placement.
  void _onLongPressPlacement(int placementId) {
    final moveNotifier = ref.read(
      bottleMoveStateProvider(widget.cellarId).notifier,
    );
    final moveState = ref.read(bottleMoveStateProvider(widget.cellarId));

    if (!moveState.isMovementMode) {
      moveNotifier.startMoving(placementId);
    } else {
      moveNotifier.togglePlacementSelection(placementId);
    }
  }

  /// Handle dropping selected placements using an anchor bottle translation.
  Future<void> _onMovePlacement({
    required int anchorPlacementId,
    required int targetRow,
    required int targetCol,
    required List<BottlePlacementEntity> allPlacements,
    required VirtualCellarEntity cellar,
  }) async {
    final moveState = ref.read(bottleMoveStateProvider(widget.cellarId));

    if (moveState.selectedPlacementIds.isEmpty) {
      return;
    }

    final anchor = allPlacements
        .where((p) => p.id == anchorPlacementId)
        .firstOrNull;
    if (anchor == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(VirtualCellarDetailHelper.missingAnchorSnackBar),
          ),
        );
      }
      return;
    }

    final undoSnapshot = _MoveUndoSnapshot(
      anchorPlacementId: anchorPlacementId,
      oldAnchorX: anchor.positionX,
      oldAnchorY: anchor.positionY,
      movedPlacementIds: Set<int>.from(moveState.selectedPlacementIds),
    );

    try {
      final result = await ref
          .read(moveBottlesInCellarUseCaseProvider)
          .call(
            allPlacements: allPlacements,
            selectedPlacementIds: moveState.selectedPlacementIds,
            anchorPlacementId: anchorPlacementId,
            targetAnchorX: targetCol,
            targetAnchorY: targetRow,
            maxColumns: cellar.columns,
            maxRows: cellar.rows,
          );

      if (!mounted) return;

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: ${failure.message}')),
            );
          }
        },
        (_) {
          _lastMoveUndo = undoSnapshot;
          if (context.mounted) {
            final messenger = ScaffoldMessenger.of(context);
            messenger
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Déplacement appliqué'),
                  action: SnackBarAction(
                    label: 'Annuler',
                    onPressed: () {
                      final snapshot = _lastMoveUndo;
                      if (snapshot == null) return;
                      _undoLastMove(snapshot, cellar);
                    },
                  ),
                ),
              );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _undoLastMove(
    _MoveUndoSnapshot snapshot,
    VirtualCellarEntity cellar,
  ) async {
    try {
      final latestPlacements = await ref
          .read(virtualCellarRepositoryProvider)
          .watchPlacementsByCellarId(widget.cellarId)
          .first;

      final result = await ref
          .read(moveBottlesInCellarUseCaseProvider)
          .call(
            allPlacements: latestPlacements,
            selectedPlacementIds: snapshot.movedPlacementIds,
            anchorPlacementId: snapshot.anchorPlacementId,
            targetAnchorX: snapshot.oldAnchorX,
            targetAnchorY: snapshot.oldAnchorY,
            maxColumns: cellar.columns,
            maxRows: cellar.rows,
          );

      if (!mounted) return;
      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Annulation impossible: ${failure.message}'),
              ),
            );
          }
        },
        (_) {
          _lastMoveUndo = null;
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Déplacement annulé')));
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur annulation: $e')));
      }
    }
  }

  Future<void> _updateCellarTheme(VirtualCellarTheme theme) async {
    final cellar = _cellar;
    if (cellar == null || cellar.theme == theme) {
      return;
    }

    final updated = cellar.copyWith(theme: theme);
    final result = await ref
        .read(updateVirtualCellarUseCaseProvider)
        .call(updated);
    if (!mounted) {
      return;
    }

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        setState(() {
          _cellar = updated;
        });
        _applyImmersiveTheme(theme);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlightLastConsumptionYear =
        ref.watch(highlightLastConsumptionYearProvider);
    final highlightPastOptimalConsumption =
        ref.watch(highlightPastOptimalConsumptionProvider);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cellar = _cellar;
    if (cellar == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cellier introuvable')),
        body: const Center(child: Text('Ce cellier n\'existe plus.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(cellar.name),
        actions: [
          PopupMenuButton<VirtualCellarTheme>(
            tooltip: VirtualCellarDetailHelper.changeRepresentationTooltip,
            icon: Icon(iconForVirtualCellarTheme(cellar.theme)),
            onSelected: _updateCellarTheme,
            itemBuilder: (context) {
              return VirtualCellarDetailHelper.buildThemeMenuOptions(
                    cellar.theme,
                  )
                  .map((option) {
                    return PopupMenuItem<VirtualCellarTheme>(
                      value: option.theme,
                      child: Row(
                        children: [
                          Icon(
                            iconForVirtualCellarTheme(option.theme),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(option.label)),
                          if (option.selected)
                            Icon(
                              Icons.check,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false);
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final moveState = ref.watch(
                bottleMoveStateProvider(widget.cellarId),
              );
              final controls = VirtualCellarDetailHelper.movementControlsFor(
                moveState,
              );
              final notifier = ref.read(
                bottleMoveStateProvider(widget.cellarId).notifier,
              );
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controls.showSelectionToggle)
                    IconButton(
                      icon: Icon(controls.selectionToggleIcon),
                      tooltip: controls.selectionToggleTooltip,
                      onPressed: () {
                        if (moveState.isDragModeEnabled) {
                          notifier.enableSelectionMode();
                        } else {
                          notifier.enableDragMode();
                        }
                      },
                    ),
                  IconButton(
                    icon: Icon(controls.modeIcon),
                    tooltip: controls.modeTooltip,
                    onPressed: () {
                      notifier.toggleMovementMode();
                    },
                  ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: VirtualCellarDetailHelper.editCellarTooltip,
            onPressed: () => _showEditDialog(context, cellar),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (VirtualCellarDetailHelper.backgroundKindFor(cellar.theme) ==
              VirtualCellarBackgroundKind.premium)
            const PremiumCaveScreenBackground(),
          if (VirtualCellarDetailHelper.backgroundKindFor(cellar.theme) ==
              VirtualCellarBackgroundKind.stone)
            const StoneCaveScreenBackground(),
          if (VirtualCellarDetailHelper.backgroundKindFor(cellar.theme) ==
              VirtualCellarBackgroundKind.garage)
            const GarageIndustrialScreenBackground(),
          StreamBuilder<List<BottlePlacementEntity>>(
        stream: ref
            .watch(virtualCellarRepositoryProvider)
            .watchPlacementsByCellarId(widget.cellarId),
        builder: (context, snapshot) {
          final placements = snapshot.data ?? const [];
          final filteredPlacements = placements
              .where(_matchesMaturityFilter)
              .toList(growable: false);
          _placedBottles = placements;
          return Column(
            children: [
              _buildMaturityFilterBar(
                context,
                totalCount: placements.length,
                visibleCount: filteredPlacements.length,
              ),
              Expanded(
                child: _CellarGridView(
                  cellar: cellar,
                  visiblePlacements: filteredPlacements,
                  allPlacements: placements,
                  pendingPlacement: _pendingPlacement,
                  onSlotTap: (row, col) =>
                      _onSlotTap(context, cellar, placements, row, col),
                  cellarId: widget.cellarId,
                  highlightWineId: widget.highlightWineId,
                  onLongPressPlacement: _onLongPressPlacement,
                  onMovePlacement:
                      ({
                        required anchorPlacementId,
                        required targetRow,
                        required targetCol,
                        required allPlacements,
                      }) => _onMovePlacement(
                        anchorPlacementId: anchorPlacementId,
                        targetRow: targetRow,
                        targetCol: targetCol,
                        allPlacements: allPlacements,
                        cellar: cellar,
                      ),
                  highlightLastConsumptionYear: highlightLastConsumptionYear,
                  highlightPastOptimalConsumption:
                      highlightPastOptimalConsumption,
                ),
              ),
            ],
          );
        },
      ),
        ],
      ),
    );
  }

  bool _matchesMaturityFilter(BottlePlacementEntity placement) {
    return VirtualCellarDetailHelper.matchesMaturityFilter(
      _maturityFilters,
      placement.wine.maturity,
    );
  }

  Widget _buildMaturityFilterBar(
    BuildContext context, {
    required int totalCount,
    required int visibleCount,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              VirtualCellarDetailHelper.maturityFilterTitle,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: WineMaturity.values
                  .map((maturity) {
                    final selected = _maturityFilters.contains(maturity);
                    return FilterChip(
                      label: Text(maturity.label),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          _maturityFilters
                            ..clear()
                            ..addAll(
                              VirtualCellarDetailHelper.updateMaturityFilters(
                                _maturityFilters,
                                maturity,
                                value,
                              ),
                            );
                        });
                      },
                    );
                  })
                  .toList(growable: false),
            ),
            if (VirtualCellarDetailHelper.shouldShowMaturitySummary(
              _maturityFilters,
            ))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        VirtualCellarDetailHelper.maturitySummaryText(
                          visibleCount,
                          totalCount,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _maturityFilters.clear());
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                      label: const Text(
                        VirtualCellarDetailHelper.resetFiltersLabel,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSlotTap(
    BuildContext context,
    VirtualCellarEntity cellar,
    List<BottlePlacementEntity> placements,
    int row,
    int col,
  ) async {
    if (cellar.isCellEmpty(oneBasedRow: row + 1, oneBasedCol: col + 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(VirtualCellarDetailHelper.emptyZoneSnackBar),
        ),
      );
      return;
    }

    final placementAtSlot = placements
        .where((p) => p.positionX == col && p.positionY == row)
        .firstOrNull;

    if (_pendingPlacement != null) {
      if (placementAtSlot != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(VirtualCellarDetailHelper.occupiedSlotSnackBar),
          ),
        );
        return;
      }
      await _placePendingBottleAt(context, row, col);
      return;
    }

    if (placementAtSlot != null) {
      await _showBottleInfoDialog(context, placementAtSlot, cellar.name);
      return;
    }

    await _showPlaceWineDialog(context, row, col, placements);
  }

  Future<void> _showBottleInfoDialog(
    BuildContext context,
    BottlePlacementEntity placement,
    String cellarName,
  ) async {
    final wine = placement.wine;
    final colorValue = AppTheme.colorForWine(wine.color.name);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: colorValue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(wine.displayName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Cellier', cellarName),
            _infoRow(
              'Position',
              'Rangée ${placement.positionY + 1}, Colonne ${placement.positionX + 1}',
            ),
            _infoRow('Couleur', '${wine.color.emoji} ${wine.color.label}'),
            if (wine.vintage != null) _infoRow('Millésime', '${wine.vintage}'),
            if (wine.drinkFromYear != null || wine.drinkUntilYear != null)
              _infoRow(
                'Fenêtre de dégustation',
                '${wine.drinkFromYear ?? '?'} – ${wine.drinkUntilYear ?? '?'}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(removeBottlePlacementUseCaseProvider)
                  .call(placement.id);
            },
            child: const Text('Retirer cette bouteille'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (wine.id != null) {
                context.push('/cellar/wine/${wine.id}');
              }
            },
            child: const Text('Voir la fiche'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlaceWineDialog(
    BuildContext context,
    int row,
    int col,
    List<BottlePlacementEntity> placements,
  ) async {
    final allWines = await ref.read(wineRepositoryProvider).getAllWines();
    final countPairs = await Future.wait(
      allWines.map((wine) async {
        final id = wine.id;
        if (id == null) return (wine, 0);
        final countResult = await ref
            .read(virtualCellarRepositoryProvider)
            .getPlacedBottleCount(id);
        return (wine, countResult.getOrElse((_) => 0));
      }),
    );

    final placedCountsByWineId = <int, int>{
      for (final pair in countPairs)
        if (pair.$1.id != null) pair.$1.id!: pair.$2,
    };
    final availableChoices =
        VirtualCellarDetailHelper.buildAvailableWineChoices(
      allWines,
      placedCountsByWineId,
    );
    final availableCountByWineId = <int, int>{
      for (final choice in availableChoices) choice.wine.id!: choice.unplacedCount,
    };
    final availableWines = availableChoices
        .map((choice) => choice.wine)
        .toList(growable: false);

    if (!context.mounted) return;
    if (availableWines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(VirtualCellarDetailHelper.noBottleAvailableSnackBar),
        ),
      );
      return;
    }

    final chosen = await showDialog<WineEntity>(
      context: context,
      builder: (ctx) => _WinePickerDialog(
        wines: availableWines,
        availableCountByWineId: availableCountByWineId,
      ),
    );

    if (chosen == null || chosen.id == null || !context.mounted) return;

    final maxCount = availableCountByWineId[chosen.id!] ?? 1;
    final selectedCount =
      VirtualCellarDetailHelper.shouldAskHowManyBottles(maxCount)
        ? await _askHowManyBottlesToPlace(context, chosen, maxCount)
        : 1;

    if (!context.mounted || selectedCount == null || selectedCount <= 0) return;

    await _placeMultipleBottles(
      context: context,
      wine: chosen,
      startRow: row,
      startCol: col,
      count: selectedCount,
      currentPlacements: placements,
    );
  }

  Future<int?> _askHowManyBottlesToPlace(
    BuildContext context,
    WineEntity wine,
    int maxCount,
  ) async {
    var count = 1;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            VirtualCellarDetailHelper.askBottleCountTitle(wine.displayName),
          ),
          content: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: count > 1
                    ? () => setDialogState(() => count--)
                    : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$count / $maxCount',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: count < maxCount
                    ? () => setDialogState(() => count++)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(count),
              child: const Text(VirtualCellarDetailHelper.placeBottleLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeMultipleBottles({
    required BuildContext context,
    required WineEntity wine,
    required int startRow,
    required int startCol,
    required int count,
    required List<BottlePlacementEntity> currentPlacements,
  }) async {
    final occupied = <(int, int)>{
      for (final p in currentPlacements) (p.positionY, p.positionX),
    };

    if (occupied.contains((startRow, startCol))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(VirtualCellarDetailHelper.occupiedSlotSnackBar),
        ),
      );
      return;
    }

    final firstPlaced = await _placeSingleBottle(
      context,
      wineId: wine.id!,
      row: startRow,
      col: startCol,
    );
    if (!firstPlaced) return;

    occupied.add((startRow, startCol));
    var remaining = count - 1;
    var nextCol = startCol + 1;

    while (remaining > 0 && _cellar != null && nextCol < _cellar!.columns) {
      if (!occupied.contains((startRow, nextCol))) {
        if (!context.mounted) return;
        final placed = await _placeSingleBottle(
          context,
          wineId: wine.id!,
          row: startRow,
          col: nextCol,
        );
        if (!placed) break;
        occupied.add((startRow, nextCol));
        remaining--;
      } else {
        break;
      }
      nextCol++;
    }

    if (!mounted || !context.mounted) return;

    if (remaining > 0) {
      setState(() {
        _pendingPlacement = _PendingPlacement(wine: wine, remaining: remaining);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            VirtualCellarDetailHelper.remainingManualPlacementMessage(
              remaining,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _placePendingBottleAt(
    BuildContext context,
    int row,
    int col,
  ) async {
    final pending = _pendingPlacement;
    if (pending == null || pending.wine.id == null) return;

    final placed = await _placeSingleBottle(
      context,
      wineId: pending.wine.id!,
      row: row,
      col: col,
    );
    if (!placed || !mounted) return;

    final left = pending.remaining - 1;
    if (left <= 0) {
      setState(() => _pendingPlacement = null);
      if (!context.mounted) return;
      if (pending.returnToWineId != null) {
        final goBack = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(VirtualCellarDetailHelper.placementCompleteTitle),
            content: Text(
              VirtualCellarDetailHelper.placementCompletedDialogContent(
                pending.wine.displayName,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(VirtualCellarDetailHelper.stayLabel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  VirtualCellarDetailHelper.returnToDetailsLabel,
                ),
              ),
            ],
          ),
        );
        if (goBack == true && context.mounted) {
          context.push('/cellar/wine/${pending.returnToWineId}');
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(VirtualCellarDetailHelper.placementFinishedSnackBar),
          ),
        );
      }
      return;
    }

    if (pending.returnToWineId != null) {
      if (!context.mounted) return;
      final continuePlace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(VirtualCellarDetailHelper.bottlePlacedTitle),
          content: Text(
            VirtualCellarDetailHelper.continuePlacementDialogContent(left),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(VirtualCellarDetailHelper.stopPlacementLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                VirtualCellarDetailHelper.placeNextBottleLabel,
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (continuePlace != true) {
        setState(() => _pendingPlacement = null);
        return;
      }
    }

    setState(() {
      _pendingPlacement = _PendingPlacement(
        wine: pending.wine,
        remaining: left,
        returnToWineId: pending.returnToWineId,
      );
    });
  }

  Future<bool> _placeSingleBottle(
    BuildContext context, {
    required int wineId,
    required int row,
    required int col,
  }) async {
    final result = await ref
        .read(placeWineInCellarUseCaseProvider)
        .call(
          PlaceWineParams(
            wineId: wineId,
            cellarId: widget.cellarId,
            positionX: col,
            positionY: row,
          ),
        );

    return result.fold((failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
      return false;
    }, (_) => true);
  }

  Future<void> _showEditDialog(
    BuildContext context,
    VirtualCellarEntity cellar,
  ) async {
    final nameCtrl = TextEditingController(text: cellar.name);
    var rows = cellar.rows;
    var cols = cellar.columns;
    var theme = cellar.theme;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le cellier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 16),
                VirtualCellarThemeSelector(
                  selectedTheme: theme,
                  onChanged: (newTheme) {
                    setDialogState(() => theme = newTheme);
                  },
                ),
                const SizedBox(height: 16),
                _StepperRow(
                  label: 'Rangées',
                  value: rows,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setDialogState(() => rows = v),
                ),
                const SizedBox(height: 8),
                _StepperRow(
                  label: 'Colonnes',
                  value: cols,
                  min: 1,
                  max: 30,
                  onChanged: (v) => setDialogState(() => cols = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final displaced = _placedBottles.where((p) {
                  return p.positionY >= rows || p.positionX >= cols;
                }).toList();

                Navigator.of(ctx).pop();

                // Handle row insertion position if rows increased
                int? rowInsertPosition;
                if (rows > cellar.rows && context.mounted) {
                  rowInsertPosition = await _showInsertPositionDialog(
                    context,
                    'Rangées',
                    cellar.rows,
                    rows - cellar.rows,
                  );
                  if (rowInsertPosition == null) return;
                }

                // Handle column insertion position if columns increased
                int? colInsertPosition;
                if (cols > cellar.columns && context.mounted) {
                  colInsertPosition = await _showInsertPositionDialog(
                    context,
                    'Colonnes',
                    cellar.columns,
                    cols - cellar.columns,
                  );
                  if (colInsertPosition == null) return;
                }

                if (displaced.isNotEmpty && context.mounted) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c2) => AlertDialog(
                      title: const Text('Attention'),
                      content: Text(
                        '${displaced.length} bouteille(s) seront retirée(s) car hors des nouvelles dimensions.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(c2).pop(false),
                          child: const Text('Annuler'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(c2).pop(true),
                          child: const Text('Confirmer'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;

                  for (final p in displaced) {
                    await ref
                        .read(removeBottlePlacementUseCaseProvider)
                        .call(p.id);
                  }
                }

                // Reindex placements if needed
                if ((rowInsertPosition != null &&
                        rowInsertPosition != cellar.rows) ||
                    (colInsertPosition != null &&
                        colInsertPosition != cellar.columns)) {
                  await _reindexPlacementsAfterInsertion(
                    rowInsertPosition,
                    colInsertPosition,
                    cellar.rows,
                    cellar.columns,
                  );
                }

                final result = await ref
                    .read(updateVirtualCellarUseCaseProvider)
                    .call(
                      cellar.copyWith(
                        name: name,
                        rows: rows,
                        columns: cols,
                        theme: theme,
                      ),
                    );
                result.fold(
                  (failure) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(failure.message)));
                    }
                  },
                  (_) => setState(
                    () => _cellar = cellar.copyWith(
                      name: name,
                      rows: rows,
                      columns: cols,
                      theme: theme,
                    ),
                  ),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to ask user where to insert new rows/columns.
  /// Returns the insertion position index, or null if cancelled.
  Future<int?> _showInsertPositionDialog(
    BuildContext context,
    String type,
    int currentCount,
    int addCount,
  ) async {
    int selectedPosition = currentCount; // Default to end

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Où ajouter $addCount $type?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sélectionnez la position d\'insertion pour les $addCount nouvelles $type:',
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                child: Column(
                  children: [
                    _InsertPositionTile(
                      title: 'Au début',
                      selected: selectedPosition == 0,
                      onTap: () => setState(() => selectedPosition = 0),
                    ),
                    if (currentCount > 0)
                      ...List.generate(
                        currentCount,
                        (idx) => _InsertPositionTile(
                          title:
                              'Entre ${type.toLowerCase()} ${idx + 1} et ${idx + 2}',
                          selected: selectedPosition == idx + 1,
                          onTap: () =>
                              setState(() => selectedPosition = idx + 1),
                        ),
                      ),
                    _InsertPositionTile(
                      title: 'À la fin',
                      selected: selectedPosition == currentCount,
                      onTap: () =>
                          setState(() => selectedPosition = currentCount),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(selectedPosition),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );

    return result;
  }

  /// Reindex placements when rows or columns are inserted at specific positions.
  /// Shifts existing placements if insertion is not at the end.
  Future<void> _reindexPlacementsAfterInsertion(
    int? rowInsertPos,
    int? colInsertPos,
    int oldRows,
    int oldCols,
  ) async {
    for (final placement in _placedBottles) {
      int newY = placement.positionY;
      int newX = placement.positionX;

      // Shift Y if rows were inserted before this placement
      if (rowInsertPos != null && rowInsertPos <= placement.positionY) {
        newY = placement.positionY;
      }

      // Shift X if columns were inserted before this placement
      if (colInsertPos != null && colInsertPos <= placement.positionX) {
        newX = placement.positionX;
      }

      // Only update if position changed
      if (newY != placement.positionY || newX != placement.positionX) {
        final result = await ref
            .read(virtualCellarRepositoryProvider)
            .moveBottleInCellar(
              placementId: placement.id,
              newPositionX: newX,
              newPositionY: newY,
            );

        result.fold((failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur reindexation: ${failure.message}'),
              ),
            );
          }
        }, (_) {});
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

const double _kCellWidth = 64;
const double _kCellHeight = 46;
const double _kRowNumWidth = 28;

class _GroupDragData {
  final int anchorPlacementId;

  const _GroupDragData({required this.anchorPlacementId});
}

class _MoveUndoSnapshot {
  final int anchorPlacementId;
  final int oldAnchorX;
  final int oldAnchorY;
  final Set<int> movedPlacementIds;

  const _MoveUndoSnapshot({
    required this.anchorPlacementId,
    required this.oldAnchorX,
    required this.oldAnchorY,
    required this.movedPlacementIds,
  });
}

class _CellarGridView extends ConsumerStatefulWidget {
  final VirtualCellarEntity cellar;
  final List<BottlePlacementEntity> visiblePlacements;
  final List<BottlePlacementEntity> allPlacements;
  final _PendingPlacement? pendingPlacement;
  final void Function(int row, int col) onSlotTap;
  final int cellarId;
  final int? highlightWineId;
  final bool highlightLastConsumptionYear;
  final bool highlightPastOptimalConsumption;
  final void Function(int placementId) onLongPressPlacement;
  final Future<void> Function({
    required int anchorPlacementId,
    required int targetRow,
    required int targetCol,
    required List<BottlePlacementEntity> allPlacements,
  })
  onMovePlacement;

  const _CellarGridView({
    required this.cellar,
    required this.visiblePlacements,
    required this.allPlacements,
    required this.pendingPlacement,
    required this.onSlotTap,
    required this.cellarId,
    this.highlightWineId,
    required this.highlightLastConsumptionYear,
    required this.highlightPastOptimalConsumption,
    required this.onLongPressPlacement,
    required this.onMovePlacement,
  });

  @override
  ConsumerState<_CellarGridView> createState() => _CellarGridViewState();
}

class _CellarGridViewState extends ConsumerState<_CellarGridView> {
  static const double _kMinZoom = 0.7;
  static const double _kMaxZoom = 2.0;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final GlobalKey _dragAreaKey = GlobalKey();
  final Map<int, Offset> _activePointers = <int, Offset>{};
  bool _highlightActive = false;

  int? _dragAnchorPlacementId;
  Set<(int, int)> _previewTargets = <(int, int)>{};
  bool _previewValid = false;
  double _zoomLevel = 1.0;
  double _pinchStartZoom = 1.0;
  double? _pinchStartDistance;

  @override
  void initState() {
    super.initState();
    if (widget.highlightWineId != null) {
      _highlightActive = true;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _highlightActive = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _startDrag(int anchorPlacementId) {
    setState(() {
      _dragAnchorPlacementId = anchorPlacementId;
      _previewTargets = <(int, int)>{};
      _previewValid = false;
    });
  }

  void _updateDragHover(int targetRow, int targetCol) {
    final anchorId = _dragAnchorPlacementId;
    if (anchorId == null) return;

    final allPlacements = widget.allPlacements;
    final selectedIds = ref
        .read(bottleMoveStateProvider(widget.cellarId))
        .selectedPlacementIds;
    final anchor = allPlacements.where((p) => p.id == anchorId).firstOrNull;
    if (anchor == null || selectedIds.isEmpty) return;

    final selectedPlacements = allPlacements
        .where((p) => selectedIds.contains(p.id))
        .toList(growable: false);

    final deltaX = targetCol - anchor.positionX;
    final deltaY = targetRow - anchor.positionY;

    final occupiedByOthers = <(int, int)>{
      for (final p in allPlacements)
        if (!selectedIds.contains(p.id)) (p.positionY, p.positionX),
    };

    var valid = true;
    final preview = <(int, int)>{};

    for (final placement in selectedPlacements) {
      final newX = placement.positionX + deltaX;
      final newY = placement.positionY + deltaY;
      if (newX < 0 ||
          newX >= widget.cellar.columns ||
          newY < 0 ||
          newY >= widget.cellar.rows) {
        valid = false;
        break;
      }
      if (widget.cellar.isCellEmpty(
        oneBasedRow: newY + 1,
        oneBasedCol: newX + 1,
      )) {
        valid = false;
      }
      if (occupiedByOthers.contains((newY, newX))) {
        valid = false;
      }
      preview.add((newY, newX));
    }

    setState(() {
      _previewTargets = preview;
      _previewValid = valid;
    });
  }

  Future<void> _acceptDrop(int targetRow, int targetCol) async {
    final anchorId = _dragAnchorPlacementId;
    if (anchorId == null) return;

    await widget.onMovePlacement(
      anchorPlacementId: anchorId,
      targetRow: targetRow,
      targetCol: targetCol,
      allPlacements: widget.allPlacements,
    );
    _endDrag();
  }

  void _endDrag() {
    if (!mounted) return;
    setState(() {
      _dragAnchorPlacementId = null;
      _previewTargets = <(int, int)>{};
      _previewValid = false;
    });
  }

  void _setZoom(double value) {
    setState(() {
      _zoomLevel = value.clamp(_kMinZoom, _kMaxZoom);
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length == 2) {
      _pinchStartDistance = _currentPinchDistance();
      _pinchStartZoom = _zoomLevel;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) {
      return;
    }

    _activePointers[event.pointer] = event.position;

    if (_activePointers.length < 2) {
      return;
    }

    final startDistance = _pinchStartDistance;
    final currentDistance = _currentPinchDistance();
    if (startDistance == null ||
        startDistance <= 0 ||
        currentDistance == null) {
      return;
    }

    _setZoom(_pinchStartZoom * (currentDistance / startDistance));
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _pinchStartDistance = null;
      _pinchStartZoom = _zoomLevel;
    }
  }

  double? _currentPinchDistance() {
    if (_activePointers.length < 2) {
      return null;
    }

    final positions = _activePointers.values.take(2).toList(growable: false);
    final dx = positions[0].dx - positions[1].dx;
    final dy = positions[0].dy - positions[1].dy;
    return math.sqrt((dx * dx) + (dy * dy));
  }

  void _handleDragPointerUpdate(Offset globalPosition) {
    final ctx = _dragAreaKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox) return;

    final local = renderObject.globalToLocal(globalPosition);
    final size = renderObject.size;

    const edgeSize = 44.0;
    const scrollStep = 18.0;

    if (_verticalController.hasClients) {
      final current = _verticalController.offset;
      final maxExtent = _verticalController.position.maxScrollExtent;
      if (local.dy < edgeSize) {
        _verticalController.jumpTo(math.max(0, current - scrollStep));
      } else if (local.dy > size.height - edgeSize) {
        _verticalController.jumpTo(math.min(maxExtent, current + scrollStep));
      }
    }

    if (_horizontalController.hasClients) {
      final current = _horizontalController.offset;
      final maxExtent = _horizontalController.position.maxScrollExtent;
      if (local.dx < edgeSize) {
        _horizontalController.jumpTo(math.max(0, current - scrollStep));
      } else if (local.dx > size.width - edgeSize) {
        _horizontalController.jumpTo(math.min(maxExtent, current + scrollStep));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cellar = widget.cellar;
    final placements = widget.visiblePlacements;
    final pendingPlacement = widget.pendingPlacement;
    final onSlotTap = widget.onSlotTap;
    final moveState = ref.watch(bottleMoveStateProvider(widget.cellarId));

    final lookup = <(int, int), BottlePlacementEntity>{};
    for (final p in placements) {
      if (p.positionX < cellar.columns &&
          p.positionY < cellar.rows &&
          !cellar.isCellEmpty(
            oneBasedRow: p.positionY + 1,
            oneBasedCol: p.positionX + 1,
          )) {
        lookup[(p.positionY, p.positionX)] = p;
      }
    }

    final occupied = lookup.length;
    final total = cellar.totalSlots;
    final cellWidth = _kCellWidth * _zoomLevel;
    final cellHeight = _kCellHeight * _zoomLevel;
    final rowNumWidth = _kRowNumWidth * _zoomLevel;
    final isPremiumCave = cellar.theme == VirtualCellarTheme.premiumCave;
    final isStoneCave = cellar.theme == VirtualCellarTheme.stoneCave;
    final isGarageIndustrial = cellar.theme == VirtualCellarTheme.garageIndustrial;
    final rowGap = 6 * _zoomLevel;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                cellar.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.zoom_out),
                tooltip: 'Dézoomer',
                onPressed: _zoomLevel <= _kMinZoom
                    ? null
                    : () => _setZoom(_zoomLevel - 0.1),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '${(_zoomLevel * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in),
                tooltip: 'Zoomer',
                onPressed: _zoomLevel >= _kMaxZoom
                    ? null
                    : () => _setZoom(_zoomLevel + 0.1),
              ),
              Text(
                '$occupied / $total emplacement${total > 1 ? 's' : ''} occupé${occupied > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (pendingPlacement != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Placement manuel en cours: ${pendingPlacement.remaining} bouteille(s) de ${pendingPlacement.wine.displayName}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerEnd,
            onPointerCancel: _handlePointerEnd,
            child: Container(
              key: _dragAreaKey,
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.vertical,
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    padding: const EdgeInsets.only(bottom: 80),
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: isPremiumCave
                          ? PremiumCaveWrapper(
                              columns: cellar.columns,
                              rows: cellar.rows,
                              cellWidth: cellWidth,
                              cellHeight: cellHeight,
                              rowNumWidth: rowNumWidth,
                              rowGap: rowGap,
                              gridChild: _buildGridContent(
                                context,
                                cellar: cellar,
                                lookup: lookup,
                                cellWidth: cellWidth,
                                cellHeight: cellHeight,
                                rowNumWidth: rowNumWidth,
                                rowGap: rowGap,
                                onSlotTap: onSlotTap,
                                moveState: moveState,
                              ),
                            )
                          : isStoneCave
                          ? StoneCaveWrapper(
                              columns: cellar.columns,
                              rows: cellar.rows,
                              cellWidth: cellWidth,
                              cellHeight: cellHeight,
                              rowNumWidth: rowNumWidth,
                              rowGap: rowGap,
                              gridChild: _buildGridContent(
                                context,
                                cellar: cellar,
                                lookup: lookup,
                                cellWidth: cellWidth,
                                cellHeight: cellHeight,
                                rowNumWidth: rowNumWidth,
                                rowGap: rowGap,
                                onSlotTap: onSlotTap,
                                moveState: moveState,
                              ),
                            )
                          : isGarageIndustrial
                          ? GarageIndustrialWrapper(
                              columns: cellar.columns,
                              rows: cellar.rows,
                              cellWidth: cellWidth,
                              cellHeight: cellHeight,
                              rowNumWidth: rowNumWidth,
                              rowGap: rowGap,
                              gridChild: _buildGridContent(
                                context,
                                cellar: cellar,
                                lookup: lookup,
                                cellWidth: cellWidth,
                                cellHeight: cellHeight,
                                rowNumWidth: rowNumWidth,
                                rowGap: rowGap,
                                onSlotTap: onSlotTap,
                                moveState: moveState,
                              ),
                            )
                          : Container(
                        padding: EdgeInsets.fromLTRB(
                          10 * _zoomLevel,
                          10 * _zoomLevel,
                          12 * _zoomLevel,
                          12 * _zoomLevel,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            14,
                          ),
                          color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                          border: Border.all(
                            color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh,
                          ),
                        ),
                        child: _buildGridContent(
                                context,
                                cellar: cellar,
                                lookup: lookup,
                                cellWidth: cellWidth,
                                cellHeight: cellHeight,
                                rowNumWidth: rowNumWidth,
                                rowGap: rowGap,
                                onSlotTap: onSlotTap,
                                moveState: moveState,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _Legend(),
      ],
    );
  }

  String _rowLabel(int rowIndex) {
    final base = 'A'.codeUnitAt(0);
    if (rowIndex < 26) {
      return String.fromCharCode(base + rowIndex);
    }
    final first = (rowIndex ~/ 26) - 1;
    final second = rowIndex % 26;
    return '${String.fromCharCode(base + first)}${String.fromCharCode(base + second)}';
  }

  Widget _buildGridContent(
    BuildContext context, {
    required VirtualCellarEntity cellar,
    required Map<(int, int), BottlePlacementEntity> lookup,
    required double cellWidth,
    required double cellHeight,
    required double rowNumWidth,
    required double rowGap,
    required void Function(int row, int col) onSlotTap,
    required BottleMoveStateEntity moveState,
  }) {
    final isPremiumCave = cellar.theme == VirtualCellarTheme.premiumCave;
    final isStoneCave = cellar.theme == VirtualCellarTheme.stoneCave;
    final isGarageIndustrial = cellar.theme == VirtualCellarTheme.garageIndustrial;
    final labelColor = isPremiumCave
        ? const Color(0xCCA8C8E0)
        : isStoneCave
        ? const Color(0xCCF0E4D0)
        : isGarageIndustrial
        ? const Color(0xCCD0D4DA)
        : Theme.of(context).colorScheme.outline;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: labelColor,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: rowNumWidth),
            ...List.generate(cellar.columns, (col) {
              return SizedBox(
                width: cellWidth,
                child: Center(
                  child: Text('${col + 1}', style: labelStyle),
                ),
              );
            }),
          ],
        ),
        SizedBox(height: rowGap),
        ...List.generate(cellar.rows, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: rowGap),
            child: Row(
              children: [
                SizedBox(
                  width: rowNumWidth,
                  child: Center(
                    child: Text(_rowLabel(row), style: labelStyle),
                  ),
                ),
                ...List.generate(cellar.columns, (col) {
                  final placement = lookup[(row, col)];
                  final isEmptyCell = cellar.isCellEmpty(
                    oneBasedRow: row + 1,
                    oneBasedCol: col + 1,
                  );
                  final isPreviewTarget =
                      _previewTargets.contains((row, col));
                  final hideBottleVisual =
                      _dragAnchorPlacementId != null &&
                      placement != null &&
                      moveState.selectedPlacementIds
                          .contains(placement.id) &&
                      !isPreviewTarget;
                  final showDragGhost =
                      _dragAnchorPlacementId != null && isPreviewTarget;
                  return SizedBox(
                    width: cellWidth,
                    height: cellHeight,
                    child: DragTarget<_GroupDragData>(
                      onWillAcceptWithDetails: (_) => true,
                      onMove: (_) => _updateDragHover(row, col),
                      onAcceptWithDetails: (_) => _acceptDrop(row, col),
                      onLeave: (_) {
                        if (_dragAnchorPlacementId == null) return;
                        setState(() {
                          _previewTargets = <(int, int)>{};
                          _previewValid = false;
                        });
                      },
                      builder: (context, candidateData, rejectedData) {
                        return _SlotCell(
                          placement: placement,
                          onTap: () => onSlotTap(row, col),
                          cellarId: widget.cellarId,
                          onLongPressPlacement:
                              widget.onLongPressPlacement,
                          row: row,
                          col: col,
                          cellarTheme: cellar.theme,
                          isEmptyCell: isEmptyCell,
                          isPreviewTarget: isPreviewTarget,
                          previewIsValid: _previewValid,
                          selectedCount:
                              moveState.selectedPlacementIds.length,
                          onDragStarted: _startDrag,
                          onDragEnded: _endDrag,
                          onDragPointerUpdate:
                              _handleDragPointerUpdate,
                          hideBottleVisual: hideBottleVisual,
                          showDragGhost: showDragGhost,
                          isHighlighted: _highlightActive &&
                              placement != null &&
                              placement.wineId == widget.highlightWineId,
                            highlightLastConsumptionYear:
                              widget.highlightLastConsumptionYear,
                            highlightPastOptimalConsumption:
                              widget.highlightPastOptimalConsumption,
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _SlotCell extends ConsumerStatefulWidget {
  final BottlePlacementEntity? placement;
  final VoidCallback onTap;
  final int cellarId;
  final void Function(int) onLongPressPlacement;
  final int row;
  final int col;
  final VirtualCellarTheme cellarTheme;
  final bool isEmptyCell;
  final bool isHighlighted;
  final bool isPreviewTarget;
  final bool previewIsValid;
  final int selectedCount;
  final void Function(int anchorPlacementId) onDragStarted;
  final VoidCallback onDragEnded;
  final void Function(Offset globalPosition) onDragPointerUpdate;
  final bool hideBottleVisual;
  final bool showDragGhost;
  final bool highlightLastConsumptionYear;
  final bool highlightPastOptimalConsumption;

  const _SlotCell({
    this.placement,
    required this.onTap,
    required this.cellarId,
    required this.onLongPressPlacement,
    required this.row,
    required this.col,
    required this.cellarTheme,
    required this.isEmptyCell,
    required this.isPreviewTarget,
    required this.previewIsValid,
    required this.selectedCount,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onDragPointerUpdate,
    required this.hideBottleVisual,
    required this.showDragGhost,
    required this.highlightLastConsumptionYear,
    required this.highlightPastOptimalConsumption,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<_SlotCell> createState() => _SlotCellState();
}

class _SlotCellState extends ConsumerState<_SlotCell>
    with SingleTickerProviderStateMixin {
  AnimationController? _blinkController;

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) {
      _startBlink();
    }
  }

  @override
  void didUpdateWidget(covariant _SlotCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _startBlink();
    } else if (!widget.isHighlighted && _blinkController != null) {
      _blinkController!.dispose();
      _blinkController = null;
    }
  }

  void _startBlink() {
    _blinkController?.dispose();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Render empty cells as invisible (no symbol or background)
    if (widget.isEmptyCell) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final wine = widget.placement?.wine;
    final hasWine = wine != null;
    final visibleWine = hasWine && !widget.hideBottleVisual;
    final wineColor = hasWine ? AppTheme.colorForWine(wine.color.name) : null;
    final consumptionHighlight = hasWine
      ? computeWineConsumptionHighlight(
        wine,
        highlightLastConsumptionYear: widget.highlightLastConsumptionYear,
        highlightPastOptimalWindow: widget.highlightPastOptimalConsumption,
        )
      : WineConsumptionHighlight.none;
    final hasConsumptionHighlight =
      consumptionHighlight != WineConsumptionHighlight.none;
    final consumptionColor = colorForConsumptionHighlight(consumptionHighlight);
    final isPremiumCave = widget.cellarTheme == VirtualCellarTheme.premiumCave;
    final isStoneCave = widget.cellarTheme == VirtualCellarTheme.stoneCave;
    final isGarageIndustrial = widget.cellarTheme == VirtualCellarTheme.garageIndustrial;
    final isImmersive = isPremiumCave || isStoneCave || isGarageIndustrial;

    final moveState = ref.watch(bottleMoveStateProvider(widget.cellarId));
    final isSelected =
        widget.placement != null && moveState.isSelected(widget.placement!.id);
    final isMovementMode = moveState.isMovementMode;
    final isDragModeEnabled = moveState.isDragModeEnabled;

    final slotStrokeColor = widget.isPreviewTarget
        ? (widget.previewIsValid
              ? theme.colorScheme.secondary
              : theme.colorScheme.error)
        : isSelected
        ? theme.colorScheme.primary
      : hasConsumptionHighlight
      ? consumptionColor
        : visibleWine
        ? wineColor!.withValues(alpha: 0.75)
        : theme.colorScheme.outlineVariant;

    final slotBackgroundColor = widget.isPreviewTarget
        ? (widget.previewIsValid
              ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.35)
              : theme.colorScheme.errorContainer.withValues(alpha: 0.4))
        : isImmersive
        ? Colors.transparent
        : Colors.transparent;

    final content = GestureDetector(
      onTap: () {
        if (hasWine && isMovementMode && !isDragModeEnabled) {
          // In movement mode, simple tap toggles selection.
          widget.onLongPressPlacement(widget.placement!.id);
          return;
        }
        if (!isMovementMode) {
          widget.onTap();
        }
      },
      // Keep this handler disabled once movement mode is active so
      // LongPressDraggable can win the gesture arena on touch devices.
      onLongPress: hasWine && !isMovementMode && widget.placement != null
          ? () {
              // First long-press enters movement mode and selects the bottle.
              widget.onLongPressPlacement(widget.placement!.id);
            }
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: slotBackgroundColor,
          borderRadius: BorderRadius.circular(
              isImmersive ? 0 : 10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isImmersive)
              // Immersive themes: no decorative wave or bar – bottles sit on
              // the painted shelf rails. Show only a subtle selection ring
              // or preview border.
              if (widget.isPreviewTarget || isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isPreviewTarget
                            ? (widget.previewIsValid
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.error)
                            : theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.shrink()
            else
              Positioned(
                bottom: 8,
                child: CustomPaint(
                  size: const Size(42, 18),
                  painter: _WaveSlotPainter(
                    color: slotStrokeColor,
                    strokeWidth: widget.isPreviewTarget || isSelected ? 2.6 : 2,
                  ),
                ),
              ),
            if (visibleWine)
              Positioned(
                top: isImmersive ? 2 : 6,
                child: isImmersive
                    ? CustomPaint(
                        size: const Size(28, 28),
                        painter: _BottleFacePainter(
                          wineColor: wineColor!,
                          isSelected: isSelected,
                        ),
                      )
                    : Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: wineColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.white,
                            width: isSelected ? 2 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
              )
            else if (!widget.showDragGhost)
              Positioned(
                top: isImmersive ? 6 : 8,
                child: isImmersive
                    ? CustomPaint(
                        size: const Size(24, 24),
                        painter: _EmptySlotDashedPainter(),
                      )
                    : Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.55,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (widget.showDragGhost)
              Positioned(
                top: 6,
                child: Icon(
                  Icons.local_bar,
                  size: 15,
                  color: widget.previewIsValid
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.error,
                ),
              ),
            if (isSelected)
              Positioned(
                right: 9,
                top: 4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (hasConsumptionHighlight && !widget.showDragGhost)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: consumptionColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            if (widget.isHighlighted && _blinkController != null)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _blinkController!,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (hasConsumptionHighlight
                                  ? consumptionColor
                                  : theme.colorScheme.tertiary)
                              .withValues(
                            alpha: _blinkController!.value * 0.9,
                          ),
                          width: 2.5,
                        ),
                        color: (hasConsumptionHighlight
                                ? consumptionColor
                                : theme.colorScheme.tertiary)
                            .withValues(
                          alpha: _blinkController!.value * 0.25,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );

    if (isMovementMode && hasWine && isSelected && widget.placement != null) {
      final dragData = _GroupDragData(anchorPlacementId: widget.placement!.id);
      final feedback = _DragSelectionFeedback(count: widget.selectedCount);
      final childWhenDragging = Opacity(opacity: 0.35, child: content);

      void onDragStarted() {
        widget.onDragStarted(widget.placement!.id);
      }

      void onDragUpdate(DragUpdateDetails details) {
        widget.onDragPointerUpdate(details.globalPosition);
      }

      final isDesktopPlatform =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS);

      if (isDesktopPlatform) {
        if (!isDragModeEnabled) {
          return MouseRegion(cursor: SystemMouseCursors.click, child: content);
        }

        return Draggable<_GroupDragData>(
          data: dragData,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          maxSimultaneousDrags: 1,
          onDragStarted: onDragStarted,
          onDragUpdate: onDragUpdate,
          onDragCompleted: widget.onDragEnded,
          onDragEnd: (_) => widget.onDragEnded(),
          feedback: feedback,
          childWhenDragging: childWhenDragging,
          child: MouseRegion(cursor: SystemMouseCursors.grab, child: content),
        );
      }

      if (!isDragModeEnabled) {
        return content;
      }

      return LongPressDraggable<_GroupDragData>(
        data: dragData,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        maxSimultaneousDrags: 1,
        onDragStarted: onDragStarted,
        onDragUpdate: onDragUpdate,
        onDragCompleted: widget.onDragEnded,
        onDragEnd: (_) => widget.onDragEnded(),
        onDraggableCanceled: (velocity, offset) => widget.onDragEnded(),
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: content,
      );
    }

    return content;
  }
}

class _WaveSlotPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _WaveSlotPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, 0, math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveSlotPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Draws a wine bottle seen end-on (circle with glass-depth) for premium cave.
class _BottleFacePainter extends CustomPainter {
  final Color wineColor;
  final bool isSelected;

  const _BottleFacePainter({required this.wineColor, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);
    final p = Paint();

    // Selection ring
    if (isSelected) {
      p.color = Colors.white.withValues(alpha: 0.6);
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), r, p);
      p.style = PaintingStyle.fill;
    }

    // Outer glow
    final glowR = r - 1;
    p.shader = RadialGradient(
      colors: [wineColor.withValues(alpha: 0.3), const Color(0x00000000)],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR + 4));
    canvas.drawCircle(Offset(cx, cy), glowR + 4, p);
    p.shader = null;

    // Body
    p.color = wineColor;
    canvas.drawCircle(Offset(cx, cy), glowR, p);

    // Glass-depth gradient
    final darker = Color.lerp(wineColor, Colors.black, 0.6)!;
    final lighter = Color.lerp(wineColor, Colors.white, 0.25)!;
    p.shader = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 1.0,
      colors: [
        lighter.withValues(alpha: 0.55),
        wineColor,
        darker.withValues(alpha: 0.6),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR));
    canvas.drawCircle(Offset(cx, cy), glowR, p);
    p.shader = null;

    // Collet ring
    p.color = lighter;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.8;
    canvas.drawCircle(Offset(cx, cy), glowR * 0.48, p);
    p.style = PaintingStyle.fill;

    // Neck disc
    p.color = darker;
    canvas.drawCircle(Offset(cx, cy), glowR * 0.38, p);

    // Cork
    p.shader = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: const [Color(0xFFE0B850), Color(0xFFA07828)],
    ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: glowR * 0.24));
    canvas.drawCircle(Offset(cx, cy), glowR * 0.24, p);
    p.shader = null;

    // Specular highlight
    p.shader = RadialGradient(
      center: const Alignment(-0.55, -0.55),
      colors: [Colors.white.withValues(alpha: 0.22), const Color(0x00000000)],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR));
    canvas.drawCircle(Offset(cx, cy), glowR, p);
    p.shader = null;

    // Glint
    p.color = Colors.white.withValues(alpha: 0.4);
    canvas.save();
    canvas.translate(cx - glowR * 0.35, cy - glowR * 0.35);
    canvas.rotate(-0.6);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: glowR * 0.3, height: glowR * 0.18), p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BottleFacePainter old) =>
      old.wineColor != wineColor || old.isSelected != isSelected;
}

/// Draws a dashed circle for empty slots in premium cave theme.
class _EmptySlotDashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (int i = 0; i < 8; i++) {
      final start = i * math.pi / 4;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r - 1),
        start,
        math.pi / 6,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmptySlotDashedPainter old) => false;
}

class _DragSelectionFeedback extends StatelessWidget {
  final int count;

  const _DragSelectionFeedback({required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 3),
              color: Colors.black26,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_bar, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              '$count bouteille${count > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = [
      ('Rouge', AppTheme.colorForWine('red')),
      ('Blanc', AppTheme.colorForWine('white')),
      ('Rose', AppTheme.colorForWine('rose')),
      ('Petil.', AppTheme.colorForWine('sparkling')),
      ('Liquor.', AppTheme.colorForWine('sweet')),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: colors
            .map(
              (pair) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: pair.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(pair.$1, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _WinePickerDialog extends StatefulWidget {
  final List<WineEntity> wines;
  final Map<int, int> availableCountByWineId;

  const _WinePickerDialog({
    required this.wines,
    required this.availableCountByWineId,
  });

  @override
  State<_WinePickerDialog> createState() => _WinePickerDialogState();
}

class _WinePickerDialogState extends State<_WinePickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.wines
        : widget.wines
              .where(
                (w) =>
                    w.displayName.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();

    return AlertDialog(
      title: const Text('Placer une ou plusieurs bouteilles'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final wine = filtered[index];
                  final colorValue = AppTheme.colorForWine(wine.color.name);
                  final available = widget.availableCountByWineId[wine.id] ?? 0;
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colorValue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(wine.displayName),
                    subtitle: Text('$available bouteille(s) disponible(s)'),
                    onTap: () => Navigator.of(context).pop(wine),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

class _InsertPositionTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _InsertPositionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(title),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      onTap: onTap,
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _PendingPlacement {
  final WineEntity wine;
  final int remaining;
  final int? returnToWineId;

  const _PendingPlacement({
    required this.wine,
    required this.remaining,
    this.returnToWineId,
  });
}
