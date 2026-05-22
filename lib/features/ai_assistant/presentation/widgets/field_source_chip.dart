import 'package:flutter/material.dart';

/// Small icon button shown next to a field label in developer mode when that
/// field was completed by a web source (Vivino, CellarTracker, Gemini Web…).
///
/// Tapping the button shows a popup menu listing the source names.
/// Visible only when [sources] is non-empty.
class FieldSourceChip extends StatelessWidget {
  final List<String> sources;

  const FieldSourceChip({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final uniqueSources = sources.toSet().toList();

    return PopupMenuButton<String>(
      tooltip: 'Sources web',
      padding: EdgeInsets.zero,
      itemBuilder: (_) => uniqueSources
          .map(
            (s) => PopupMenuItem<String>(
              enabled: false,
              height: 36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForSource(s),
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(s, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          Icons.public,
          size: 14,
          color: theme.colorScheme.primary.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  IconData _iconForSource(String source) {
    return switch (source.toLowerCase()) {
      'vivino' => Icons.wine_bar,
      'cellartracker' => Icons.inventory_2,
      'gemini web' => Icons.travel_explore,
      _ => Icons.public,
    };
  }
}
