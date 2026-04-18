import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';

/// Detail screen for a single wine
class WineDetailScreen extends ConsumerStatefulWidget {
  final int wineId;

  const WineDetailScreen({super.key, required this.wineId});

  @override
  ConsumerState<WineDetailScreen> createState() => _WineDetailScreenState();
}

class _WineDetailScreenState extends ConsumerState<WineDetailScreen> {
  WineEntity? _wine;
  List<FoodCategoryEntity> _pairings = const [];
  List<BottlePlacementEntity> _placements = const [];
  Map<int, VirtualCellarEntity> _cellarsById = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWine();
  }

  Future<void> _loadWine() async {
    final result = await ref
        .read(getWineByIdUseCaseProvider)
        .call(widget.wineId);
    if (mounted) {
      result.fold(
        (failure) => setState(() {
          _wine = null;
          _pairings = const [];
          _loading = false;
        }),
        (wine) {
          if (wine == null) {
            setState(() {
              _wine = null;
              _pairings = const [];
              _loading = false;
            });
            return;
          }
          _loadWineWithPairings(wine);
        },
      );
    }
  }

  Future<void> _loadWineWithPairings(WineEntity wine) async {
    final categories = await ref
        .read(foodCategoryRepositoryProvider)
        .getAllCategories();

    final explicitPairings = categories
        .where((category) => wine.foodCategoryIds.contains(category.id))
        .toList();

    if (!mounted) return;
    setState(() {
      _wine = wine;
      _pairings = explicitPairings;
      _loading = false;
    });
    await _loadPlacements(wine.id);
  }

  Future<void> _loadPlacements(int? wineId) async {
    if (wineId == null) return;

    final placementsResult = await ref
        .read(getWinePlacementsUseCaseProvider)
        .call(wineId);
    final cellarsResult = await ref
        .read(virtualCellarRepositoryProvider)
        .getAll();

    if (!mounted) return;

    final placements = placementsResult.getOrElse((_) => const []);
    final cellars = cellarsResult.getOrElse((_) => const []);
    final byId = <int, VirtualCellarEntity>{
      for (final cellar in cellars)
        if (cellar.id != null) cellar.id!: cellar,
    };

    setState(() {
      _placements = placements;
      _cellarsById = byId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final wine = _wine;
    if (wine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vin non trouvé')),
        body: const Center(child: Text('Ce vin n\'existe pas.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(wine.displayName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cellar'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () => _navigateToEdit(wine),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () => _confirmDelete(wine),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with color bar and main info
            _buildHeader(context, wine),
            const SizedBox(height: 24),

            // Wine details sections
            _buildSection(context, 'Informations', [
              _buildInfoRow('Appellation', _displayValue(wine.appellation)),
              _buildInfoRow('Producteur', _displayValue(wine.producer)),
              _buildInfoRow('Région', _displayValue(wine.region)),
              _buildInfoRow('Pays', wine.country),
              _buildInfoRow(
                'Couleur',
                '${wine.color.emoji} ${wine.color.label}',
              ),
              _buildInfoRow('Millésime', _displayInt(wine.vintage)),
              _buildInfoRow(
                'Cépages',
                wine.grapeVarieties.isEmpty
                    ? ''
                    : wine.grapeVarieties.join(', '),
              ),
            ]),

            _buildSection(context, 'Garde', [
              _buildInfoRow(
                'À boire à partir de',
                _displayInt(wine.drinkFromYear),
                aiSuggested: _isAiSuggestedGuardValue(wine, wine.drinkFromYear),
              ),
              _buildInfoRow(
                'À boire jusqu\'à',
                _displayInt(wine.drinkUntilYear),
                aiSuggested: _isAiSuggestedGuardValue(
                  wine,
                  wine.drinkUntilYear,
                ),
              ),
              _buildInfoRow(
                'Statut',
                '${wine.maturity.emoji} ${wine.maturity.label}',
              ),
              if (_isAiGuardInfoPresent(wine))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '🤖 = information proposée par l\'IA',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ]),

            _buildCellarSection(context, wine),
            _buildSection(context, 'Accords mets-vins', [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _editFoodPairings(wine),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier les accords'),
                ),
              ),
              const SizedBox(height: 8),
              if (_pairings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Aucune proposition disponible.'),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _pairings
                        .map(
                          (pairing) => Chip(
                            label: Text(
                              '${pairing.icon ?? '🍽️'} ${pairing.name}${wine.aiSuggestedFoodPairings ? ' 🤖' : ''}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (wine.aiSuggestedFoodPairings && _pairings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '🤖 = accord proposé par l\'IA',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ]),

            _buildSection(context, 'Notes de dégustation', [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _displayValue(wine.tastingNotes),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ]),

            _buildSection(context, 'Description IA', [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _displayValue(wine.aiDescription),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
      // Quantity adjustment FAB
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'remove',
            onPressed: wine.quantity > 0
                ? () => _updateQuantity(wine, wine.quantity - 1)
                : null,
            child: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.extended(
            heroTag: 'qty',
            onPressed: null,
            label: Text(
              '${wine.quantity} bouteille${wine.quantity > 1 ? 's' : ''}',
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'add',
            onPressed: () => _updateQuantity(wine, wine.quantity + 1),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WineEntity wine) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Wine color circle
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.colorForWine(
                  wine.color.name,
                ).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.colorForWine(wine.color.name),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  wine.color.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wine.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (wine.vintage != null)
                    Text(
                      'Millésime ${wine.vintage}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
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

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool aiSuggested = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              aiSuggested && value.trim().isNotEmpty ? '$value 🤖' : value,
            ),
          ),
        ],
      ),
    );
  }

  String _displayValue(String? value) {
    if (value == null) return '';
    return value.trim();
  }

  String _displayInt(int? value) {
    return value?.toString() ?? '';
  }

  Widget _buildCellarSection(BuildContext context, WineEntity wine) {
    final theme = Theme.of(context);
    final placedCount = _placements.length;
    final unplacedCount = wine.quantity - placedCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cave',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const Divider(),
          _buildInfoRow(
            'Quantité',
            '${wine.quantity} bouteille${wine.quantity > 1 ? 's' : ''}',
          ),
          _buildInfoRow(
            'Prix d\'achat',
            wine.purchasePrice != null
                ? '${wine.purchasePrice!.toStringAsFixed(2)} €'
                : '',
          ),
          _buildInfoRow(
            'Note',
            wine.rating != null
                ? '${'★' * wine.rating!}${'☆' * (5 - wine.rating!)}'
                : '',
          ),
          _buildInfoRow('Localisation', _displayValue(wine.location)),
          _buildInfoRow(
            'Bouteilles placées',
            '$placedCount / ${wine.quantity}',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  placedCount == 0
                      ? 'Aucune bouteille placée en cellier.'
                      : 'Afficher les emplacements en cave',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: placedCount == 0
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
              if (placedCount > 0)
                TextButton.icon(
                  onPressed: () => _showPlacementsDialog(context, wine),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Voir'),
                ),
            ],
          ),
          if (unplacedCount > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showPlaceInCellarFlow(wine),
                icon: const Icon(Icons.grid_view_outlined),
                label: Text(
                  unplacedCount == wine.quantity
                      ? 'Placer en cave'
                      : 'Placer les $unplacedCount bouteille(s) non placée(s)',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showPlaceInCellarFlow(WineEntity wine) async {
    final cellarsResult = await ref
        .read(virtualCellarRepositoryProvider)
        .getAll();
    if (!mounted) return;

    final cellars = cellarsResult.getOrElse((_) => const []);
    if (cellars.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aucun cellier'),
          content: const Text(
            'Vous n\'avez pas encore créé de cave virtuelle.\n'
            'Rendez-vous dans l\'onglet Celliers pour en créer une.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final selectedCellar = await showDialog<VirtualCellarEntity>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choisir une cave'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cellars.length,
            itemBuilder: (context, index) {
              final cellar = cellars[index];
              return ListTile(
                leading: const Icon(Icons.grid_view_outlined),
                title: Text(cellar.name),
                subtitle: Text(
                  '${cellar.rows} × ${cellar.columns} — ${cellar.totalSlots} emplacements',
                ),
                onTap: () => Navigator.of(ctx).pop(cellar),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (!mounted || selectedCellar == null || selectedCellar.id == null) {
      return;
    }

    context.push('/cellars/${selectedCellar.id}?wineId=${wine.id}');
  }

  Future<void> _showPlacementsDialog(
    BuildContext context,
    WineEntity wine,
  ) async {
    if (_placements.isEmpty) return;

    final placementsByCellar = <int, List<BottlePlacementEntity>>{};
    for (final placement in _placements) {
      placementsByCellar
          .putIfAbsent(placement.cellarId, () => [])
          .add(placement);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Placements de ${wine.displayName}'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: placementsByCellar.entries.map((entry) {
                final cellarId = entry.key;
                final cellar = _cellarsById[cellarId];
                if (cellar == null) return const SizedBox.shrink();
                final cellarPlacements = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${cellar.name} - ${cellarPlacements.length} bouteille(s)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              context.push('/cellars/${cellar.id}?highlightWineId=${wine.id}');
                            },
                            child: const Text('Ouvrir le cellier'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildPlacementGridPreview(
                        context: context,
                        cellar: cellar,
                        placements: cellarPlacements,
                        wineColor: AppTheme.colorForWine(wine.color.name),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacementGridPreview({
    required BuildContext context,
    required VirtualCellarEntity cellar,
    required List<BottlePlacementEntity> placements,
    required Color wineColor,
  }) {
    final points = <(int, int)>{
      for (final p in placements) (p.positionY, p.positionX),
    };

    final gridContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(cellar.rows, (r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(cellar.columns, (c) {
            final occupied = points.contains((r, c));
            return Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: occupied
                    ? wineColor.withValues(alpha: 0.25)
                    : Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                border: Border.all(
                  color: occupied
                      ? wineColor
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      }),
    );

    return Container(
      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 500),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(6),
      child: Scrollbar(
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        child: Scrollbar(
          thumbVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: gridContent,
            ),
          ),
        ),
      ),
    );
  }

  bool _isAiSuggestedGuardValue(WineEntity wine, int? value) {
    if (value == null) return false;
    return (value == wine.drinkFromYear && wine.aiSuggestedDrinkFromYear) ||
        (value == wine.drinkUntilYear && wine.aiSuggestedDrinkUntilYear);
  }

  bool _isAiGuardInfoPresent(WineEntity wine) {
    return (wine.drinkFromYear != null && wine.aiSuggestedDrinkFromYear) ||
        (wine.drinkUntilYear != null && wine.aiSuggestedDrinkUntilYear);
  }

  Future<void> _navigateToEdit(WineEntity wine) async {
    final updated = await context.push<bool>('/cellar/wine/${wine.id}/edit');
    if (updated == true) {
      await _loadWine();
    }
  }

  Future<void> _editFoodPairings(WineEntity wine) async {
    final categories = await ref
        .read(foodCategoryRepositoryProvider)
        .getAllCategories();
    if (!mounted) return;

    final selected = wine.foodCategoryIds.toSet();
    final customCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier les accords mets-vins'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...categories.map(
                      (category) => CheckboxListTile(
                        value: selected.contains(category.id),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${category.icon ?? '🍽️'} ${category.name}',
                        ),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selected.add(category.id);
                            } else {
                              selected.remove(category.id);
                            }
                          });
                        },
                      ),
                    ),
                    const Divider(height: 20),
                    TextField(
                      controller: customCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Autre accord personnalisé',
                        hintText: 'Ex: Raclette',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final customName = customCtrl.text.trim();
    if (customName.isNotEmpty) {
      final created = await ref
          .read(foodCategoryRepositoryProvider)
          .createOrGetCategory(customName, icon: '🍽️');
      if (!mounted) return;
      selected.add(created.id);
    }

    final updatedWine = wine.copyWith(
      foodCategoryIds: selected.toList(),
      aiSuggestedFoodPairings: false,
      updatedAt: DateTime.now(),
    );

    final result = await ref.read(updateWineUseCaseProvider).call(updatedWine);
    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) async {
        await _loadWine();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accords mets-vins mis à jour.')),
        );
      },
    );
  }

  Future<void> _updateQuantity(WineEntity wine, int newQty) async {
    if (wine.id == null) return;

    if (newQty >= 0 && _placements.length > newQty && _placements.isNotEmpty) {
      final mustChoose = _placements.length == wine.quantity;
      if (mustChoose) {
        final toRemove = await _askWhichPlacedBottleWasRemoved(context);
        if (toRemove == null) return;
        await ref.read(removeBottlePlacementUseCaseProvider).call(toRemove.id);
      }
    }

    if (!mounted) return;

    if (newQty <= 0) {
      // Ask user if they want to delete when quantity reaches 0
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dernière bouteille !'),
          content: Text(
            'La quantité de "${wine.displayName}" va passer à 0.\n'
            'Que souhaitez-vous faire ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Annuler'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('zero'),
              child: const Text('Garder à 0'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('delete'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (!mounted || action == null || action == 'cancel') return;

      final useCase = ref.read(updateWineQuantityUseCaseProvider);
      final params = UpdateQuantityParams(
        wineId: wine.id!,
        newQuantity: newQty,
      );
      final zeroAction = action == 'delete'
          ? ZeroQuantityAction.delete
          : ZeroQuantityAction.keep;

      final result = await useCase.callWithAction(params, zeroAction);
      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          }
        },
        (_) {
          if (mounted && action == 'delete') {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Vin supprimé')));
            context.go('/cellar');
            return;
          }
        },
      );
      if (action == 'delete') return;
      // action == 'zero': continue to reload
    } else {
      final useCase = ref.read(updateWineQuantityUseCaseProvider);
      final params = UpdateQuantityParams(
        wineId: wine.id!,
        newQuantity: newQty,
      );
      await useCase(params);
    }
    await _loadWine();
  }

  Future<BottlePlacementEntity?> _askWhichPlacedBottleWasRemoved(
    BuildContext context,
  ) async {
    return showDialog<BottlePlacementEntity>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quelle bouteille a été retirée ?'),
        content: SizedBox(
          width: 500,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _placements.length,
            itemBuilder: (context, index) {
              final placement = _placements[index];
              final cellarName =
                  _cellarsById[placement.cellarId]?.name ??
                  'Cellier ${placement.cellarId}';
              return ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(cellarName),
                subtitle: Text(
                  'Rangée ${placement.positionY + 1}, Colonne ${placement.positionX + 1}',
                ),
                onTap: () => Navigator.of(dialogContext).pop(placement),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(WineEntity wine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce vin ?'),
        content: Text('Voulez-vous vraiment supprimer "${wine.displayName}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && wine.id != null) {
      final result = await ref.read(deleteWineUseCaseProvider).call(wine.id!);
      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          }
        },
        (_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Vin supprimé')));
            context.go('/cellar');
          }
        },
      );
    }
  }
}
