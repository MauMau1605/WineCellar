import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';

/// Landing screen for developer tools.
/// Shows all available developer-only features.
class DeveloperScreen extends ConsumerWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Outils développeur')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            content: const Text(
              'Mode développeur actif — ces fonctionnalités sont réservées '
              'aux tests et ne doivent pas être utilisées en production.',
            ),
            leading: const Icon(Icons.warning_amber, color: Colors.orange),
            actions: const [SizedBox.shrink()],
          ),
          const SizedBox(height: 20),
          Text(
            'Outils disponibles',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: const Text('Réévaluation IA des vins'),
              subtitle: const Text(
                'Mettre à jour fenêtres de dégustation et accords mets-vins '
                'pour une sélection de vins en cave.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/developer/reevaluate'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: theme.colorScheme.onErrorContainer,
              ),
              title: Text(
                'Supprimer tous les vins',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              subtitle: Text(
                'Vider complètement la cave pour repartir sur une base '
                'de données propre.',
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer.withAlpha(180),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onErrorContainer,
              ),
              onTap: () => _confirmDeleteAllWines(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAllWines(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final wineCount = await ref.read(wineRepositoryProvider).getWineCount();

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text('Supprimer tous les vins ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cette action supprimera définitivement les $wineCount vin(s) '
              'de la cave, ainsi que tous les placements de bouteilles associés.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette opération est irréversible.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final deleteUseCase = ref.read(deleteAllWinesUseCaseProvider);
    final result = await deleteUseCase(const NoParams());

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${failure.message}')),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$wineCount vin(s) supprimé(s) avec succès.',
            ),
          ),
        );
      },
    );
  }
}
