import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/expert_cellar_editor_screen.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/virtual_cellar_theme_selector.dart';

/// Screen listing all virtual cellars. Accessible via /cellars.
class VirtualCellarListScreen extends ConsumerWidget {
  const VirtualCellarListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cellarsStream = ref
        .watch(getAllVirtualCellarsUseCaseProvider)
        .watch();

    return Scaffold(
      appBar: AppBar(title: const Text('Mes Celliers')),
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
            return _EmptyState(
              onCreateTap: () => _showCreateDialog(context, ref),
            );
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
                onEditExpert: () => _openExpertEditor(
                  context,
                  name: cellar.name,
                  rows: cellar.rows,
                  cols: cellar.columns,
                  initialTheme: cellar.theme,
                  sourceCellar: cellar,
                ),
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
    final existingCellars = await _getExistingCellarNames(ref);
    if (!context.mounted) return;
    await _showCellarFormDialog(
      context: context,
      title: 'Nouveau cellier',
      confirmLabel: 'Créer',
      enableModeSelection: true,
      existingCellarNames: existingCellars,
      onConfirm: (name, rows, cols, theme) async {
        final result = await ref
            .read(createVirtualCellarUseCaseProvider)
            .call(
              VirtualCellarEntity(
                name: name,
                rows: rows,
                columns: cols,
                theme: theme,
              ),
            );
        result.fold((failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          }
        }, (_) {});
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    VirtualCellarEntity cellar,
  ) async {
    final oldName = cellar.name;
    await _showCellarFormDialog(
      context: context,
      title: 'Modifier le cellier',
      initialName: cellar.name,
      initialRows: cellar.rows,
      initialColumns: cellar.columns,
      initialTheme: cellar.theme,
      confirmLabel: 'Enregistrer',
      onConfirm: (name, rows, cols, theme) async {
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
        result.fold((failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          }
        }, (_) async {
          // If name changed, ask about updating wine locations
          if (name != oldName && context.mounted) {
            await _askUpdateWineLocations(
              context,
              ref,
              oldName: oldName,
              newName: name,
            );
          }
        });
      },
    );
  }

  Future<void> _askUpdateWineLocations(
    BuildContext context,
    WidgetRef ref, {
    required String oldName,
    required String newName,
  }) async {
    final wineRepo = ref.read(wineRepositoryProvider);
    final allWines = await wineRepo.getAllWines();
    final affectedWines = allWines
        .where((w) => w.location == oldName)
        .toList();

    if (affectedWines.isEmpty || !context.mounted) return;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mettre à jour la localisation ?'),
        content: Text(
          '${affectedWines.length} bouteille(s) ont la localisation '
          '"$oldName".\n\n'
          'Souhaitez-vous mettre à jour leur localisation en "$newName" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Non, garder l\'ancienne'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Oui, mettre à jour'),
          ),
        ],
      ),
    );

    if (shouldUpdate != true) return;

    final updateUseCase = ref.read(updateWineUseCaseProvider);
    for (final wine in affectedWines) {
      await updateUseCase(wine.copyWith(location: newName));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${affectedWines.length} bouteille(s) mise(s) à jour.',
          ),
        ),
      );
    }
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
      result.fold((failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      }, (_) {});
    }
  }

  Future<List<String>> _getExistingCellarNames(WidgetRef ref) async {
    final result = await ref.read(virtualCellarRepositoryProvider).getAll();
    return result
        .getOrElse((_) => const [])
        .map((c) => c.name)
        .toList();
  }

  static String _generateDefaultCellarName(List<String> existingNames) {
    final lowerNames = existingNames.map((n) => n.toLowerCase()).toSet();
    for (var i = 1;; i++) {
      final candidate = 'Cave $i';
      if (!lowerNames.contains(candidate.toLowerCase())) return candidate;
    }
  }

  Future<void> _showCellarFormDialog({
    required BuildContext context,
    required String title,
    String? initialName,
    int? initialRows,
    int? initialColumns,
    VirtualCellarTheme initialTheme = VirtualCellarTheme.classic,
    required String confirmLabel,
    bool enableModeSelection = false,
    List<String> existingCellarNames = const [],
    required Future<void> Function(
      String name,
      int rows,
      int cols,
      VirtualCellarTheme theme,
    )
    onConfirm,
  }) async {
    final nameCtrl = TextEditingController(text: initialName ?? '');
    var rows = initialRows ?? 5;
    var cols = initialColumns ?? 5;
    var mode = _CellarCreationMode.simplified;
    var theme = initialTheme;

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
                  if (enableModeSelection) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mode de creation',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CreationModeSelector(
                      selectedMode: mode,
                      onModeChanged: (newMode) {
                        setDialogState(() {
                          mode = newMode;
                          if (mode == _CellarCreationMode.simplified) {
                            rows = rows.clamp(1, 12);
                            cols = cols.clamp(1, 16);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nom du cellier',
                      hintText: existingCellarNames.isEmpty
                          ? 'Ex : Cave principale'
                          : 'Par défaut : ${_generateDefaultCellarName(existingCellarNames)}',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  VirtualCellarThemeSelector(
                    selectedTheme: theme,
                    onChanged: (newTheme) {
                      setDialogState(() => theme = newTheme);
                    },
                  ),
                  const SizedBox(height: 20),
                  if (mode == _CellarCreationMode.simplified) ...[
                    _DimensionStepper(
                      label: 'Rangées (hauteur)',
                      value: rows,
                      min: 1,
                      max: 12,
                      onChanged: (v) => setDialogState(() => rows = v),
                    ),
                    const SizedBox(height: 12),
                    _DimensionStepper(
                      label: 'Colonnes (largeur)',
                      value: cols,
                      min: 1,
                      max: 16,
                      onChanged: (v) => setDialogState(() => cols = v),
                    ),
                    const SizedBox(height: 14),
                    _SimpleWavePreview(rows: rows, cols: cols),
                  ] else ...[
                    _DimensionStepper(
                      label: 'Rangées (hauteur)',
                      value: rows,
                      min: 1,
                      max: 30,
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
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Le mode expert permet de marquer des zones vides et modifier finement la grille.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
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
                  var name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    name = _generateDefaultCellarName(existingCellarNames);
                  }

                  if (mode == _CellarCreationMode.advanced) {
                    Navigator.of(ctx).pop();
                    await _openExpertEditor(
                      context,
                      name: name,
                      rows: rows,
                      cols: cols,
                      initialTheme: theme,
                    );
                    return;
                  }

                  Navigator.of(ctx).pop();
                  await onConfirm(name, rows, cols, theme);
                },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openExpertEditor(
    BuildContext context, {
    required String name,
    required int rows,
    required int cols,
    required VirtualCellarTheme initialTheme,
    VirtualCellarEntity? sourceCellar,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => ExpertCellarEditorScreen(
          initialName: name,
          initialRows: rows,
          initialColumns: cols,
          initialTheme: initialTheme,
          sourceCellar: sourceCellar,
        ),
      ),
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _CellarCard extends StatelessWidget {
  final VirtualCellarEntity cellar;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onEditExpert;
  final VoidCallback onDelete;

  const _CellarCard({
    required this.cellar,
    required this.onTap,
    required this.onEdit,
    required this.onEditExpert,
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
          child: Icon(
            iconForVirtualCellarTheme(cellar.theme),
            color: theme.colorScheme.primary,
          ),
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
          '(${cellar.totalSlots} emplacements) • ${cellar.theme.label}',
          style: theme.textTheme.bodySmall,
        ),
        onTap: onTap,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'expert') onEditExpert();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Modifier')),
            PopupMenuItem(
              value: 'expert',
              child: Text('Ouvrir en mode expert'),
            ),
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
          Icon(
            Icons.grid_view_outlined,
            size: 80,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('Aucun cellier créé', style: theme.textTheme.titleMedium),
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

enum _CellarCreationMode { simplified, advanced }

class _CreationModeSelector extends StatelessWidget {
  final _CellarCreationMode selectedMode;
  final ValueChanged<_CellarCreationMode> onModeChanged;

  const _CreationModeSelector({
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            title: 'Simplifie',
            subtitle: 'Format vague',
            icon: Icons.waves,
            selected: selectedMode == _CellarCreationMode.simplified,
            enabled: true,
            onTap: () => onModeChanged(_CellarCreationMode.simplified),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeChip(
            title: 'Avance',
            subtitle: 'Grille libre',
            icon: Icons.tune,
            selected: selectedMode == _CellarCreationMode.advanced,
            enabled: true,
            onTap: () => onModeChanged(_CellarCreationMode.advanced),
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeChip({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 8),
              Text(title, style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleWavePreview extends StatelessWidget {
  final int rows;
  final int cols;

  const _SimpleWavePreview({required this.rows, required this.cols});

  @override
  Widget build(BuildContext context) {
    final previewRows = rows.clamp(1, 5);
    final previewCols = cols.clamp(1, 8);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apercu du format simplifie',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          ...List.generate(previewRows, (_) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(previewCols, (_) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.water_drop_outlined,
                      size: 12,
                      color: theme.colorScheme.outline,
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}
