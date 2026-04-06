import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Landing screen for developer tools.
/// Shows all available developer-only features.
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Outils développeur')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            content: const Text(
              'Mode développeur actif — ces fonctionnalités sont réservées '
              'aux tests et ne doivent pas être utilisées en production.',
            ),
            leading: const Icon(Icons.warning_amber, color: Colors.orange),
            actions: const [SizedBox.shrink()],
          ),
          const SizedBox(height: 20),
          Text(
            'Outils disponibles',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: const Text('Réévaluation IA des vins'),
              subtitle: const Text(
                'Mettre à jour fenêtres de dégustation et accords mets-vins '
                'pour une sélection de vins en cave.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/developer/reevaluate'),
            ),
          ),
        ],
      ),
    );
  }
}
