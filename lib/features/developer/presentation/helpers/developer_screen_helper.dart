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

  static const DeveloperToolCardConfig exportBackupTool =
      DeveloperToolCardConfig(
        icon: Icons.backup_outlined,
        title: 'Exporter la sauvegarde',
        subtitle: 'Exporte la cave complète et la configuration dans un fichier '
            'chiffré (.wce). Inclut les secrets (clés API, CellarTracker) '
            'si le mode développeur est actif.',
        isDestructive: false,
        route: null,
      );

  static const DeveloperToolCardConfig importBackupTool =
      DeveloperToolCardConfig(
        icon: Icons.restore_outlined,
        title: 'Restaurer une sauvegarde',
        subtitle: 'Importe un fichier de sauvegarde .wce et restaure la cave, '
            'la configuration et les secrets qu\'il contient.',
        isDestructive: false,
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

  // ── Backup messages ────────────────────────────────────────────────────────

  static const String backupPasswordLabel = 'Mot de passe de chiffrement';
  static const String backupPasswordHint =
      'Requis pour déchiffrer la sauvegarde lors de la restauration.';
  static const String backupPasswordConfirmLabel = 'Confirmer le mot de passe';
  static const String backupExportTitle = 'Exporter la sauvegarde';
  static const String backupImportTitle = 'Restaurer une sauvegarde';
  static const String backupPasswordMismatch =
      'Les mots de passe ne correspondent pas.';
  static const String backupExportWithSecretsNotice =
      'Mode développeur actif : les clés API et identifiants CellarTracker '
      'seront inclus dans la sauvegarde.';

  static String backupExportConfirmLabel(bool includesSecrets) =>
      includesSecrets ? 'Exporter (avec secrets)' : 'Exporter';
}