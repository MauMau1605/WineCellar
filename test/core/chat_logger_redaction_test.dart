import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/core/chat_logger.dart';

void main() {
  group('ChatLogger.redactSecrets', () {
    test('masque les cles et mots de passe dans une URL', () {
      final out = ChatLogger.redactSecrets(
        'GET https://x.test/v1?key=SECRET123&a=1 et ?password=hunter2',
      );
      expect(out, isNot(contains('SECRET123')));
      expect(out, isNot(contains('hunter2')));
      expect(out, contains('a=1'));
    });

    test('masque les cles OpenAI/Google et les bearer tokens', () {
      final out = ChatLogger.redactSecrets(
        'sk-abcdefghijklmnopqrstuvwx AIzaSyA1234567890abcdefghijk '
        'Authorization: Bearer abcdefghijklmnop12345',
      );
      expect(out, isNot(contains('abcdefghijklmnopqrstuvwx')));
      expect(out, isNot(contains('AIzaSyA1234567890')));
      expect(out, isNot(contains('abcdefghijklmnop12345')));
    });

    test('laisse le texte normal intact', () {
      expect(ChatLogger.redactSecrets('Un Chablis 2019 ?'), 'Un Chablis 2019 ?');
    });
  });
}
