import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/features/developer/domain/entities/wine_reevaluation_change.dart';
import 'package:wine_cellar/features/developer/presentation/providers/reevaluation_provider.dart';

/// Displays the AI re-evaluation results before applying them.
///
/// Each wine shows what changed (before → after).
/// The user can toggle which wines' changes to apply, then confirm.
class ReevaluationPreviewScreen extends ConsumerWidget {
  const ReevaluationPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reevaluationNotifierProvider);
    final notifier = ref.read(reevaluationNotifierProvider.notifier);
    final theme = Theme.of(context);

    if (state is ReevaluationApplying) {
      return Scaffold(
        appBar: AppBar(title: const Text('Application des changements')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state is ReevaluationApplied) {
      return _AppliedScreen(state: state);
    }

    if (state is! ReevaluationPreview) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prévisualisation')),
        body: const Center(
          child: Text('Aucun résultat de réévaluation disponible.'),
        ),
      );
    }

    final changes = state.changes;
    final withChanges = changes.where((c) => c.hasAnyChange).toList();
    final unchanged = changes.where((c) => c.unchanged).toList();
    final errors = changes.where((c) => c.hasError).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifications proposées'),
        actions: [
          if (withChanges.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'all') notifier.selectAll();
                if (v == 'none') notifier.deselectAll();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('Tout sélectionner'),
                ),
                const PopupMenuItem(
                  value: 'none',
                  child: Text('Tout désélectionner'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.secondaryContainer,
            child: Text(
              _buildSummary(state),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),

          // Wine list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                if (withChanges.isNotEmpty) ...[
                  const _SectionHeader('Modifications détectées'),
                  ...withChanges.map(
                    (c) => _WineChangeTile(
                      change: c,
                      selected: state.selectedWineIds
                          .contains(c.originalWine.id),
                      onToggle: c.originalWine.id != null
                          ? () => notifier.toggleWineSelection(
                                c.originalWine.id!,
                              )
                          : null,
                    ),
                  ),
                ],
                if (unchanged.isNotEmpty) ...[
                  const _SectionHeader('Déjà à jour'),
                  ...unchanged.map(
                    (c) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline,
                          color: Colors.green),
                      title: Text(c.originalWine.displayName),
                      subtitle: const Text('Aucune modification nécessaire'),
                    ),
                  ),
                ],
                if (errors.isNotEmpty) ...[
                  const _SectionHeader('Erreurs'),
                  ...errors.map(
                    (c) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: Text(c.originalWine.displayName),
                      subtitle: Text(c.errorMessage ?? 'Erreur inconnue'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomActionBar(
        selectedCount: state.selectedCount,
        onApply: state.selectedCount > 0 ? notifier.applySelected : null,
        onCancel: () {
          notifier.reset();
          context.pop();
        },
      ),
    );
  }

  String _buildSummary(ReevaluationPreview state) {
    final parts = <String>[];
    if (state.changesCount > 0) {
      parts.add('${state.changesCount} vin(s) à mettre à jour');
    }
    if (state.unchangedCount > 0) {
      parts.add('${state.unchangedCount} déjà à jour');
    }
    if (state.errorCount > 0) {
      parts.add('${state.errorCount} erreur(s)');
    }
    if (parts.isEmpty) return 'Aucun résultat.';
    return parts.join('  ·  ');
  }
}

// ============================================================
//  Applied screen
// ============================================================

class _AppliedScreen extends StatelessWidget {
  final ReevaluationApplied state;

  const _AppliedScreen({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réévaluation terminée')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                '${state.appliedCount} vin(s) mis à jour',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (state.unchangedCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${state.unchangedCount} vin(s) déjà à jour',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (state.errorCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${state.errorCount} erreur(s) ignorée(s)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange,
                      ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context
                  ..go('/developer/reevaluate')
                  ..pop(),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  Supporting widgets
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _WineChangeTile extends StatelessWidget {
  final WineReevaluationChange change;
  final bool selected;
  final VoidCallback? onToggle;

  const _WineChangeTile({
    required this.change,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      key: ValueKey(change.originalWine.id),
      value: selected,
      onChanged: onToggle != null ? (_) => onToggle!() : null,
      title: Text(
        change.originalWine.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (change.hasDrinkingWindowChange)
            _ChangeLine(
              label: 'Fenêtre',
              oldValue: _fmtWindow(
                change.originalWine.drinkFromYear,
                change.originalWine.drinkUntilYear,
              ),
              newValue: _fmtWindow(
                change.newDrinkFromYear ?? change.originalWine.drinkFromYear,
                change.newDrinkUntilYear ?? change.originalWine.drinkUntilYear,
              ),
              theme: theme,
            ),
          if (change.hasFoodPairingsChange)
            _ChangeLine(
              label: 'Accords',
              oldValue: change.originalWine.foodCategoryIds.isEmpty
                  ? '(aucun)'
                  : '${change.originalWine.foodCategoryIds.length} catégorie(s)',
              newValue: change.newFoodPairingNames?.join(', ') ?? '—',
              theme: theme,
            ),
        ],
      ),
      isThreeLine: change.hasDrinkingWindowChange && change.hasFoodPairingsChange,
    );
  }

  String _fmtWindow(int? from, int? until) {
    if (from == null && until == null) return '—';
    if (from != null && until != null) return '$from – $until';
    if (from != null) return 'à partir de $from';
    return 'jusqu\'à $until';
  }
}

class _ChangeLine extends StatelessWidget {
  final String label;
  final String oldValue;
  final String newValue;
  final ThemeData theme;

  const _ChangeLine({
    required this.label,
    required this.oldValue,
    required this.newValue,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label : ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: oldValue,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const TextSpan(text: ' → '),
            TextSpan(
              text: newValue,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onApply;
  final VoidCallback onCancel;

  const _BottomActionBar({
    required this.selectedCount,
    required this.onApply,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            OutlinedButton(
              onPressed: onCancel,
              child: const Text('Annuler'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: Text(
                  onApply == null
                      ? 'Aucune sélection'
                      : 'Appliquer ($selectedCount vin(s))',
                ),
                onPressed: onApply,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
