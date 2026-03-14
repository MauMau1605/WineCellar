import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';

/// Screen listing all virtual cellars. Accessible via /cellars.
class VirtualCellarListScreen extends ConsumerWidget {
  const VirtualCellarListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cellarsStream = ref
        .watch(getAllVirtualCellarsUseCaseProvider)
        .watch();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Celliers'),
      ),
      body: StreamBuilder<List<VirtualCellarEntity>>(
        stream: cellarsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }

          final cellars = snapshot.data ?? [];

          if (cellars.isEmpty) {
            return _EmptyState(onCreateTap: () => _showCreateDialog(context, ref));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cellars.length,
            itemBuilder: (context, index) {
              final cellar = cellars[index];
              return _CellarCard(
                cellar: cellar,
                onTap: () => context.push('/cellars/${cellar.id}'),
                onEdit: () => _showEditDialog(context, ref, cellar),
                onDelete: () => _confirmDelete(context, ref, cellar),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau cellier'),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    await _showCellarFormDialog(
      context: context,
      title: 'Nouveau cellier',
      confirmLabel: 'Créer',
      onConfirm: (name, rows, cols) async {
        final result = await ref
            .read(createVirtualCellarUseCaseProvider)
            .call(VirtualCellarEntity(name: name, rows: rows, columns: cols));
        result.fold(
          (failure) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(failure.message)),
              );
            }
          },
          (_) {},
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    VirtualCellarEntity cellar,
  ) async {
    await _showCellarFormDialog(
      context: context,
      title: 'Modifier le cellier',
      initialName: cellar.name,
      initialRows: cellar.rows,
      initialColumns: cellar.columns,
      confirmLabel: 'Enregistrer',
      onConfirm: (name, rows, cols) async {
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
          (_) {},
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    VirtualCellarEntity cellar,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le cellier ?'),
        content: Text(
          'Le cellier "${cellar.name}" sera supprimé. '
          'Les bouteilles qu\'il contient seront déplacées (non supprimées).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && cellar.id != null) {
      final result = await ref
          .read(deleteVirtualCellarUseCaseProvider)
          .call(cellar.id!);
      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.message)),
            );
          }
        },
        (_) {},
      );
    }
  }

  Future<void> _showCellarFormDialog({
    required BuildContext context,
    required String title,
    String? initialName,
    int? initialRows,
    int? initialColumns,
    required String confirmLabel,
    required Future<void> Function(String name, int rows, int cols) onConfirm,
  }) async {
    final nameCtrl = TextEditingController(text: initialName ?? '');
    var rows = initialRows ?? 5;
    var cols = initialColumns ?? 5;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du cellier',
                      hintText: 'Ex : Cave principale',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 20),
                  _DimensionStepper(
                    label: 'Rangées (hauteur)',
                    value: rows,
                    min: 1,
                    max: 20,
                    onChanged: (v) => setDialogState(() => rows = v),
                  ),
                  const SizedBox(height: 12),
                  _DimensionStepper(
                    label: 'Colonnes (largeur)',
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
                  Navigator.of(ctx).pop();
                  await onConfirm(name, rows, cols);
                },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _CellarCard extends StatelessWidget {
  final VirtualCellarEntity cellar;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CellarCard({
    required this.cellar,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.grid_view, color: theme.colorScheme.primary),
        ),
        title: Text(
          cellar.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${cellar.rows} rangée${cellar.rows > 1 ? 's' : ''} × '
          '${cellar.columns} colonne${cellar.columns > 1 ? 's' : ''} '
          '(${cellar.totalSlots} emplacements)',
          style: theme.textTheme.bodySmall,
        ),
        onTap: onTap,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Modifier')),
            PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_view_outlined,
              size: 80, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Aucun cellier créé',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Créez votre premier cellier virtuel pour placer\nvos bouteilles et les retrouver facilement.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add),
            label: const Text('Créer un cellier'),
          ),
        ],
      ),
    );
  }
}

class _DimensionStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _DimensionStepper({
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
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
