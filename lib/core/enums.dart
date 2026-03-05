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
