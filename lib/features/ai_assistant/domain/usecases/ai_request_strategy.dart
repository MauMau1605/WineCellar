import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';

enum AddWineMessageIntent {
  newWine,
  refineCurrentWine,
  unclear,
}

class WebSearchDecision {
  final bool shouldUseWebSearch;
  final String reason;

  const WebSearchDecision({
    required this.shouldUseWebSearch,
    required this.reason,
  });
}

/// Local, deterministic strategy to reduce unnecessary web-grounded requests.
class AiRequestStrategy {
  AiRequestStrategy._();

  static const Set<String> _highValueFields = {
    'producer',
    'appellation',
    'drinkFromYear',
    'drinkUntilYear',
    'tastingNotes',
  };

  static const List<String> _explicitNewWineMarkers = [
    'nouveau vin',
    'nouvelle bouteille',
    'nouvelle reference',
    'nouvelle cuvee',
    'autre vin',
    'autre bouteille',
    'autre reference',
    'je veux ajouter',
    'j ai achete',
    'j ai un',
    'j ai aussi',
    'deuxieme vin',
    '2e vin',
    'second vin',
  ];

  static const List<String> _explicitRefinementMarkers = [
    'en fait',
    'correction',
    'corrige',
    'corriger',
    'rectifie',
    'ce vin',
    'celui ci',
    'millesime',
    'quantite',
    'prix',
    'appellation',
    'producteur',
    'region',
    'couleur',
    'cepage',
  ];

  static const List<String> _wineIdentityMarkers = [
    'chateau',
    'domaine',
    'cotes',
    'chablis',
    'sancerre',
    'bordeaux',
    'bourgogne',
    'champagne',
    'riesling',
    'pinot',
    'merlot',
    'syrah',
  ];

  static WebSearchDecision decideWebSearchForWineCompletion(
    WineAiResponse wine,
  ) {
    if ((wine.name ?? '').trim().isEmpty) {
      return const WebSearchDecision(
        shouldUseWebSearch: false,
        reason: 'Nom du vin absent.',
      );
    }

    if (wine.estimatedFields.isEmpty) {
      return const WebSearchDecision(
        shouldUseWebSearch: false,
        reason: 'Aucun champ estimé à confirmer.',
      );
    }

    final estimated = wine.estimatedFields.toSet();
    final highValueCount = estimated.intersection(_highValueFields).length;
    final hasIdentitySignals = wine.vintage != null ||
        (wine.appellation ?? '').trim().isNotEmpty ||
        (wine.producer ?? '').trim().isNotEmpty;

    if (!hasIdentitySignals) {
      return const WebSearchDecision(
        shouldUseWebSearch: false,
        reason: 'Identité du vin insuffisante pour une recherche fiable.',
      );
    }

    if (highValueCount > 0) {
      return const WebSearchDecision(
        shouldUseWebSearch: true,
        reason: 'Champs critiques à confirmer via sources web.',
      );
    }

    if (estimated.length >= 3) {
      return const WebSearchDecision(
        shouldUseWebSearch: true,
        reason: 'Plusieurs champs estimés nécessitent une vérification.',
      );
    }

    return const WebSearchDecision(
      shouldUseWebSearch: false,
      reason: 'Nombre de champs estimés insuffisant pour justifier une recherche web.',
    );
  }

  static AddWineMessageIntent detectAddWineMessageIntent({
    required String userMessage,
    required List<WineAiResponse> currentWineData,
  }) {
    if (currentWineData.isEmpty) return AddWineMessageIntent.newWine;

    final normalized = _normalize(userMessage);
    if (normalized.isEmpty) return AddWineMessageIntent.unclear;

    final hasExplicitNew = _explicitNewWineMarkers.any(normalized.contains);
    final hasExplicitRefine =
        _explicitRefinementMarkers.any(normalized.contains);

    if (hasExplicitNew) return AddWineMessageIntent.newWine;
    if (hasExplicitRefine) return AddWineMessageIntent.refineCurrentWine;

    final hasVintage = RegExp(r'\b(19|20)\d{2}\b').hasMatch(normalized);
    final hasWineIdentityCue = _wineIdentityMarkers.any(normalized.contains);
    if (hasVintage && hasWineIdentityCue) {
      return AddWineMessageIntent.newWine;
    }

    return AddWineMessageIntent.unclear;
  }

  static String _normalize(String input) {
    var s = input.toLowerCase().trim();
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ÿ': 'y',
      '’': '\'',
    };

    replacements.forEach((from, to) {
      s = s.replaceAll(from, to);
    });
    s = s.replaceAll(RegExp(r"[^a-z0-9\s']"), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }
}