import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_cellar_naming_helper.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';

void main() {
  group('ChatCellarNamingHelper.buildDefaultCellarName', () {
    test('retourne Ma cave si le nom de base est libre', () {
      final name = ChatCellarNamingHelper.buildDefaultCellarName(const [
        VirtualCellarEntity(name: 'Ma cave 2', rows: 5, columns: 5),
      ]);

      expect(name, 'Ma cave');
    });

    test('utilise Ma cave 2 si le nom de base existe deja avec casse variable', () {
      final name = ChatCellarNamingHelper.buildDefaultCellarName(const [
        VirtualCellarEntity(name: '  MA CAVE ', rows: 5, columns: 5),
      ]);

      expect(name, 'Ma cave 2');
    });

    test('cherche le premier suffixe libre', () {
      final name = ChatCellarNamingHelper.buildDefaultCellarName(const [
        VirtualCellarEntity(name: 'Ma cave', rows: 5, columns: 5),
        VirtualCellarEntity(name: 'Ma cave 2', rows: 5, columns: 5),
        VirtualCellarEntity(name: 'Ma cave 3', rows: 5, columns: 5),
      ]);

      expect(name, 'Ma cave 4');
    });
  });
}