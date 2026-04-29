import 'package:flutter/material.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/virtual_cellar_theme_selector.dart';

class LayoutOptionData {
  final WineListLayout value;
  final String label;
  final String description;
  final IconData icon;

  const LayoutOptionData({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class ThemeOptionData {
  final VirtualCellarTheme? value;
  final String label;
  final String description;
  final IconData icon;

  const ThemeOptionData({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class ConsumptionAlertOptionData {
  final String title;
  final String subtitle;

  const ConsumptionAlertOptionData({
    required this.title,
    required this.subtitle,
  });
}

class DisplaySettingsOptionsHelper {
  DisplaySettingsOptionsHelper._();

  static const String layoutSectionDescription =
      'Choisissez comment afficher votre liste de vins.';

  static const String themeSectionDescription =
      'Le thème choisi s\'applique à l\'ensemble de l\'interface. '
      'Les celliers thémés l\'activent automatiquement pendant la consultation.';

  static const String consumptionAlertsSectionDescription =
      'Mettez en surbrillance les bouteilles proches ou au-dela de leur '
      'fenetre theorique de consommation dans la liste et la cave virtuelle.';

  static const ConsumptionAlertOptionData lastConsumptionYearAlert =
      ConsumptionAlertOptionData(
        title: 'Derniere annee de consommation',
        subtitle: 'Indique "A boire cette annee"',
      );

  static const ConsumptionAlertOptionData pastOptimalConsumptionAlert =
      ConsumptionAlertOptionData(
        title: 'Fenetre optimale depassee',
        subtitle: 'Indique "Fenetre depassee"',
      );

  static List<LayoutOptionData> layoutOptions() {
    return WineListLayout.values
        .map(
          (layout) => LayoutOptionData(
            value: layout,
            label: layout.label,
            description: layout.description,
            icon: layout.icon,
          ),
        )
        .toList(growable: false);
  }

  static List<ThemeOptionData> themeOptions() {
    return [
      const ThemeOptionData(
        value: null,
        label: 'Classique',
        description: 'Thème clair vin & crème par défaut',
        icon: Icons.wb_sunny_outlined,
      ),
      ...VirtualCellarTheme.values
          .where((theme) => theme != VirtualCellarTheme.classic)
          .map(
            (theme) => ThemeOptionData(
              value: theme,
              label: theme.label,
              description: descriptionForVirtualCellarTheme(theme),
              icon: iconForVirtualCellarTheme(theme),
            ),
          ),
    ];
  }
}