import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Detail screen for a single wine
class WineDetailScreen extends ConsumerStatefulWidget {
  final int wineId;

  const WineDetailScreen({super.key, required this.wineId});

  @override
  ConsumerState<WineDetailScreen> createState() => _WineDetailScreenState();
}

class _WineDetailScreenState extends ConsumerState<WineDetailScreen> {
  WineEntity? _wine;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWine();
  }

  Future<void> _loadWine() async {
    final wine =
        await ref.read(wineRepositoryProvider).getWineById(widget.wineId);
    if (mounted) {
      setState(() {
        _wine = wine;
        _loading = false;
      });
    }
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
                if (wine.appellation != null)
                  _buildInfoRow('Appellation', wine.appellation!),
                if (wine.producer != null)
                  _buildInfoRow('Producteur', wine.producer!),
                if (wine.region != null)
                  _buildInfoRow('Région', wine.region!),
                _buildInfoRow('Pays', wine.country),
                _buildInfoRow(
                    'Couleur', '${wine.color.emoji} ${wine.color.label}'),
                if (wine.vintage != null)
                  _buildInfoRow('Millésime', wine.vintage.toString()),
                if (wine.grapeVarieties.isNotEmpty)
                  _buildInfoRow(
                      'Cépages', wine.grapeVarieties.join(', ')),
              ],
            ),

            if (wine.drinkFromYear != null || wine.drinkUntilYear != null)
              _buildSection(
                context,
                'Garde',
                [
                  if (wine.drinkFromYear != null)
                    _buildInfoRow('À boire à partir de',
                        wine.drinkFromYear.toString()),
                  if (wine.drinkUntilYear != null)
                    _buildInfoRow(
                        'À boire jusqu\'à', wine.drinkUntilYear.toString()),
                  _buildInfoRow(
                    'Statut',
                    '${wine.maturity.emoji} ${wine.maturity.label}',
                  ),
                ],
              ),

            _buildSection(
              context,
              'Cave',
              [
                _buildInfoRow('Quantité',
                    '${wine.quantity} bouteille${wine.quantity > 1 ? 's' : ''}'),
                if (wine.purchasePrice != null)
                  _buildInfoRow('Prix d\'achat',
                      '${wine.purchasePrice!.toStringAsFixed(2)} €'),
                if (wine.rating != null)
                  _buildInfoRow(
                    'Note',
                    '${'★' * wine.rating!}${'☆' * (5 - wine.rating!)}',
                  ),
                if (wine.location != null && wine.location!.isNotEmpty)
                  _buildInfoRow('Localisation', wine.location!),
              ],
            ),

            if (wine.tastingNotes != null &&
                wine.tastingNotes!.isNotEmpty)
              _buildSection(
                context,
                'Notes de dégustation',
                [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      wine.tastingNotes!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),

            if (wine.aiDescription != null &&
                wine.aiDescription!.isNotEmpty)
              _buildSection(
                context,
                'Description IA',
                [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      wine.aiDescription!,
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

  Widget _buildInfoRow(String label, String value) {
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
            child: Text(value),
          ),
        ],
      ),
    );
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

      if (action == 'delete') {
        await ref.read(wineRepositoryProvider).deleteWine(wine.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vin supprimé')),
          );
          context.go('/cellar');
        }
        return;
      }
      // action == 'zero': continue to set quantity to 0
    }

    await ref
        .read(wineRepositoryProvider)
        .updateQuantity(wine.id!, newQty < 0 ? 0 : newQty);
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
      await ref.read(wineRepositoryProvider).deleteWine(wine.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vin supprimé')),
        );
        context.go('/cellar');
      }
    }
  }
}
