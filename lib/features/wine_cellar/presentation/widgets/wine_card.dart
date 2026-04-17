import 'package:flutter/material.dart';

import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/wine_consumption_highlight.dart';

/// Card widget displaying a wine in the list.
///
/// Supports a [selected] state for the master-detail layout and
/// an optional [compact] mode that hides quantity controls.
class WineCard extends StatelessWidget {
  final WineEntity wine;
  final VoidCallback onTap;
  final ValueChanged<int> onQuantityChanged;
  final bool selected;
  final bool compact;
  final WineConsumptionHighlight consumptionHighlight;

  const WineCard({
    super.key,
    required this.wine,
    required this.onTap,
    required this.onQuantityChanged,
    this.selected = false,
    this.compact = false,
    this.consumptionHighlight = WineConsumptionHighlight.none,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wineColor = AppTheme.colorForWine(wine.color.name);
    final consumptionBorderColor = colorForConsumptionHighlight(
      consumptionHighlight,
    );
    final hasConsumptionHighlight =
        consumptionHighlight != WineConsumptionHighlight.none;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasConsumptionHighlight
              ? consumptionBorderColor
              : selected
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          width: hasConsumptionHighlight ? 2 : (selected ? 1.5 : 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 12,
              vertical: compact ? 10 : 12,
            ),
            child: Row(
              children: [
                // Color dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: wineColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: wineColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
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
                        wine.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _buildSecondLine(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasConsumptionHighlight) ...[
                        const SizedBox(height: 6),
                        _buildConsumptionBadge(theme),
                      ],
                    ],
                  ),
                ),
                // Quantity badge (always shown) or full controls
                if (compact) ...[
                  _buildQuantityBadge(theme, wineColor),
                ] else ...[
                  _buildQuantityControls(theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildSecondLine() {
    final parts = <String>[];
    if (wine.vintage != null) parts.add('${wine.vintage}');
    if (wine.appellation != null) {
      parts.add(wine.appellation!);
    } else if (wine.region != null) {
      parts.add(wine.region!);
    }
    return parts.join(' · ');
  }

  Widget _buildQuantityBadge(ThemeData theme, Color wineColor) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${wine.quantity}',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildQuantityControls(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () => onQuantityChanged(wine.quantity + 1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildConsumptionBadge(ThemeData theme) {
    final label = labelForConsumptionHighlight(consumptionHighlight);
    if (label == null) {
      return const SizedBox.shrink();
    }

    final accent = colorForConsumptionHighlight(consumptionHighlight);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.65)),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
