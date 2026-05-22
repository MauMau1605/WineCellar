import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/reevaluate_wine_from_form_usecase.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/widgets/field_source_chip.dart';

/// Card showing the wine data extracted by AI, with confirm/edit buttons,
/// field locking and a re-evaluation trigger.
class WinePreviewCard extends ConsumerStatefulWidget {
  final WineAiResponse wineData;
  final VoidCallback? onConfirm;
  final VoidCallback? onEdit;
  final VoidCallback? onForceAdd;

  /// Called when the AI re-evaluation produces a new [WineAiResponse].
  final ValueChanged<WineAiResponse>? onReevaluated;

  const WinePreviewCard({
    super.key,
    required this.wineData,
    this.onConfirm,
    this.onEdit,
    this.onForceAdd,
    this.onReevaluated,
  });

  @override
  ConsumerState<WinePreviewCard> createState() => _WinePreviewCardState();
}

class _WinePreviewCardState extends ConsumerState<WinePreviewCard> {
  final Set<String> _lockedFields = {};
  bool _isReevaluating = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(WinePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wineData != widget.wineData) {
      final changed = _diffFields(oldWidget.wineData, widget.wineData);
      if (changed.isNotEmpty) {
        setState(() => _lockedFields.addAll(changed));
      }
    }
  }

  Set<String> _diffFields(WineAiResponse a, WineAiResponse b) {
    final diff = <String>{};
    if (a.name != b.name) diff.add('name');
    if (a.appellation != b.appellation) diff.add('appellation');
    if (a.producer != b.producer) diff.add('producer');
    if (a.region != b.region) diff.add('region');
    if (a.country != b.country) diff.add('country');
    if (a.color != b.color) diff.add('color');
    if (a.vintage != b.vintage) diff.add('vintage');
    if (a.grapeVarieties.join() != b.grapeVarieties.join()) {
      diff.add('grapeVarieties');
    }
    if (a.quantity != b.quantity) diff.add('quantity');
    if (a.purchasePrice != b.purchasePrice) diff.add('purchasePrice');
    if (a.drinkFromYear != b.drinkFromYear) diff.add('drinkFromYear');
    if (a.drinkUntilYear != b.drinkUntilYear) diff.add('drinkUntilYear');
    if (a.tastingNotes != b.tastingNotes) diff.add('tastingNotes');
    if (a.suggestedFoodPairings.join() != b.suggestedFoodPairings.join()) {
      diff.add('suggestedFoodPairings');
    }
    return diff;
  }

  void _toggleLock(String fieldName) {
    setState(() {
      if (_lockedFields.contains(fieldName)) {
        _lockedFields.remove(fieldName);
      } else {
        _lockedFields.add(fieldName);
      }
    });
  }

  Future<void> _reevaluate() async {
    final useCase = ref.read(reevaluateWineFromFormUseCaseProvider);
    if (useCase == null || !mounted) return;
    setState(() => _isReevaluating = true);
    final result = await useCase(
      ReevaluateWineFromFormParams(
        currentData: widget.wineData,
        lockedFields: Set.from(_lockedFields),
      ),
    );
    if (!mounted) return;
    setState(() => _isReevaluating = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Réévaluation échouée : ${failure.message}')),
      ),
      (newData) {
        widget.onReevaluated?.call(newData);
      },
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDev = ref.watch(developerModeProvider);
    final data = widget.wineData;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.wine_bar,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Fiche du vin',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (data.isComplete)
                  Chip(
                    label: const Text('Complet'),
                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(color: Colors.green, fontSize: 12),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Chip(
                    label: const Text('Incomplet'),
                    backgroundColor: Colors.orange.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(color: Colors.orange, fontSize: 12),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const Divider(),

            // Wine fields
            ..._buildFieldRows(data, isDev),

            // Confidence notes — collapsible
            if (data.confidenceNotes != null && data.confidenceNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: ExpansionTile(
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      leading: const Icon(Icons.info_outline,
                          size: 16, color: Colors.amber),
                      title: Text(
                        'Estimations IA (${data.estimatedFields.length} champ(s))',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                      iconColor: Colors.amber,
                      collapsedIconColor: Colors.amber,
                      initiallyExpanded: false,
                      children: [
                        Text(
                          data.confidenceNotes!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Locked fields hint
            if (_lockedFields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.lock,
                        size: 13, color: theme.colorScheme.secondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${_lockedFields.length} champ(s) verrouillé(s) — '
                        'la réévaluation les préservera.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Action buttons
            if (data.isComplete)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onReevaluated != null) ...[
                    _ReevaluateButton(
                      isLoading: _isReevaluating,
                      onPressed: _reevaluate,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.onConfirm == null)
                    Chip(
                      avatar: const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                      label: const Text('Ajouté'),
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      labelStyle:
                          const TextStyle(color: Colors.green, fontSize: 12),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.onConfirm != null && widget.onEdit != null)
                    OutlinedButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                    ),
                  if (widget.onConfirm != null) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: widget.onConfirm,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter à la cave'),
                    ),
                  ],
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Champs obligatoires manquants : '
                    '${data.missingRequiredFields.join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onReevaluated != null) ...[
                        _ReevaluateButton(
                          isLoading: _isReevaluating,
                          onPressed: _reevaluate,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.onEdit != null)
                        OutlinedButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Modifier'),
                        ),
                      if (widget.onForceAdd != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: widget.onForceAdd,
                          icon: const Icon(Icons.warning_amber_rounded,
                              size: 18, color: Colors.orange),
                          label: const Text('Ajouter quand même'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFieldRows(WineAiResponse data, bool isDev) {
    Widget row(String label, String value, String fieldName) => _FieldRow(
          label: label,
          value: value,
          isEstimated: data.estimatedFields.contains(fieldName),
          webSources: isDev ? (data.fieldSources[fieldName] ?? []) : [],
          isLocked: _lockedFields.contains(fieldName),
          onToggleLock: () => _toggleLock(fieldName),
        );

    return [
      if (data.name != null) row('Nom', data.name!, 'name'),
      if (data.appellation != null)
        row('Appellation', data.appellation!, 'appellation'),
      if (data.producer != null) row('Producteur', data.producer!, 'producer'),
      if (data.region != null) row('Région', data.region!, 'region'),
      if (data.country != null) row('Pays', data.country!, 'country'),
      if (data.color != null)
        row('Couleur', _colorLabel(data.color!), 'color'),
      if (data.vintage != null)
        row('Millésime', data.vintage.toString(), 'vintage'),
      if (data.grapeVarieties.isNotEmpty)
        row('Cépages', data.grapeVarieties.join(', '), 'grapeVarieties'),
      if (data.quantity != null)
        row('Quantité', '${data.quantity} bouteille(s)', 'quantity'),
      if (data.purchasePrice != null)
        row('Prix', '${data.purchasePrice!.toStringAsFixed(2)} €',
            'purchasePrice'),
      if (data.drinkFromYear != null)
        row('À boire dès', data.drinkFromYear.toString(), 'drinkFromYear'),
      if (data.drinkUntilYear != null)
        row("À boire jusqu'à", data.drinkUntilYear.toString(), 'drinkUntilYear'),
      if (data.suggestedFoodPairings.isNotEmpty)
        row('Accords mets', data.suggestedFoodPairings.join(', '),
            'suggestedFoodPairings'),
    ];
  }

  String _colorLabel(String color) {
    return switch (color) {
      'red' => '🍷 Rouge',
      'white' => '🥂 Blanc',
      'rose' => '🌸 Rosé',
      'sparkling' => '🍾 Pétillant',
      'sweet' => '🍯 Moelleux',
      _ => color,
    };
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEstimated;
  final List<String> webSources;
  final bool isLocked;
  final VoidCallback onToggleLock;

  const _FieldRow({
    required this.label,
    required this.value,
    required this.isEstimated,
    required this.webSources,
    required this.isLocked,
    required this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle:
                          isEstimated ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                if (isEstimated) ...[
                  const SizedBox(width: 4),
                  const Tooltip(
                    message: "Estimé par l'IA",
                    child:
                        Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                  ),
                ],
                if (webSources.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  FieldSourceChip(sources: webSources),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggleLock,
            child: Tooltip(
              message: isLocked
                  ? 'Champ verrouillé — taper pour déverrouiller'
                  : 'Verrouiller ce champ',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  isLocked ? Icons.lock : Icons.lock_open,
                  size: 14,
                  color: isLocked
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReevaluateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _ReevaluateButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('Réévaluer'),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}

