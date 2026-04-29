import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/settings/presentation/helpers/display_settings_options_helper.dart';
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
    final highlightLastConsumptionYear =
        ref.watch(highlightLastConsumptionYearProvider);
    final highlightPastOptimalConsumption =
        ref.watch(highlightPastOptimalConsumptionProvider);
    final layoutOptions = DisplaySettingsOptionsHelper.layoutOptions();
    final themeOptions = DisplaySettingsOptionsHelper.themeOptions();

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
            DisplaySettingsOptionsHelper.layoutSectionDescription,
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
              children: layoutOptions.map(
                (layout) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: RadioListTile<WineListLayout>(
                    value: layout.value,
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
            DisplaySettingsOptionsHelper.themeSectionDescription,
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
                  children: themeOptions
                      .map(
                        (option) => RadioListTile<VirtualCellarTheme?>(
                          title: Text(option.label),
                          subtitle: Text(option.description),
                          secondary: Icon(option.icon),
                          value: option.value,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // -------- Alertes de consommation --------
          _SectionHeader(
            icon: Icons.notifications_active_outlined,
            title: 'Alertes de consommation',
          ),
          const SizedBox(height: 4),
          Text(
            DisplaySettingsOptionsHelper.consumptionAlertsSectionDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    DisplaySettingsOptionsHelper.lastConsumptionYearAlert.title,
                  ),
                  subtitle: const Text(
                    DisplaySettingsOptionsHelper
                        .lastConsumptionYearAlert.subtitle,
                  ),
                  value: highlightLastConsumptionYear,
                  onChanged: (value) {
                    ref
                        .read(highlightLastConsumptionYearProvider.notifier)
                        .setValue(value);
                  },
                ),
                const Divider(height: 0),
                SwitchListTile(
                  title: const Text(
                    DisplaySettingsOptionsHelper
                        .pastOptimalConsumptionAlert.title,
                  ),
                  subtitle: const Text(
                    DisplaySettingsOptionsHelper
                        .pastOptimalConsumptionAlert.subtitle,
                  ),
                  value: highlightPastOptimalConsumption,
                  onChanged: (value) {
                    ref
                        .read(highlightPastOptimalConsumptionProvider.notifier)
                        .setValue(value);
                  },
                ),
              ],
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
