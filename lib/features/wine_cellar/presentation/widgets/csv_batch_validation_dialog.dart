import 'package:flutter/material.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';

/// Result of the batch validation dialog.
enum CsvBatchAction {
  /// User validated this batch — import the wines.
  validate,

  /// User wants to re-send this batch to the AI.
  retry,

  /// User cancelled the entire import.
  cancel,
}

class CsvBatchValidationResult {
  final CsvBatchAction action;

  /// The wines after user edits (deletions / field changes).
  /// Only meaningful when [action] is [CsvBatchAction.validate].
  final List<WineAiResponse> wines;

  /// Indices (into the original list) of wines that were manually modified
  /// and should be re-evaluated individually if the user requests it.
  final Set<int> modifiedIndices;

  const CsvBatchValidationResult({
    required this.action,
    this.wines = const [],
    this.modifiedIndices = const {},
  });
}

/// A dialog that shows AI-enriched wines for validation before import.
///
/// Each wine's fields are editable inline. Wines can be deleted.
/// Actions: Validate, Retry batch, Cancel import.
class CsvBatchValidationDialog extends StatefulWidget {
  final int batchNumber;
  final int totalBatches;
  final List<WineAiResponse> wines;

  /// If non-null, called to re-evaluate a single modified wine via the AI.
  final Future<WineAiResponse?> Function(WineAiResponse wine)?
      onReevaluateSingleWine;

  const CsvBatchValidationDialog({
    super.key,
    required this.batchNumber,
    required this.totalBatches,
    required this.wines,
    this.onReevaluateSingleWine,
  });

  @override
  State<CsvBatchValidationDialog> createState() =>
      _CsvBatchValidationDialogState();
}

class _CsvBatchValidationDialogState extends State<CsvBatchValidationDialog> {
  late List<WineAiResponse?> _wines; // null = deleted
  final Set<int> _modifiedIndices = {};
  final Set<int> _reevaluatingIndices = {};

  @override
  void initState() {
    super.initState();
    _wines = List<WineAiResponse?>.from(widget.wines);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeWines =
        _wines.where((w) => w != null).toList();
    final deletedCount = _wines.where((w) => w == null).length;

    return AlertDialog(
      title: Text(
        'Validation lot IA ${widget.batchNumber}/${widget.totalBatches}',
      ),
      content: SizedBox(
        width: 800,
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary bar
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${activeWines.length} vin(s) à importer',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (deletedCount > 0) ...[
                        const SizedBox(width: 12),
                        Text(
                          '($deletedCount supprimé(s))',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ],
                      if (_modifiedIndices.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          '(${_modifiedIndices.length} modifié(s))',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Wine cards
                for (var i = 0; i < _wines.length; i++) ...[
                  if (_wines[i] != null) ...[
                    _WineEditCard(
                      index: i,
                      wine: _wines[i]!,
                      isModified: _modifiedIndices.contains(i),
                      isReevaluating: _reevaluatingIndices.contains(i),
                      canReevaluate: widget.onReevaluateSingleWine != null,
                      onWineChanged: (updated) {
                        setState(() {
                          _wines[i] = updated;
                          _modifiedIndices.add(i);
                        });
                      },
                      onDelete: () {
                        setState(() {
                          _wines[i] = null;
                          _modifiedIndices.remove(i);
                        });
                      },
                      onReevaluate: widget.onReevaluateSingleWine != null
                          ? () => _reevaluateSingleWine(i)
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const CsvBatchValidationResult(action: CsvBatchAction.cancel),
          ),
          child: const Text('Annuler l\'import'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(
            const CsvBatchValidationResult(action: CsvBatchAction.retry),
          ),
          child: const Text('Réessayer ce lot'),
        ),
        FilledButton(
          onPressed: activeWines.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    CsvBatchValidationResult(
                      action: CsvBatchAction.validate,
                      wines: activeWines.cast<WineAiResponse>(),
                      modifiedIndices: _modifiedIndices,
                    ),
                  ),
          child: const Text('Valider ce lot'),
        ),
      ],
    );
  }

  Future<void> _reevaluateSingleWine(int index) async {
    if (widget.onReevaluateSingleWine == null || _wines[index] == null) return;
    setState(() => _reevaluatingIndices.add(index));

    try {
      final result =
          await widget.onReevaluateSingleWine!(_wines[index]!);
      if (result != null && mounted) {
        setState(() {
          _wines[index] = result;
          _modifiedIndices.remove(index);
        });
      }
    } finally {
      if (mounted) setState(() => _reevaluatingIndices.remove(index));
    }
  }
}

// ====================================================================
// Editable wine card within the batch validation dialog
// ====================================================================

class _WineEditCard extends StatefulWidget {
  final int index;
  final WineAiResponse wine;
  final bool isModified;
  final bool isReevaluating;
  final bool canReevaluate;
  final ValueChanged<WineAiResponse> onWineChanged;
  final VoidCallback onDelete;
  final VoidCallback? onReevaluate;

  const _WineEditCard({
    required this.index,
    required this.wine,
    required this.isModified,
    required this.isReevaluating,
    required this.canReevaluate,
    required this.onWineChanged,
    required this.onDelete,
    this.onReevaluate,
  });

  @override
  State<_WineEditCard> createState() => _WineEditCardState();
}

class _WineEditCardState extends State<_WineEditCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wine = widget.wine;
    final borderColor = widget.isModified
        ? Colors.orange
        : widget.isReevaluating
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vin ${widget.index + 1} — ${wine.name ?? "Sans nom"}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (widget.isModified)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: const Text('Modifié'),
                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                        visualDensity: VisualDensity.compact,
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  if (widget.isReevaluating)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (widget.isModified &&
                      widget.canReevaluate &&
                      !widget.isReevaluating)
                    IconButton(
                      icon: const Icon(Icons.smart_toy, size: 18),
                      tooltip: 'Réévaluer ce vin par l\'IA',
                      onPressed: widget.onReevaluate,
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Retirer ce vin',
                    onPressed: widget.onDelete,
                    color: Colors.red,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),

          // Editable fields
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _editField('Nom', wine.name, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: v.isEmpty ? null : v,
                      appellation: wine.appellation,
                      producer: wine.producer,
                      region: wine.region,
                      country: wine.country,
                      color: wine.color,
                      vintage: wine.vintage,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: wine.quantity,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: wine.drinkFromYear,
                      drinkUntilYear: wine.drinkUntilYear,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                  _editField('Appellation', wine.appellation, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: wine.name,
                      appellation: v.isEmpty ? null : v,
                      producer: wine.producer,
                      region: wine.region,
                      country: wine.country,
                      color: wine.color,
                      vintage: wine.vintage,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: wine.quantity,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: wine.drinkFromYear,
                      drinkUntilYear: wine.drinkUntilYear,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                  _editField('Producteur', wine.producer, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: wine.name,
                      appellation: wine.appellation,
                      producer: v.isEmpty ? null : v,
                      region: wine.region,
                      country: wine.country,
                      color: wine.color,
                      vintage: wine.vintage,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: wine.quantity,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: wine.drinkFromYear,
                      drinkUntilYear: wine.drinkUntilYear,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                  _editField('Région', wine.region, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: wine.name,
                      appellation: wine.appellation,
                      producer: wine.producer,
                      region: v.isEmpty ? null : v,
                      country: wine.country,
                      color: wine.color,
                      vintage: wine.vintage,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: wine.quantity,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: wine.drinkFromYear,
                      drinkUntilYear: wine.drinkUntilYear,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                  _editField('Pays', wine.country, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: wine.name,
                      appellation: wine.appellation,
                      producer: wine.producer,
                      region: wine.region,
                      country: v.isEmpty ? null : v,
                      color: wine.color,
                      vintage: wine.vintage,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: wine.quantity,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: wine.drinkFromYear,
                      drinkUntilYear: wine.drinkUntilYear,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                  _editField('Couleur', wine.color, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: wine.name,
                      appellation: wine.appellation,
                      producer: wine.producer,
                      region: wine.region,
                      country: wine.country,
                      color: v.isEmpty ? null : v,
                      vintage: wine.vintage,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: wine.quantity,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: wine.drinkFromYear,
                      drinkUntilYear: wine.drinkUntilYear,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                  _editFieldInt('Millésime', wine.vintage, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: wine.name,
                      appellation: wine.appellation,
                      producer: wine.producer,
                      region: wine.region,
                      country: wine.country,
                      color: wine.color,
                      vintage: v,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: wine.quantity,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: wine.drinkFromYear,
                      drinkUntilYear: wine.drinkUntilYear,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                  _editFieldInt('Quantité', wine.quantity, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: wine.name,
                      appellation: wine.appellation,
                      producer: wine.producer,
                      region: wine.region,
                      country: wine.country,
                      color: wine.color,
                      vintage: wine.vintage,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: v,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: wine.drinkFromYear,
                      drinkUntilYear: wine.drinkUntilYear,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                  _editField(
                    'Cépages',
                    wine.grapeVarieties.join(', '),
                    (v) {
                      final grapes = v
                          .split(RegExp(r'[,;]'))
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      widget.onWineChanged(WineAiResponse(
                        name: wine.name,
                        appellation: wine.appellation,
                        producer: wine.producer,
                        region: wine.region,
                        country: wine.country,
                        color: wine.color,
                        vintage: wine.vintage,
                        grapeVarieties: grapes,
                        quantity: wine.quantity,
                        purchasePrice: wine.purchasePrice,
                        drinkFromYear: wine.drinkFromYear,
                        drinkUntilYear: wine.drinkUntilYear,
                        tastingNotes: wine.tastingNotes,
                        suggestedFoodPairings: wine.suggestedFoodPairings,
                        description: wine.description,
                        needsMoreInfo: wine.needsMoreInfo,
                        followUpQuestion: wine.followUpQuestion,
                        estimatedFields: wine.estimatedFields,
                        confidenceNotes: wine.confidenceNotes,
                      ));
                    },
                  ),
                  _editFieldInt('Boire dès', wine.drinkFromYear, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: wine.name,
                      appellation: wine.appellation,
                      producer: wine.producer,
                      region: wine.region,
                      country: wine.country,
                      color: wine.color,
                      vintage: wine.vintage,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: wine.quantity,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: v,
                      drinkUntilYear: wine.drinkUntilYear,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                  _editFieldInt('Boire jusqu\'à', wine.drinkUntilYear, (v) {
                    widget.onWineChanged(WineAiResponse(
                      name: wine.name,
                      appellation: wine.appellation,
                      producer: wine.producer,
                      region: wine.region,
                      country: wine.country,
                      color: wine.color,
                      vintage: wine.vintage,
                      grapeVarieties: wine.grapeVarieties,
                      quantity: wine.quantity,
                      purchasePrice: wine.purchasePrice,
                      drinkFromYear: wine.drinkFromYear,
                      drinkUntilYear: v,
                      tastingNotes: wine.tastingNotes,
                      suggestedFoodPairings: wine.suggestedFoodPairings,
                      description: wine.description,
                      needsMoreInfo: wine.needsMoreInfo,
                      followUpQuestion: wine.followUpQuestion,
                      estimatedFields: wine.estimatedFields,
                      confidenceNotes: wine.confidenceNotes,
                    ));
                  }),
                ],
              ),
            ),

          // Estimated fields info
          if (_isExpanded &&
              wine.estimatedFields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                '✨ Estimé par l\'IA : ${wine.estimatedFields.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.amber.shade700,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _editField(
    String label,
    String? value,
    ValueChanged<String> onChanged,
  ) {
    return SizedBox(
      width: 220,
      child: TextFormField(
        initialValue: value ?? '',
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _editFieldInt(
    String label,
    int? value,
    ValueChanged<int?> onChanged,
  ) {
    return SizedBox(
      width: 120,
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
        onChanged: (v) => onChanged(int.tryParse(v)),
      ),
    );
  }
}
