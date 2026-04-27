import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

class ChatDuplicateMatcher {
  ChatDuplicateMatcher._();

  static WineEntity? findPotentialDuplicate({
    required WineEntity candidate,
    required List<WineEntity> existingWines,
  }) {
    final normalizedName = normalize(candidate.name);
    final normalizedProducer = normalize(candidate.producer ?? '');
    final candidateVintage = candidate.vintage;

    for (final wine in existingWines) {
      if (normalize(wine.name) != normalizedName) continue;
      if (wine.vintage != candidateVintage) continue;
      if (normalize(wine.producer ?? '') != normalizedProducer) continue;
      return wine;
    }
    return null;
  }

  static String normalize(String value) {
    var normalized = value.trim().toLowerCase();

    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
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
      'õ': 'o',
      'ö': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ÿ': 'y',
    };

    replacements.forEach((accented, plain) {
      normalized = normalized.replaceAll(accented, plain);
    });

    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }
}