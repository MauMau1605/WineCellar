import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/developer/presentation/helpers/developer_screen_helper.dart';

void main() {
  group('DeveloperScreenHelper', () {
    test('expose les textes principaux du hub developpeur', () {
      expect(DeveloperScreenHelper.bannerText, contains('Mode développeur actif'));
      expect(DeveloperScreenHelper.toolsTitle, 'Outils disponibles');
      expect(
        DeveloperScreenHelper.deleteDialogTitle,
        'Supprimer tous les vins ?',
      );
      expect(
        DeveloperScreenHelper.deleteDialogWarning,
        'Cette opération est irréversible.',
      );
    });

    test('decrit les deux outils visibles du hub', () {
      expect(DeveloperScreenHelper.reevaluationTool.icon, Icons.auto_fix_high);
      expect(
        DeveloperScreenHelper.reevaluationTool.title,
        'Réévaluation IA des vins',
      );
      expect(
        DeveloperScreenHelper.reevaluationTool.route,
        '/developer/reevaluate',
      );
      expect(DeveloperScreenHelper.reevaluationTool.isDestructive, isFalse);

      expect(
        DeveloperScreenHelper.deleteAllWinesTool.icon,
        Icons.delete_forever,
      );
      expect(
        DeveloperScreenHelper.deleteAllWinesTool.title,
        'Supprimer tous les vins',
      );
      expect(DeveloperScreenHelper.deleteAllWinesTool.route, isNull);
      expect(DeveloperScreenHelper.deleteAllWinesTool.isDestructive, isTrue);
    });

    test('construit les messages de suppression dynamiques', () {
      expect(
        DeveloperScreenHelper.deleteDialogContent(12),
        contains('12 vin(s)'),
      );
      expect(
        DeveloperScreenHelper.deleteSuccessMessage(12),
        '12 vin(s) supprimé(s) avec succès.',
      );
      expect(
        DeveloperScreenHelper.deleteErrorMessage('boom'),
        'Erreur : boom',
      );
    });
  });
}