import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/settings/presentation/helpers/display_settings_options_helper.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/virtual_cellar_theme_selector.dart';

void main() {
  group('DisplaySettingsOptionsHelper.layoutOptions', () {
    test('expose toutes les options de layout avec leurs metadonnees', () {
      final options = DisplaySettingsOptionsHelper.layoutOptions();

      expect(options, hasLength(WineListLayout.values.length));
      expect(options.map((option) => option.value), WineListLayout.values);
      expect(options.first.label, WineListLayout.auto.label);
      expect(options.first.description, WineListLayout.auto.description);
      expect(options.first.icon, WineListLayout.auto.icon);
    });
  });

  group('DisplaySettingsOptionsHelper.themeOptions', () {
    test('place l option classique en tete puis les themes non classiques', () {
      final options = DisplaySettingsOptionsHelper.themeOptions();

      expect(options, hasLength(VirtualCellarTheme.values.length));
      expect(options.first.value, isNull);
      expect(options.first.label, 'Classique');
      expect(options.first.description, 'Thème clair vin & crème par défaut');
      expect(options.first.icon, Icons.wb_sunny_outlined);
      expect(
        options.skip(1).map((option) => option.value),
        VirtualCellarTheme.values.where(
          (theme) => theme != VirtualCellarTheme.classic,
        ),
      );
    });

    test('reprend les descriptions et icones du selecteur de themes', () {
      final stoneCave = DisplaySettingsOptionsHelper.themeOptions().firstWhere(
        (option) => option.value == VirtualCellarTheme.stoneCave,
      );

      expect(
        stoneCave.description,
        descriptionForVirtualCellarTheme(VirtualCellarTheme.stoneCave),
      );
      expect(
        stoneCave.icon,
        iconForVirtualCellarTheme(VirtualCellarTheme.stoneCave),
      );
    });
  });

  group('DisplaySettingsOptionsHelper alert metadata', () {
    test('expose les descriptions de section attendues', () {
      expect(
        DisplaySettingsOptionsHelper.layoutSectionDescription,
        contains('liste de vins'),
      );
      expect(
        DisplaySettingsOptionsHelper.themeSectionDescription,
        contains('celliers thémés'),
      );
      expect(
        DisplaySettingsOptionsHelper.consumptionAlertsSectionDescription,
        contains('fenetre theorique de consommation'),
      );
    });

    test('expose les deux reglages d alertes de consommation', () {
      expect(
        DisplaySettingsOptionsHelper.lastConsumptionYearAlert.title,
        'Derniere annee de consommation',
      );
      expect(
        DisplaySettingsOptionsHelper.lastConsumptionYearAlert.subtitle,
        'Indique "A boire cette annee"',
      );
      expect(
        DisplaySettingsOptionsHelper.pastOptimalConsumptionAlert.title,
        'Fenetre optimale depassee',
      );
      expect(
        DisplaySettingsOptionsHelper.pastOptimalConsumptionAlert.subtitle,
        'Indique "Fenetre depassee"',
      );
    });
  });
}