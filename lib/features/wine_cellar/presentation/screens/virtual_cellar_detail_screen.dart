import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/place_wine_in_cellar.dart';

class VirtualCellarDetailScreen extends ConsumerStatefulWidget {
  final int cellarId;

  const VirtualCellarDetailScreen({super.key, required this.cellarId});

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

  @override
  void initState() {
    super.initState();
    _loadCellar();
  }

  Future<void> _loadCellar() async {
    final result = await ref
        .read(virtualCellarRepositoryProvider)
        .getById(widget.cellarId);
    result.fold(
      (_) => setState(() => _loading = false),
      (cellar) => setState(() {
        _cellar = cellar;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier le cellier',
            onPressed: () => _showEditDialog(context, cellar),
          ),
        ],
      ),
      body: StreamBuilder<List<BottlePlacementEntity>>(
        stream: ref
            .watch(virtualCellarRepositoryProvider)
            .watchPlacementsByCellarId(widget.cellarId),
        builder: (context, snapshot) {
          final placements = snapshot.data ?? const [];
          _placedBottles = placements;
          return _CellarGridView(
            cellar: cellar,
            placements: placements,
            pendingPlacement: _pendingPlacement,
            onSlotTap: (row, col) =>
                _onSlotTap(context, cellar, placements, row, col),
          );
        },
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
    final placementAtSlot = placements
        .where((p) => p.positionX == col && p.positionY == row)
        .firstOrNull;

    if (_pendingPlacement != null) {
      if (placementAtSlot != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emplacement occupé.')),
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
              child: Text(
                wine.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Cellier', cellarName),
            _infoRow('Position',
                'Rangée ${placement.positionY + 1}, Colonne ${placement.positionX + 1}'),
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
        final countResult =
            await ref.read(virtualCellarRepositoryProvider).getPlacedBottleCount(id);
        return (wine, countResult.getOrElse((_) => 0));
      }),
    );

    final availableCountByWineId = <int, int>{};
    final availableWines = <WineEntity>[];
    for (final pair in countPairs) {
      final wine = pair.$1;
      final placedCount = pair.$2;
      final id = wine.id;
      if (id == null) continue;
      final unplaced = wine.quantity - placedCount;
      if (unplaced > 0) {
        availableCountByWineId[id] = unplaced;
        availableWines.add(wine);
      }
    }

    availableWines.sort((a, b) => a.displayName.compareTo(b.displayName));

    if (!context.mounted) return;
    if (availableWines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune bouteille disponible à placer.'),
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
    final selectedCount = maxCount > 1
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
          title: Text('Combien placer pour ${wine.displayName} ?'),
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
              child: const Text('Placer'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emplacement occupé.')),
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
        _pendingPlacement = _PendingPlacement(
          wine: wine,
          remaining: remaining,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$remaining bouteille(s) restante(s). Choisissez les emplacements manuellement.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Placement terminé.')),
      );
      return;
    }

    setState(() {
      _pendingPlacement = _PendingPlacement(
        wine: pending.wine,
        remaining: left,
      );
    });
  }

  Future<bool> _placeSingleBottle(
    BuildContext context, {
    required int wineId,
    required int row,
    required int col,
  }) async {
    final result = await ref.read(placeWineInCellarUseCaseProvider).call(
          PlaceWineParams(
            wineId: wineId,
            cellarId: widget.cellarId,
            positionX: col,
            positionY: row,
          ),
        );

    return result.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
        return false;
      },
      (_) => true,
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    VirtualCellarEntity cellar,
  ) async {
    final nameCtrl = TextEditingController(text: cellar.name);
    var rows = cellar.rows;
    var cols = cellar.columns;

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

                final result = await ref
                    .read(updateVirtualCellarUseCaseProvider)
                    .call(cellar.copyWith(name: name, rows: rows, columns: cols));
                result.fold(
                  (failure) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(failure.message)),
                      );
                    }
                  },
                  (_) => setState(
                    () => _cellar = cellar.copyWith(
                      name: name,
                      rows: rows,
                      columns: cols,
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

class _CellarGridView extends StatelessWidget {
  final VirtualCellarEntity cellar;
  final List<BottlePlacementEntity> placements;
  final _PendingPlacement? pendingPlacement;
  final void Function(int row, int col) onSlotTap;

  const _CellarGridView({
    required this.cellar,
    required this.placements,
    required this.pendingPlacement,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final lookup = <(int, int), BottlePlacementEntity>{};
    for (final p in placements) {
      if (p.positionX < cellar.columns && p.positionY < cellar.rows) {
        lookup[(p.positionY, p.positionX)] = p;
      }
    }

    final occupied = lookup.length;
    final total = cellar.totalSlots;

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
                    'Placement manuel en cours: ${pendingPlacement!.remaining} bouteille(s) de ${pendingPlacement!.wine.displayName}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const SizedBox(width: 28),
              ...List.generate(cellar.columns, (col) {
                return Expanded(
                  child: Center(
                    child: Text(
                      '${col + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            child: Column(
              children: List.generate(cellar.rows, (row) {
                return Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: Text(
                          '${row + 1}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ),
                    ),
                    ...List.generate(cellar.columns, (col) {
                      final placement = lookup[(row, col)];
                      return Expanded(
                        child: _SlotCell(
                          placement: placement,
                          onTap: () => onSlotTap(row, col),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ),
          ),
        ),
        _Legend(),
      ],
    );
  }
}

class _SlotCell extends StatelessWidget {
  final BottlePlacementEntity? placement;
  final VoidCallback onTap;

  const _SlotCell({this.placement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wine = placement?.wine;
    final hasWine = wine != null;
    final wineColor = hasWine ? AppTheme.colorForWine(wine.color.name) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        height: 52,
        decoration: BoxDecoration(
          color: hasWine
              ? wineColor!.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(
            color: hasWine
                ? wineColor!.withValues(alpha: 0.6)
                : theme.colorScheme.outlineVariant,
            width: hasWine ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: hasWine
            ? Padding(
                padding: const EdgeInsets.all(3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: wineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wine.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 8,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: theme.colorScheme.outlineVariant,
                ),
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
                  Text(pair.$1,
                      style: Theme.of(context).textTheme.labelSmall),
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
            .where((w) =>
                w.displayName.toLowerCase().contains(_query.toLowerCase()))
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

  const _PendingPlacement({
    required this.wine,
    required this.remaining,
  });
}
