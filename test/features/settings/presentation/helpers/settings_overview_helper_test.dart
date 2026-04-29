import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/settings/presentation/helpers/settings_overview_helper.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

void main() {
  group('SettingsOverviewHelper.displaySubtitle', () {
    test('retourne seulement le layout sans theme', () {
      final subtitle = SettingsOverviewHelper.displaySubtitle(
        WineListLayout.list,
        null,
      );

      expect(subtitle, WineListLayout.list.label);
    });

    test('inclut le theme quand il est defini', () {
      final subtitle = SettingsOverviewHelper.displaySubtitle(
        WineListLayout.masterDetail,
        VirtualCellarTheme.stoneCave,
      );

      expect(
        subtitle,
        '${WineListLayout.masterDetail.label} · Thème : ${VirtualCellarTheme.stoneCave.label}',
      );
    });
  });

  group('SettingsOverviewHelper developer section', () {
    test('retourne le sous-titre actif en mode developpeur', () {
      expect(
        SettingsOverviewHelper.developerModeSubtitle(true),
        'Activé — outils avancés disponibles',
      );
      expect(SettingsOverviewHelper.shouldShowDeveloperTools(true), isTrue);
    });

    test('retourne le sous-titre inactif hors mode developpeur', () {
      expect(
        SettingsOverviewHelper.developerModeSubtitle(false),
        'Désactivé',
      );
      expect(SettingsOverviewHelper.shouldShowDeveloperTools(false), isFalse);
    });
  });
}