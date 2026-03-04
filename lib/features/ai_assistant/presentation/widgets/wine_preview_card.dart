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
            if (wineData.name != null) _buildField('Nom', wineData.name!),
            if (wineData.appellation != null)
              _buildField('Appellation', wineData.appellation!),
            if (wineData.producer != null)
              _buildField('Producteur', wineData.producer!),
            if (wineData.region != null)
              _buildField('Région', wineData.region!),
            if (wineData.country != null)
              _buildField('Pays', wineData.country!),
            if (wineData.color != null)
              _buildField('Couleur', _colorLabel(wineData.color!)),
            if (wineData.vintage != null)
              _buildField('Millésime', wineData.vintage.toString()),
            if (wineData.grapeVarieties.isNotEmpty)
              _buildField('Cépages', wineData.grapeVarieties.join(', ')),
            if (wineData.quantity != null)
              _buildField('Quantité', '${wineData.quantity} bouteille(s)'),
            if (wineData.purchasePrice != null)
              _buildField(
                  'Prix', '${wineData.purchasePrice!.toStringAsFixed(2)} €'),
            if (wineData.drinkFromYear != null)
              _buildField('À boire dès', wineData.drinkFromYear.toString()),
            if (wineData.drinkUntilYear != null)
              _buildField(
                  'À boire jusqu\'à', wineData.drinkUntilYear.toString()),
            if (wineData.suggestedFoodPairings.isNotEmpty)
              _buildField(
                  'Accords mets', wineData.suggestedFoodPairings.join(', ')),

            const SizedBox(height: 12),

            // Action buttons
            if (wineData.isComplete)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter à la cave'),
                  ),
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

  Widget _buildField(String label, String value) {
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
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
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
