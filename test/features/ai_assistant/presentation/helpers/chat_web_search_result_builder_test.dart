import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/cellar_tracker_result.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/vivino_result.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_web_search_result_builder.dart';

void main() {
  group('ChatWebSearchResultBuilder.buildAssistantMessage', () {
    test('construit un message assistant sans sources quand aucune source nest fournie', () {
      final message = ChatWebSearchResultBuilder.buildAssistantMessage(
        messageId: 'msg-1',
        timestamp: DateTime(2026),
        result: const AiChatResult(textResponse: 'Reponse simple'),
      );

      expect(message.id, 'msg-1');
      expect(message.content, 'Reponse simple');
      expect(message.webSources, isEmpty);
      expect(message.collapseSourcesByDefault, isFalse);
    });

    test('convertit et deduplique les sources web puis active le collapse par defaut', () {
      final message = ChatWebSearchResultBuilder.buildAssistantMessage(
        messageId: 'msg-2',
        timestamp: DateTime(2026),
        result: const AiChatResult(
          textResponse: 'Reponse sourcee',
          webSources: [
            WebSource(uri: 'https://a.test', title: 'A1'),
            WebSource(uri: 'https://b.test', title: 'B'),
            WebSource(uri: 'https://a.test', title: 'A2'),
          ],
        ),
      );

      expect(message.webSources, hasLength(2));
      expect(message.webSources.first.title, 'A1');
      expect(message.webSources.first.uri, 'https://a.test');
      expect(message.collapseSourcesByDefault, isTrue);
    });

    test('attache les resultats complets Vivino et CellarTracker au message', () {
      const vivinoResult = VivinoSearchResult(
        status: VivinoSourceStatus.found,
        reviews: [VivinoReview(rating: 4.2, note: 'Tres bon')],
      );
      const cellarTrackerResult = CellarTrackerResult(
        status: CellarTrackerSourceStatus.found,
        notes: [CellarTrackerNote(rating: 93, note: 'Garde prometteuse')],
      );

      final message = ChatWebSearchResultBuilder.buildAssistantMessage(
        messageId: 'msg-3',
        timestamp: DateTime(2026),
        result: const AiChatResult(
          textResponse: 'Reponse reviewee',
          vivinoSourceStatus: VivinoSourceStatus.found,
          cellarTrackerStatus: CellarTrackerSourceStatus.found,
        ),
        vivinoResult: vivinoResult,
        cellarTrackerResult: cellarTrackerResult,
      );

      expect(message.vivinoResult, same(vivinoResult));
      expect(message.cellarTrackerResult, same(cellarTrackerResult));
      expect(message.vivinoSourceStatus, VivinoSourceStatus.found);
      expect(message.cellarTrackerStatus, CellarTrackerSourceStatus.found);
    });
  });
}