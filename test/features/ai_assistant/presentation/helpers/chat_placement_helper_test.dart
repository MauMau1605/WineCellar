import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_placement_helper.dart';

void main() {
  group('ChatPlacementHelper.resolveSinglePlacement', () {
    test('stoppe sur annulation ou none', () {
      expect(
        ChatPlacementHelper.resolveSinglePlacement(
          ChatPlacementChoiceResolution.cancel,
        ).type,
        ChatSinglePlacementNextStepType.stop,
      );
      expect(
        ChatPlacementHelper.resolveSinglePlacement(
          ChatPlacementChoiceResolution.none,
        ).type,
        ChatSinglePlacementNextStepType.stop,
      );
    });

    test('demande une cave sans navigation pour associate only', () {
      expect(
        ChatPlacementHelper.resolveSinglePlacement(
          ChatPlacementChoiceResolution.associateOnly,
        ).type,
        ChatSinglePlacementNextStepType.chooseCellarOnly,
      );
    });

    test('demande une navigation vers emplacement pour place in slot', () {
      expect(
        ChatPlacementHelper.resolveSinglePlacement(
          ChatPlacementChoiceResolution.placeInSlot,
        ).type,
        ChatSinglePlacementNextStepType.navigateToSlot,
      );
    });
  });

  group('ChatPlacementHelper grouped helpers', () {
    test('continue le placement groupe seulement pour associate only', () {
      expect(
        ChatPlacementHelper.shouldContinueGroupedPlacement(
          ChatPlacementChoiceResolution.associateOnly,
        ),
        isTrue,
      );
      expect(
        ChatPlacementHelper.shouldContinueGroupedPlacement(
          ChatPlacementChoiceResolution.none,
        ),
        isFalse,
      );
    });

    test('construit les routes et messages attendus', () {
      expect(
        ChatPlacementHelper.buildSinglePlacementRoute(
          cellarId: 3,
          wineId: 7,
        ),
        '/cellars/3?wineId=7',
      );
      expect(
        ChatPlacementHelper.buildGroupedPlacementRoute(cellarId: 3),
        '/cellars/3',
      );
      expect(
        ChatPlacementHelper.buildGroupedPlacementSuccessMessage(
          wineCount: 2,
          cellarName: 'Ma cave',
        ),
        '2 vins associés à « Ma cave ».',
      );
    });

    test('formate la liste des vins du dialogue groupe', () {
      expect(
        ChatPlacementHelper.buildGroupedWineNames(const [
          (id: 1, name: 'Chablis'),
          (id: 2, name: 'Margaux'),
        ]),
        '• Chablis\n• Margaux',
      );
    });
  });
}