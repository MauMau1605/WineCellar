import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/helpers/virtual_cellar_list_helper.dart';

void main() {
  group('VirtualCellarListHelper', () {
    test('génère le premier nom de cave disponible sans tenir compte de la casse', () {
      expect(
        VirtualCellarListHelper.generateDefaultCellarName([
          'Cave 1',
          'cave 2',
          'Réserve',
        ]),
        'Cave 3',
      );
    });

    test('construit le hint et normalise le nom saisi', () {
      expect(
        VirtualCellarListHelper.cellarNameHint(const []),
        'Ex : Cave principale',
      );
      expect(
        VirtualCellarListHelper.cellarNameHint(['Cave 1']),
        'Par défaut : Cave 2',
      );
      expect(
        VirtualCellarListHelper.normalizeCellarName('  Cave du fond  ', const []),
        'Cave du fond',
      );
      expect(
        VirtualCellarListHelper.normalizeCellarName('   ', ['Cave 1']),
        'Cave 2',
      );
    });

    test('borne les dimensions en mode simplifié', () {
      expect(VirtualCellarListHelper.clampSimplifiedRows(0), 1);
      expect(VirtualCellarListHelper.clampSimplifiedRows(14), 12);
      expect(VirtualCellarListHelper.clampSimplifiedColumns(0), 1);
      expect(VirtualCellarListHelper.clampSimplifiedColumns(18), 16);
    });

    test('construit les messages de renommage et de suppression', () {
      expect(VirtualCellarListHelper.shouldAskToRenameLocations(0), isFalse);
      expect(VirtualCellarListHelper.shouldAskToRenameLocations(2), isTrue);
      expect(
        VirtualCellarListHelper.renameLocationDialogContent(
          2,
          'Cave 1',
          'Cave principale',
        ),
        '2 bouteille(s) ont la localisation "Cave 1".\n\n'
        'Souhaitez-vous mettre à jour leur localisation en "Cave principale" ?',
      );
      expect(
        VirtualCellarListHelper.renameLocationSuccessMessage(2),
        '2 bouteille(s) mise(s) à jour.',
      );
      expect(
        VirtualCellarListHelper.deleteDialogContent('Cave 1'),
        'Le cellier "Cave 1" sera supprimé. '
        'Les bouteilles qu\'il contient seront déplacées (non supprimées).',
      );
    });

    test('construit le sous-titre de carte et détecte le mode expert', () {
      const cellar = VirtualCellarEntity(
        id: 4,
        name: 'Panoramique',
        rows: 3,
        columns: 4,
        theme: VirtualCellarTheme.premiumCave,
      );

      expect(
        VirtualCellarListHelper.cellarCardSubtitle(cellar),
        '3 rangées × 4 colonnes (12 emplacements) • Cave premium',
      );
      expect(VirtualCellarListHelper.shouldOpenExpertEditor(false), isFalse);
      expect(VirtualCellarListHelper.shouldOpenExpertEditor(true), isTrue);
    });
  });
}