import 'package:flutter/material.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Card widget displaying a wine in the list
class WineCard extends StatelessWidget {
  final WineEntity wine;
  final VoidCallback onTap;
  final ValueChanged<int> onQuantityChanged;

  const WineCard({
    super.key,
    required this.wine,
    required this.onTap,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Color indicator
              Container(
                width: 8,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.colorForWine(wine.color.name),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              // Wine info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      wine.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (wine.appellation != null)
                      Text(
                        wine.appellation!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Wine color chip
                        _buildMiniChip(
                          context,
                          '${wine.color.emoji} ${wine.color.label}',
                          AppTheme.colorForWine(wine.color.name),
                        ),
                        const SizedBox(width: 6),
                        // Maturity indicator
                        _buildMiniChip(
                          context,
                          '${wine.maturity.emoji} ${wine.maturity.label}',
                          _maturityColor(wine.maturity),
                        ),
                        if (wine.region != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              wine.region!,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Quantity controls
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () =>
                        onQuantityChanged(wine.quantity + 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  Text(
                    '${wine.quantity}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: wine.quantity > 0
                        ? () => onQuantityChanged(wine.quantity - 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
      ),
    );
  }

  Color _maturityColor(WineMaturity maturity) {
    switch (maturity) {
      case WineMaturity.tooYoung:
        return Colors.blue;
      case WineMaturity.ready:
        return Colors.green;
      case WineMaturity.peak:
        return Colors.amber;
      case WineMaturity.pastPeak:
        return Colors.red;
      case WineMaturity.unknown:
        return Colors.grey;
    }
  }
}
