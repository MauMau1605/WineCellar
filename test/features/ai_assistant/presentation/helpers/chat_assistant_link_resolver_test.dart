import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_assistant_link_resolver.dart';

void main() {
  group('ChatAssistantLinkResolver.resolve', () {
    test('pousse directement une route interne absolue', () {
      final action = ChatAssistantLinkResolver.resolve('/settings');

      expect(action.type, ChatAssistantLinkActionType.pushRoute);
      expect(action.route, '/settings');
    });

    test('reconnait un lien detail vin interne depuis une uri absolue', () {
      final action = ChatAssistantLinkResolver.resolve(
        'https://winecellar.local/cellar/wine/42?tab=details',
      );

      expect(action.type, ChatAssistantLinkActionType.pushRoute);
      expect(action.route, '/cellar/wine/42');
    });

    test('ouvre les urls web externes', () {
      final action = ChatAssistantLinkResolver.resolve(
        'https://example.com/articles/chablis',
      );

      expect(action.type, ChatAssistantLinkActionType.openExternal);
      expect(action.externalUri.toString(), 'https://example.com/articles/chablis');
    });

    test('ignore les liens non pris en charge', () {
      final action = ChatAssistantLinkResolver.resolve('mailto:test@example.com');

      expect(action.type, ChatAssistantLinkActionType.ignore);
      expect(action.route, isNull);
      expect(action.externalUri, isNull);
    });
  });
}