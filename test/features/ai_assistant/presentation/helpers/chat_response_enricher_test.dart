import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_response_enricher.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

void main() {
  group('ChatResponseEnricher.chatSourcesFromWebSources', () {
    test('deduplique les sources par uri en conservant le premier ordre', () {
      final sources = ChatResponseEnricher.chatSourcesFromWebSources([
        const WebSource(uri: 'https://a.test', title: 'A1'),
        const WebSource(uri: 'https://b.test', title: 'B'),
        const WebSource(uri: 'https://a.test', title: 'A2'),
      ]);

      expect(sources, hasLength(2));
      expect(sources[0].title, 'A1');
      expect(sources[0].uri, 'https://a.test');
      expect(sources[1].title, 'B');
    });
  });

  group('ChatResponseEnricher.appendWineDetailLinksToResponse', () {
    test('retourne le texte tel quel si la reponse contient deja des liens internes', () {
      final result = ChatResponseEnricher.appendWineDetailLinksToResponse(
        'Voir deja /cellar/wine/1 pour le detail',
        const [
          WineEntity(id: 1, name: 'Chablis', color: WineColor.white),
        ],
      );

      expect(result, 'Voir deja /cellar/wine/1 pour le detail');
    });

    test('ajoute des liens pour les vins mentionnes avec normalisation des accents', () {
      final result = ChatResponseEnricher.appendWineDetailLinksToResponse(
        'Je vous conseille Chateau Margaux 2015 et Cotes du Rhone pour ce plat.',
        const [
          WineEntity(
            id: 1,
            name: 'Château Margaux',
            vintage: 2015,
            color: WineColor.red,
          ),
          WineEntity(
            id: 2,
            name: 'Côtes du Rhône',
            color: WineColor.red,
          ),
        ],
      );

      expect(result, contains('Acces rapide aux fiches des vins proposes :'));
      expect(result, contains('- [Château Margaux 2015](/cellar/wine/1)'));
      expect(result, contains('- [Côtes du Rhône](/cellar/wine/2)'));
    });

    test('deduplique les vins par id et limite la liste a cinq liens', () {
      final wines = List.generate(
        6,
        (index) => WineEntity(
          id: index + 1,
          name: 'Vin ${index + 1}',
          color: WineColor.red,
        ),
      );

      final result = ChatResponseEnricher.appendWineDetailLinksToResponse(
        'Vin 1, Vin 2, Vin 3, Vin 4, Vin 5 et Vin 6 sont adaptes. Vin 1 aussi.',
        wines,
      );

      expect(RegExp(r'/cellar/wine/').allMatches(result), hasLength(5));
      expect(result, isNot(contains('/cellar/wine/6')));
    });

    test('retourne le texte initial si aucun vin de la cave n est mentionne', () {
      final result = ChatResponseEnricher.appendWineDetailLinksToResponse(
        'Je recommande plutot un Riesling.',
        const [
          WineEntity(id: 1, name: 'Chablis', color: WineColor.white),
        ],
      );

      expect(result, 'Je recommande plutot un Riesling.');
    });
  });
}