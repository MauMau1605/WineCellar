import 'package:flutter_test/flutter_test.dart';

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
  });
}