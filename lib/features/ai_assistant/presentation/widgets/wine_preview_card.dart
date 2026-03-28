import 'package:flutter/material.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';

/// Card showing the wine data extracted by AI, with confirm/edit buttons
class WinePreviewCard extends StatelessWidget {
  final WineAiResponse wineData;
  final VoidCallback? onConfirm;
  final VoidCallback? onEdit;

  const WinePreviewCard({
    super.key,
    required this.wineData,
    this.onConfirm,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
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
                if (wineData.isComplete)
                  Chip(
                    label: const Text('Complet'),
                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Chip(
                    label: const Text('Incomplet'),
                    backgroundColor: Colors.orange.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const Divider(),

            // Wine fields
            if (wineData.name != null)
              _buildField('Nom', wineData.name!,
                  isEstimated: wineData.estimatedFields.contains('name')),
            if (wineData.appellation != null)
              _buildField('Appellation', wineData.appellation!,
                  isEstimated: wineData.estimatedFields.contains('appellation')),
            if (wineData.producer != null)
              _buildField('Producteur', wineData.producer!,
                  isEstimated: wineData.estimatedFields.contains('producer')),
            if (wineData.region != null)
              _buildField('Région', wineData.region!,
                  isEstimated: wineData.estimatedFields.contains('region')),
            if (wineData.country != null)
              _buildField('Pays', wineData.country!,
                  isEstimated: wineData.estimatedFields.contains('country')),
            if (wineData.color != null)
              _buildField('Couleur', _colorLabel(wineData.color!),
                  isEstimated: wineData.estimatedFields.contains('color')),
            if (wineData.vintage != null)
              _buildField('Millésime', wineData.vintage.toString(),
                  isEstimated: wineData.estimatedFields.contains('vintage')),
            if (wineData.grapeVarieties.isNotEmpty)
              _buildField('Cépages', wineData.grapeVarieties.join(', '),
                  isEstimated: wineData.estimatedFields.contains('grapeVarieties')),
            if (wineData.quantity != null)
              _buildField('Quantité', '${wineData.quantity} bouteille(s)',
                  isEstimated: wineData.estimatedFields.contains('quantity')),
            if (wineData.purchasePrice != null)
              _buildField(
                  'Prix', '${wineData.purchasePrice!.toStringAsFixed(2)} €',
                  isEstimated: wineData.estimatedFields.contains('purchasePrice')),
            if (wineData.drinkFromYear != null)
              _buildField(
                'À boire dès',
                wineData.drinkFromYear.toString(),
                isEstimated: wineData.estimatedFields.contains('drinkFromYear'),
              ),
            if (wineData.drinkUntilYear != null)
              _buildField(
                'À boire jusqu\'à',
                wineData.drinkUntilYear.toString(),
                isEstimated: wineData.estimatedFields.contains('drinkUntilYear'),
              ),
            if (wineData.suggestedFoodPairings.isNotEmpty)
              _buildField(
                'Accords mets',
                wineData.suggestedFoodPairings.join(', '),
                isEstimated: wineData.estimatedFields.contains('suggestedFoodPairings'),
              ),

            // Confidence notes for estimated fields
            if (wineData.confidenceNotes != null &&
                wineData.confidenceNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wineData.confidenceNotes!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Action buttons
            if (wineData.isComplete)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onConfirm == null)
                    Chip(
                      avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      label: const Text('Ajouté'),
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(color: Colors.green, fontSize: 12),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onConfirm != null && onEdit != null)
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                    ),
                  if (onConfirm != null) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter à la cave'),
                    ),
                  ],
                ],
              )
            else
              Text(
                'Continuez la conversation pour compléter les informations.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value, {bool isEstimated = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
                    message: 'Estimé par l\'IA',
                    child:
                        Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _colorLabel(String color) {
    switch (color) {
      case 'red':
        return '🍷 Rouge';
      case 'white':
        return '🥂 Blanc';
      case 'rose':
        return '🌸 Rosé';
      case 'sparkling':
        return '🍾 Pétillant';
      case 'sweet':
        return '🍯 Moelleux';
      default:
        return color;
    }
  }
}
