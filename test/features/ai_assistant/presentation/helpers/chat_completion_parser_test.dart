import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_completion_parser.dart';

void main() {
  group('ChatCompletionParser', () {
    test('extrait un objet JSON depuis un bloc markdown json', () {
      final result = ChatCompletionParser.extractCompletionJson(
        'Analyse\n```json\n{"producer":"Domaine X","drinkUntilYear":2032}\n```',
      );

      expect(result, isNotNull);
      expect(result!['producer'], 'Domaine X');
      expect(result['drinkUntilYear'], 2032);
    });

    test('extrait un objet JSON brut depuis du texte libre', () {
      final result = ChatCompletionParser.extractCompletionJson(
        'Voici un complément {"appellation":"Chablis","region":"Bourgogne"} fin.',
      );

      expect(result, isNotNull);
      expect(result!['appellation'], 'Chablis');
      expect(result['region'], 'Bourgogne');
    });

    test('retourne null si le bloc json est invalide', () {
      final result = ChatCompletionParser.extractCompletionJson(
        '```json\n{"producer":}\n```',
      );

      expect(result, isNull);
    });

    test('retourne null si le contenu decode n est pas un objet', () {
      final result = ChatCompletionParser.extractCompletionJson(
        '```json\n["producer","region"]\n```',
      );

      expect(result, isNull);
    });
  });
}