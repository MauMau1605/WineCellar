import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWine();
  }

  Future<void> _loadWine() async {
    final result =
        await ref.read(getWineByIdUseCaseProvider).call(widget.wineId);
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
    final categories =
        await ref.read(foodCategoryRepositoryProvider).getAllCategories();

    final explicitPairings = categories
        .where((category) => wine.foodCategoryIds.contains(category.id))
        .toList();

    if (!mounted) return;
    setState(() {
      _wine = wine;
      _pairings = explicitPairings;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
            _buildSection(
              context,
              'Informations',
              [
                _buildInfoRow('Appellation', _displayValue(wine.appellation)),
                _buildInfoRow('Producteur', _displayValue(wine.producer)),
                _buildInfoRow('Région', _displayValue(wine.region)),
                _buildInfoRow('Pays', wine.country),
                _buildInfoRow(
                    'Couleur', '${wine.color.emoji} ${wine.color.label}'),
                _buildInfoRow('Millésime', _displayInt(wine.vintage)),
                _buildInfoRow('Cépages',
                    wine.grapeVarieties.isEmpty ? '' : wine.grapeVarieties.join(', ')),
              ],
            ),

            _buildSection(
              context,
              'Garde',
              [
                _buildInfoRow(
                  'À boire à partir de',
                  _displayInt(wine.drinkFromYear),
                  aiSuggested:
                      _isAiSuggestedGuardValue(wine, wine.drinkFromYear),
                ),
                _buildInfoRow(
                  'À boire jusqu\'à',
                  _displayInt(wine.drinkUntilYear),
                  aiSuggested:
                      _isAiSuggestedGuardValue(wine, wine.drinkUntilYear),
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
              ],
            ),

            _buildSection(
              context,
              'Cave',
              [
                _buildInfoRow('Quantité',
                    '${wine.quantity} bouteille${wine.quantity > 1 ? 's' : ''}'),
                _buildInfoRow(
                    'Prix d\'achat',
                    wine.purchasePrice != null
                        ? '${wine.purchasePrice!.toStringAsFixed(2)} €'
                        : ''),
                _buildInfoRow(
                  'Note',
                  wine.rating != null
                      ? '${'★' * wine.rating!}${'☆' * (5 - wine.rating!)}'
                      : '',
                ),
                _buildInfoRow('Localisation', _displayValue(wine.location)),
                _buildInfoRow(
                  'Position cave X',
                  _displayDouble(wine.cellarPositionX),
                ),
                _buildInfoRow(
                  'Position cave Y',
                  _displayDouble(wine.cellarPositionY),
                ),
              ],
            ),

            _buildSection(
              context,
              'Accords mets-vins',
              [
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
              ],
            ),

            _buildSection(
              context,
              'Notes de dégustation',
              [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _displayValue(wine.tastingNotes),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),

            _buildSection(
              context,
              'Description IA',
              [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _displayValue(wine.aiDescription),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
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
                color: AppTheme.colorForWine(wine.color.name)
                    .withValues(alpha: 0.2),
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
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
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
      BuildContext context, String title, List<Widget> children) {
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

  Widget _buildInfoRow(
    String label,
    String value, {
    bool aiSuggested = false,
  }) {
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

  String _displayDouble(double? value) {
    if (value == null) return '';
    return value.toStringAsFixed(2);
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
    final updated = await context.push<bool>(
      '/cellar/wine/${wine.id}/edit',
    );
    if (updated == true) {
      await _loadWine();
    }
  }

  Future<void> _updateQuantity(WineEntity wine, int newQty) async {
    if (wine.id == null) return;

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.message)),
            );
          }
        },
        (_) {
          if (mounted && action == 'delete') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vin supprimé')),
            );
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

  Future<void> _confirmDelete(WineEntity wine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce vin ?'),
        content:
            Text('Voulez-vous vraiment supprimer "${wine.displayName}" ?'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.message)),
            );
          }
        },
        (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vin supprimé')),
            );
            context.go('/cellar');
          }
        },
      );
    }
  }
}
