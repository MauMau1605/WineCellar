import 'package:flutter/material.dart';

class DeveloperToolCardConfig {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDestructive;
  final String? route;

  const DeveloperToolCardConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDestructive,
    required this.route,
  });
}

class DeveloperScreenHelper {
  DeveloperScreenHelper._();

  static const String bannerText =
      'Mode développeur actif — ces fonctionnalités sont réservées '
      'aux tests et ne doivent pas être utilisées en production.';

  static const String toolsTitle = 'Outils disponibles';
  static const String deleteDialogTitle = 'Supprimer tous les vins ?';
  static const String deleteDialogWarning =
      'Cette opération est irréversible.';
  static const String cancelLabel = 'Annuler';
  static const String confirmDeleteLabel = 'Tout supprimer';

  static const DeveloperToolCardConfig reevaluationTool =
      DeveloperToolCardConfig(
        icon: Icons.auto_fix_high,
        title: 'Réévaluation IA des vins',
        subtitle: 'Mettre à jour fenêtres de dégustation et accords mets-vins '
            'pour une sélection de vins en cave.',
        isDestructive: false,
        route: '/developer/reevaluate',
      );

  static const DeveloperToolCardConfig deleteAllWinesTool =
      DeveloperToolCardConfig(
        icon: Icons.delete_forever,
        title: 'Supprimer tous les vins',
        subtitle: 'Vider complètement la cave pour repartir sur une base '
            'de données propre.',
        isDestructive: true,
        route: null,
      );

  static String deleteDialogContent(int wineCount) {
    return 'Cette action supprimera définitivement les $wineCount vin(s) '
        'de la cave, ainsi que tous les placements de bouteilles associés.';
  }

  static String deleteSuccessMessage(int wineCount) {
    return '$wineCount vin(s) supprimé(s) avec succès.';
  }

  static String deleteErrorMessage(String message) {
    return 'Erreur : $message';
  }
}