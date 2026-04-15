import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/virtual_cellar_theme_selector.dart';

/// Sub-screen for display / appearance preferences.
class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentLayout = ref.watch(wineListLayoutProvider);
    final currentTheme = ref.watch(appVisualThemeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Affichage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -------- Layout de la liste --------
          _SectionHeader(
            icon: Icons.view_quilt_outlined,
            title: 'Disposition de la cave',
          ),
          const SizedBox(height: 4),
          Text(
            'Choisissez comment afficher votre liste de vins.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<WineListLayout>(
            groupValue: currentLayout,
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(wineListLayoutProvider.notifier)
                    .setLayout(value);
              }
            },
            child: Column(
              children: WineListLayout.values.map(
                (layout) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: RadioListTile<WineListLayout>(
                    value: layout,
                    secondary: Icon(layout.icon),
                    title: Text(layout.label),
                    subtitle: Text(layout.description),
                  ),
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // -------- Thème visuel --------
          _SectionHeader(
            icon: Icons.palette_outlined,
            title: 'Thème visuel',
          ),
          const SizedBox(height: 4),
          Text(
            'Le thème choisi s\'applique à l\'ensemble de l\'interface. '
            'Les celliers thémés l\'activent automatiquement pendant la consultation.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RadioGroup<VirtualCellarTheme?>(
                groupValue: currentTheme,
                onChanged: (value) {
                  ref.read(appVisualThemeProvider.notifier).setTheme(value);
                },
                child: Column(
                  children: [
                    RadioListTile<VirtualCellarTheme?>(
                      title: const Text('Classique'),
                      subtitle:
                          const Text('Thème clair vin & crème par défaut'),
                      secondary: const Icon(Icons.wb_sunny_outlined),
                      value: null,
                    ),
                    ...VirtualCellarTheme.values
                        .where((t) => t != VirtualCellarTheme.classic)
                        .map(
                          (t) => RadioListTile<VirtualCellarTheme?>(
                            title: Text(t.label),
                            subtitle:
                                Text(descriptionForVirtualCellarTheme(t)),
                            secondary:
                                Icon(iconForVirtualCellarTheme(t)),
                            value: t,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
