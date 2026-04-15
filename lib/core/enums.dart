import 'package:flutter/material.dart';

/// Wine color enumeration
enum WineColor {
  red,
  white,
  rose,
  sparkling,
  sweet;

  String get label {
    switch (this) {
      case WineColor.red:
        return 'Rouge';
      case WineColor.white:
        return 'Blanc';
      case WineColor.rose:
        return 'Rosé';
      case WineColor.sparkling:
        return 'Pétillant';
      case WineColor.sweet:
        return 'Moelleux';
    }
  }

  String get emoji {
    switch (this) {
      case WineColor.red:
        return '🍷';
      case WineColor.white:
        return '🥂';
      case WineColor.rose:
        return '🌸';
      case WineColor.sparkling:
        return '🍾';
      case WineColor.sweet:
        return '🍯';
    }
  }
}

/// Wine maturity status based on current year vs drinking window
enum WineMaturity {
  tooYoung,
  ready,
  peak,
  pastPeak,
  unknown;

  String get label {
    switch (this) {
      case WineMaturity.tooYoung:
        return 'Trop jeune';
      case WineMaturity.ready:
        return 'Prêt à boire';
      case WineMaturity.peak:
        return 'À son apogée';
      case WineMaturity.pastPeak:
        return 'Passé';
      case WineMaturity.unknown:
        return 'Inconnu';
    }
  }

  String get emoji {
    switch (this) {
      case WineMaturity.tooYoung:
        return '⏳';
      case WineMaturity.ready:
        return '✅';
      case WineMaturity.peak:
        return '⭐';
      case WineMaturity.pastPeak:
        return '⚠️';
      case WineMaturity.unknown:
        return '❓';
    }
  }
}

/// Wine sort field enumeration
enum WineSortField {
  name,
  vintage,
  drinkUntilYear,
  drinkFromYear,
  color,
  region,
  appellation,
  rating,
  location;

  String get label {
    switch (this) {
      case WineSortField.name:
        return 'Nom';
      case WineSortField.vintage:
        return 'Millésime';
      case WineSortField.drinkUntilYear:
        return 'Fin de fenêtre';
      case WineSortField.drinkFromYear:
        return 'Apogée';
      case WineSortField.color:
        return 'Couleur';
      case WineSortField.region:
        return 'Région';
      case WineSortField.appellation:
        return 'Appellation';
      case WineSortField.rating:
        return 'Note';
      case WineSortField.location:
        return 'Localisation';
    }
  }
}

/// Wine list layout mode
enum WineListLayout {
  auto,
  list,
  masterDetail,
  masterDetailVertical;

  String get label {
    switch (this) {
      case WineListLayout.auto:
        return 'Automatique';
      case WineListLayout.list:
        return 'Liste';
      case WineListLayout.masterDetail:
        return 'Maître-détail horizontal';
      case WineListLayout.masterDetailVertical:
        return 'Maître-détail vertical';
    }
  }

  String get description {
    switch (this) {
      case WineListLayout.auto:
        return 'S\'adapte à la largeur de l\'écran';
      case WineListLayout.list:
        return 'Liste simple, clic ouvre le détail en plein écran';
      case WineListLayout.masterDetail:
        return 'Liste à gauche, détail à droite (séparation ajustable)';
      case WineListLayout.masterDetailVertical:
        return 'Liste en haut, détail en bas (séparation ajustable)';
    }
  }

  IconData get icon {
    switch (this) {
      case WineListLayout.auto:
        return Icons.auto_awesome;
      case WineListLayout.list:
        return Icons.view_list;
      case WineListLayout.masterDetail:
        return Icons.view_sidebar;
      case WineListLayout.masterDetailVertical:
        return Icons.view_stream;
    }
  }

  /// Whether this layout shows a master-detail split.
  bool get isMasterDetail =>
      this == masterDetail || this == masterDetailVertical;
}

/// AI provider enumeration
enum AiProvider {
  openai,
  gemini,
  mistral,
  ollama;

  String get label {
    switch (this) {
      case AiProvider.openai:
        return 'OpenAI';
      case AiProvider.gemini:
        return 'Google Gemini';
      case AiProvider.mistral:
        return 'Mistral AI';
      case AiProvider.ollama:
        return 'Ollama (local)';
    }
  }
}
