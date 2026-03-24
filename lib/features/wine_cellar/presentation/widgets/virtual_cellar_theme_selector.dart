import 'package:flutter/material.dart';

import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

IconData iconForVirtualCellarTheme(VirtualCellarTheme theme) {
  switch (theme) {
    case VirtualCellarTheme.classic:
      return Icons.waves;
    case VirtualCellarTheme.wineFridge:
      return Icons.kitchen_outlined;
    case VirtualCellarTheme.premiumCave:
      return Icons.wine_bar;
  }
}

String descriptionForVirtualCellarTheme(VirtualCellarTheme theme) {
  switch (theme) {
    case VirtualCellarTheme.classic:
      return 'Slots en vague comme la representation actuelle';
    case VirtualCellarTheme.wineFridge:
      return 'Casier type cave de service / frigo a vin';
    case VirtualCellarTheme.premiumCave:
      return 'Cave premium avec boiseries et éclairage ambiant';
  }
}

class VirtualCellarThemeSelector extends StatelessWidget {
  final VirtualCellarTheme selectedTheme;
  final ValueChanged<VirtualCellarTheme> onChanged;

  const VirtualCellarThemeSelector({
    super.key,
    required this.selectedTheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Representation', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VirtualCellarTheme.values
              .map((theme) {
                final selected = theme == selectedTheme;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconForVirtualCellarTheme(theme), size: 16),
                      const SizedBox(width: 6),
                      Text(theme.label),
                    ],
                  ),
                  selected: selected,
                  onSelected: (_) => onChanged(theme),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        Text(
          descriptionForVirtualCellarTheme(selectedTheme),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
