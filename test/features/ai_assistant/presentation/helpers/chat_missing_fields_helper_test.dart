import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_missing_fields_helper.dart';

void main() {
  group('ChatMissingFieldsHelper.resolveInitialSelectedColor', () {
    test('retourne la couleur existante si connue', () {
      final color = ChatMissingFieldsHelper.resolveInitialSelectedColor('white');

      expect(color, WineColor.white);
    });

    test('retourne null si la couleur est absente', () {
      final color = ChatMissingFieldsHelper.resolveInitialSelectedColor(null);

      expect(color, isNull);
    });
  });

  group('ChatMissingFieldsHelper.canConfirm', () {
    test('refuse si le nom manque encore', () {
      final canConfirm = ChatMissingFieldsHelper.canConfirm(
        wineData: const WineAiResponse(color: 'red'),
        enteredName: '   ',
        selectedColor: WineColor.red,
      );

      expect(canConfirm, isFalse);
    });

    test('refuse si la couleur manque encore', () {
      final canConfirm = ChatMissingFieldsHelper.canConfirm(
        wineData: const WineAiResponse(name: 'Chablis'),
        enteredName: 'Chablis',
        selectedColor: null,
      );

      expect(canConfirm, isFalse);
    });

    test('accepte si les champs obligatoires sont complets', () {
      final canConfirm = ChatMissingFieldsHelper.canConfirm(
        wineData: const WineAiResponse(name: 'Chablis'),
        enteredName: 'Chablis',
        selectedColor: WineColor.white,
      );

      expect(canConfirm, isTrue);
    });
  });

  group('ChatMissingFieldsHelper.completeWineData', () {
    test('complete les champs obligatoires manquants et preserve le reste', () {
      final completed = ChatMissingFieldsHelper.completeWineData(
        wineData: const WineAiResponse(
          appellation: 'Chablis',
          producer: 'Domaine Test',
          vintage: 2020,
          quantity: 2,
        ),
        enteredName: 'Chablis Premier Cru',
        selectedColor: WineColor.white,
      );

      expect(completed.name, 'Chablis Premier Cru');
      expect(completed.color, 'white');
      expect(completed.appellation, 'Chablis');
      expect(completed.producer, 'Domaine Test');
      expect(completed.vintage, 2020);
      expect(completed.quantity, 2);
    });

    test('preserve le nom et la couleur si deja presents', () {
      final completed = ChatMissingFieldsHelper.completeWineData(
        wineData: const WineAiResponse(
          name: 'Chablis',
          color: 'white',
          quantity: 2,
        ),
        enteredName: 'Autre nom',
        selectedColor: WineColor.red,
      );

      expect(completed.name, 'Chablis');
      expect(completed.color, 'white');
      expect(completed.quantity, 2);
    });
  });
}