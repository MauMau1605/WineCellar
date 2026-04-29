import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

class SettingsOverviewHelper {
  SettingsOverviewHelper._();

  static String displaySubtitle(
    WineListLayout layout,
    VirtualCellarTheme? currentTheme,
  ) {
    final parts = <String>[layout.label];
    if (currentTheme != null) {
      parts.add('Thème : ${currentTheme.label}');
    }
    return parts.join(' · ');
  }

  static String developerModeSubtitle(bool devMode) {
    return devMode
        ? 'Activé — outils avancés disponibles'
        : 'Désactivé';
  }

  static bool shouldShowDeveloperTools(bool devMode) {
    return devMode;
  }
}