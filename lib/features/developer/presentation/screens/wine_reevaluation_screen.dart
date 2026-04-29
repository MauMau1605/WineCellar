import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/developer/domain/entities/reevaluation_options.dart';
import 'package:wine_cellar/features/developer/presentation/helpers/wine_reevaluation_helper.dart';
import 'package:wine_cellar/features/developer/presentation/providers/reevaluation_provider.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Screen for selecting wines and options before launching a re-evaluation.
class WineReevaluationScreen extends ConsumerStatefulWidget {
  const WineReevaluationScreen({super.key});

  @override
  ConsumerState<WineReevaluationScreen> createState() =>
      _WineReevaluationScreenState();
}

class _WineReevaluationScreenState
    extends ConsumerState<WineReevaluationScreen> {
  final Set<ReevaluationType> _selectedTypes = {
    ReevaluationType.drinkingWindow,
    ReevaluationType.foodPairings,
  };

  final Set<int> _selectedWineIds = {};
  WineColor? _colorFilter;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winesAsync = ref.watch(
      _filteredWinesProvider(_colorFilter),
    );
    final reevalState = ref.watch(reevaluationNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Réévaluation IA')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // ---- Options section ----
              Text(
                'Que réévaluer ?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: WineReevaluationHelper.options
                      .map(
                        (option) => CheckboxListTile(
                          title: Text(option.title),
                          subtitle: Text(option.subtitle),
                          value: _selectedTypes.contains(option.type),
                          onChanged: (value) =>
                              _toggleType(option.type, value ?? false),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 24),

              // ---- Wine selection section ----
              Text(
                'Sélection des vins',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un vin…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 8),

              // Color filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tous',
                      selected: _colorFilter == null,
                      onTap: () => setState(() => _colorFilter = null),
                    ),
                    const SizedBox(width: 8),
                    ...WineColor.values.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: c.label,
                          selected: _colorFilter == c,
                          onTap: () =>
                              setState(() => _colorFilter = c),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Select all / none bar
              winesAsync.when(
                data: (allWines) {
                  final visible = _applySearch(allWines);
                  final selectionState =
                      WineReevaluationHelper.buildVisibleSelectionState(
                    visible,
                    _selectedWineIds,
                  );

                  return Row(
                    children: [
                      Text(
                        '${selectionState.selectedCount} vin(s) sélectionné(s)',
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          if (selectionState.allSelected) {
                            _selectedWineIds
                                .removeAll(selectionState.visibleIds);
                          } else {
                            _selectedWineIds
                                .addAll(selectionState.visibleIds);
                          }
                        }),
                        child: Text(
                          selectionState.allSelected
                              ? 'Tout désélectionner'
                              : 'Tout sélectionner',
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 4),

              // Wine list
              winesAsync.when(
                data: (allWines) {
                  final wines = _applySearch(allWines);
                  if (wines.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('Aucun vin trouvé.')),
                    );
                  }
                  return Column(
                    children: wines.map((wine) {
                      final id = wine.id!;
                      return CheckboxListTile(
                        key: ValueKey(id),
                        value: _selectedWineIds.contains(id),
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            _selectedWineIds.add(id);
                          } else {
                            _selectedWineIds.remove(id);
                          }
                        }),
                        title: Text(wine.displayName),
                        subtitle: Text(
                          [
                            if (wine.producer != null) wine.producer,
                            if (wine.appellation != null) wine.appellation,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondary: _WineColorDot(color: wine.color),
                        dense: true,
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erreur : $e'),
              ),
            ],
          ),

          // ---- Bottom action bar ----
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surface.withValues(alpha: 0.97),
              child: SafeArea(
                child: FilledButton.icon(
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(
                    WineReevaluationHelper.launchButtonLabel(
                      _selectedWineIds.length,
                    ),
                  ),
                  onPressed: _canLaunch(reevalState)
                      ? _launchReevaluation
                      : null,
                ),
              ),
            ),
          ),

          // ---- Processing overlay ----
          if (reevalState is ReevaluationProcessing)
            _ProcessingOverlay(
              state: reevalState,
              onCancel: ref.read(reevaluationNotifierProvider.notifier).cancel,
            ),
        ],
      ),
    );
  }

  bool _canLaunch(ReevaluationState state) =>
      WineReevaluationHelper.canLaunch(_selectedWineIds, _selectedTypes, state);

  List<WineEntity> _applySearch(List<WineEntity> wines) {
    return WineReevaluationHelper.applySearch(wines, _searchQuery);
  }

  void _toggleType(ReevaluationType type, bool value) {
    setState(() {
      if (value) {
        _selectedTypes.add(type);
      } else {
        _selectedTypes.remove(type);
      }
    });
  }

  Future<void> _launchReevaluation() async {
    final wines = await ref.read(_allWinesProvider.future);
    final selected = wines
        .where((w) => w.id != null && _selectedWineIds.contains(w.id))
        .toList();

    if (selected.isEmpty) return;

    final notifier = ref.read(reevaluationNotifierProvider.notifier);
    await notifier.startReevaluation(
      selected,
      ReevaluationOptions(types: Set.from(_selectedTypes)),
    );

    if (!mounted) return;

    final currentState = ref.read(reevaluationNotifierProvider);
    if (currentState is ReevaluationPreview) {
      context.push('/developer/reevaluate/preview');
    } else if (currentState is ReevaluationError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentState.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ============================================================
//  Providers (local to this screen)
// ============================================================

final _allWinesProvider = FutureProvider<List<WineEntity>>((ref) {
  return ref.watch(wineRepositoryProvider).getAllWines();
});

final _filteredWinesProvider =
    FutureProvider.family<List<WineEntity>, WineColor?>(
  (ref, colorFilter) async {
    final all = await ref.watch(_allWinesProvider.future);
    if (colorFilter == null) return all;
    return all.where((w) => w.color == colorFilter).toList();
  },
);

// ============================================================
//  Widgets
// ============================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _WineColorDot extends StatelessWidget {
  final WineColor color;

  const _WineColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: _dotColor(color),
    );
  }

  Color _dotColor(WineColor c) => switch (c) {
        _ => WineReevaluationHelper.wineColorDotColor(c),
      };
}

class _ProcessingOverlay extends StatelessWidget {
  final ReevaluationProcessing state;
  final VoidCallback onCancel;

  const _ProcessingOverlay({required this.state, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Réévaluation en cours…',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  WineReevaluationHelper.processingStatusText(state),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: WineReevaluationHelper.processingProgressValue(state),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Annuler'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
