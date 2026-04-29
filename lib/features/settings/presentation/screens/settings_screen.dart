import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/settings/presentation/helpers/settings_overview_helper.dart';

/// Main settings screen — clean hub navigating to sub-screens.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentProvider = ref.watch(aiProviderSettingProvider);
    final currentLayout = ref.watch(wineListLayoutProvider);
    final devMode = ref.watch(developerModeProvider);
    final currentTheme = ref.watch(appVisualThemeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // -------- Intelligence artificielle --------
          _SettingsTile(
            icon: Icons.smart_toy_outlined,
            iconColor: theme.colorScheme.primary,
            title: 'Intelligence artificielle',
            subtitle: currentProvider.label,
            onTap: () => context.push('/settings/ai'),
          ),
          const Divider(height: 0, indent: 72),

          // -------- Affichage --------
          _SettingsTile(
            icon: Icons.palette_outlined,
            iconColor: Colors.deepPurple,
            title: 'Affichage',
            subtitle: SettingsOverviewHelper.displaySubtitle(
              currentLayout,
              currentTheme,
            ),
            onTap: () => context.push('/settings/display'),
          ),
          const Divider(height: 0, indent: 72),

          // -------- Développeur --------
          _DeveloperSection(devMode: devMode),
          const Divider(height: 0, indent: 72),

          // -------- À propos --------
          _SettingsTile(
            icon: Icons.info_outline,
            iconColor: Colors.blueGrey,
            title: AppConstants.appName,
            subtitle: 'Version ${AppConstants.appVersion}',
            onTap: null,
          ),
        ],
      ),
    );
  }

}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

class _DeveloperSection extends ConsumerWidget {
  final bool devMode;
  const _DeveloperSection({required this.devMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SwitchListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.developer_mode, color: Colors.orange, size: 22),
          ),
          title: Text('Mode développeur', style: theme.textTheme.titleSmall),
          subtitle: Text(
            SettingsOverviewHelper.developerModeSubtitle(devMode),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          value: devMode,
          onChanged: (v) =>
              ref.read(developerModeProvider.notifier).setValue(v),
        ),
        if (SettingsOverviewHelper.shouldShowDeveloperTools(devMode)) ...[
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 20, bottom: 8),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/developer'),
              icon: const Icon(Icons.build_circle_outlined, size: 18),
              label: const Text('Outils développeur'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
