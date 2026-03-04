import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Detail screen for a single wine
class WineDetailScreen extends ConsumerWidget {
  final int wineId;

  const WineDetailScreen({super.key, required this.wineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return FutureBuilder<WineEntity?>(
      future: ref.read(wineRepositoryProvider).getWineById(wineId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final wine = snapshot.data;
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
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref, wine),
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
                    _buildInfoRow('Couleur', '${wine.color.emoji} ${wine.color.label}'),
                    if (wine.vintage != null)
                      _buildInfoRow('Millésime', wine.vintage.toString()),
                    if (wine.grapeVarieties.isNotEmpty)
                      _buildInfoRow('Cépages', wine.grapeVarieties.join(', ')),
                  ],
                ),

                if (wine.drinkFromYear != null || wine.drinkUntilYear != null)
                  _buildSection(
                    context,
                    'Garde',
                    [
                      if (wine.drinkFromYear != null)
                        _buildInfoRow(
                            'À boire à partir de', wine.drinkFromYear.toString()),
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
                      _buildInfoRow(
                          'Prix d\'achat', '${wine.purchasePrice!.toStringAsFixed(2)} €'),
                    if (wine.rating != null)
                      _buildInfoRow(
                        'Note',
                        '${'★' * wine.rating!}${'☆' * (5 - wine.rating!)}',
                      ),
                  ],
                ),

                if (wine.tastingNotes != null && wine.tastingNotes!.isNotEmpty)
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

                if (wine.aiDescription != null && wine.aiDescription!.isNotEmpty)
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
                    ? () => _updateQuantity(ref, wine, wine.quantity - 1)
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
                onPressed: () =>
                    _updateQuantity(ref, wine, wine.quantity + 1),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        );
      },
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
                color: AppTheme.colorForWine(wine.color.name).withValues(alpha: 0.2),
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
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

  Future<void> _updateQuantity(
      WidgetRef ref, WineEntity wine, int newQty) async {
    if (wine.id != null) {
      await ref.read(wineRepositoryProvider).updateQuantity(wine.id!, newQty);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, WineEntity wine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce vin ?'),
        content:
            Text('Voulez-vous vraiment supprimer "${wine.displayName}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && wine.id != null) {
      await ref.read(wineRepositoryProvider).deleteWine(wine.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vin supprimé')),
        );
        context.go('/cellar');
      }
    }
  }
}
