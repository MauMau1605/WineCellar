import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_assistant_link_resolver.dart';

void main() {
  group('ChatAssistantLinkResolver.resolve', () {
    test('pousse une route interne autorisee (fiche vin)', () {
      final action = ChatAssistantLinkResolver.resolve('/cellar/wine/42');

      expect(action.type, ChatAssistantLinkActionType.pushRoute);
      expect(action.route, '/cellar/wine/42');
    });

    test('pousse une route cellier avec sa query string', () {
      final action = ChatAssistantLinkResolver.resolve('/cellars/3?wineId=7');

      expect(action.type, ChatAssistantLinkActionType.pushRoute);
      expect(action.route, '/cellars/3?wineId=7');
    });

    test('ignore les routes internes non autorisees', () {
      for (final href in ['/settings', '/developer', '/cellar/wine/abc']) {
        final action = ChatAssistantLinkResolver.resolve(href);
        expect(action.type, ChatAssistantLinkActionType.ignore, reason: href);
      }
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