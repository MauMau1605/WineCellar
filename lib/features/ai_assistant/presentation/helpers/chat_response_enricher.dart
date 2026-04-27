import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

class ChatResponseEnricher {
  ChatResponseEnricher._();

  static List<ChatSource> chatSourcesFromWebSources(
    List<WebSource> webSources,
  ) {
    final seen = <String>{};
    return webSources
        .where((source) => seen.add(source.uri))
        .map((source) => ChatSource(title: source.title, uri: source.uri))
        .toList();
  }

  static String appendWineDetailLinksToResponse(
    String responseText,
    List<WineEntity> cellarWines,
  ) {
    if (cellarWines.isEmpty || responseText.contains('/cellar/wine/')) {
      return responseText;
    }

    final normalizedResponse = _normalizeForMatching(responseText);
    final matched = <WineEntity>[];

    for (final wine in cellarWines) {
      if (wine.id == null) continue;
      final normalizedDisplayName = _normalizeForMatching(wine.displayName);
      final normalizedName = _normalizeForMatching(wine.name);
      final isMentioned =
          normalizedDisplayName.isNotEmpty &&
              normalizedResponse.contains(normalizedDisplayName) ||
          (normalizedName.isNotEmpty &&
              normalizedResponse.contains(normalizedName));
      if (isMentioned) {
        matched.add(wine);
      }
    }

    if (matched.isEmpty) return responseText;

    final uniqueById = <int, WineEntity>{
      for (final wine in matched) wine.id!: wine,
    };
    final links = uniqueById.values
        .take(5)
        .map((wine) => '- [${wine.displayName}](/cellar/wine/${wine.id})')
        .join('\n');

    return '$responseText\n\nAcces rapide aux fiches des vins proposes :\n$links';
  }

  static String _normalizeForMatching(String value) {
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