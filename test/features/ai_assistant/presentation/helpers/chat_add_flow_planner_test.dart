import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_add_flow_planner.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

void main() {
  group('ChatAddFlowPlanner.guardSingleAdd', () {
    test('rejette un index invalide', () {
      final guard = ChatAddFlowPlanner.guardSingleAdd(
        wineIndex: 2,
        wines: const [WineAiResponse(name: 'Chablis', color: 'white')],
        askManualEditBeforeAdd: false,
        resolution: ChatPreAddResolution.continueAdd,
      );

      expect(guard.type, ChatSingleAddGuardType.invalidIndex);
    });

    test('respecte l annulation avant ajout manuel', () {
      final guard = ChatAddFlowPlanner.guardSingleAdd(
        wineIndex: 0,
        wines: const [WineAiResponse(name: 'Chablis', color: 'white')],
        askManualEditBeforeAdd: true,
        resolution: ChatPreAddResolution.cancel,
      );

      expect(guard.type, ChatSingleAddGuardType.cancelled);
    });

    test('redirige vers edition si demandee', () {
      final guard = ChatAddFlowPlanner.guardSingleAdd(
        wineIndex: 0,
        wines: const [WineAiResponse(name: 'Chablis', color: 'white')],
        askManualEditBeforeAdd: true,
        resolution: ChatPreAddResolution.edit,
      );

      expect(guard.type, ChatSingleAddGuardType.editRequested);
    });

    test('rejette une fiche incomplete', () {
      final guard = ChatAddFlowPlanner.guardSingleAdd(
        wineIndex: 0,
        wines: const [WineAiResponse(name: 'Chablis')],
        askManualEditBeforeAdd: false,
        resolution: ChatPreAddResolution.continueAdd,
      );

      expect(guard.type, ChatSingleAddGuardType.incompleteWine);
    });

    test('autorise une fiche complete', () {
      final guard = ChatAddFlowPlanner.guardSingleAdd(
        wineIndex: 0,
        wines: const [WineAiResponse(name: 'Chablis', color: 'white')],
        askManualEditBeforeAdd: false,
        resolution: ChatPreAddResolution.continueAdd,
      );

      expect(guard.type, ChatSingleAddGuardType.proceed);
      expect(guard.wineData!.name, 'Chablis');
    });
  });

  group('ChatAddFlowPlanner.resolveDuplicate', () {
    const candidate = WineEntity(
      name: 'Chablis',
      color: WineColor.white,
      quantity: 2,
    );

    test('cree une nouvelle reference sans doublon', () {
      final action = ChatAddFlowPlanner.resolveDuplicate(
        candidate: candidate,
        duplicate: null,
        resolution: ChatDuplicateResolution.cancel,
      );

      expect(action.type, ChatDuplicateActionType.addNewReference);
    });

    test('annule si utilisateur annule', () {
      final action = ChatAddFlowPlanner.resolveDuplicate(
        candidate: candidate,
        duplicate: const WineEntity(
          id: 4,
          name: 'Chablis',
          color: WineColor.white,
        ),
        resolution: ChatDuplicateResolution.cancel,
      );

      expect(action.type, ChatDuplicateActionType.cancelled);
    });

    test('rejette lincrementation si le doublon na pas did', () {
      final action = ChatAddFlowPlanner.resolveDuplicate(
        candidate: candidate,
        duplicate: const WineEntity(
          name: 'Chablis',
          color: WineColor.white,
          quantity: 5,
        ),
        resolution: ChatDuplicateResolution.incrementExisting,
      );

      expect(action.type, ChatDuplicateActionType.rejectMissingExistingId);
    });

    test('calcule la nouvelle quantite lors de lincrementation', () {
      final action = ChatAddFlowPlanner.resolveDuplicate(
        candidate: candidate,
        duplicate: const WineEntity(
          id: 8,
          name: 'Chablis',
          color: WineColor.white,
          quantity: 5,
        ),
        resolution: ChatDuplicateResolution.incrementExisting,
      );

      expect(action.type, ChatDuplicateActionType.incrementExistingQuantity);
      expect(action.wineId, 8);
      expect(action.newQuantity, 7);
    });

    test('autorise la creation dune nouvelle reference malgre un doublon', () {
      final action = ChatAddFlowPlanner.resolveDuplicate(
        candidate: candidate,
        duplicate: const WineEntity(
          id: 8,
          name: 'Chablis',
          color: WineColor.white,
          quantity: 5,
        ),
        resolution: ChatDuplicateResolution.createNew,
      );

      expect(action.type, ChatDuplicateActionType.addNewReference);
    });
  });

  group('ChatAddFlowPlanner.prepareBulkAdd', () {
    const wines = [
      WineAiResponse(name: 'Chablis', color: 'white'),
      WineAiResponse(name: 'Incomplet'),
      WineAiResponse(name: 'Margaux', color: 'red'),
    ];

    test('annule tout sur annulation utilisateur', () {
      final plan = ChatAddFlowPlanner.prepareBulkAdd(
        wines: wines,
        addedIndices: const {},
        resolution: ChatPreAddResolution.cancel,
      );

      expect(plan.type, ChatBulkAddPreparationType.cancel);
    });

    test('choisit la premiere fiche complete a editer', () {
      final plan = ChatAddFlowPlanner.prepareBulkAdd(
        wines: wines,
        addedIndices: const {},
        resolution: ChatPreAddResolution.edit,
      );

      expect(plan.type, ChatBulkAddPreparationType.editFirstComplete);
      expect(plan.editWineIndex, 0);
    });

    test('selectionne seulement les fiches completes non deja ajoutees', () {
      final plan = ChatAddFlowPlanner.prepareBulkAdd(
        wines: wines,
        addedIndices: const {2},
        resolution: ChatPreAddResolution.continueAdd,
      );

      expect(plan.type, ChatBulkAddPreparationType.addEligibleWines);
      expect(plan.indicesToAdd, [0]);
    });
  });

  group('ChatAddFlowPlanner.buildPlacementPlan', () {
    test('retourne none quand aucun vin na ete ajoute', () {
      final plan = ChatAddFlowPlanner.buildPlacementPlan(const []);

      expect(plan.type, ChatPlacementPlanType.none);
    });

    test('retourne single pour un seul vin ajoute', () {
      final plan = ChatAddFlowPlanner.buildPlacementPlan(const [
        (id: 3, name: 'Chablis'),
      ]);

      expect(plan.type, ChatPlacementPlanType.single);
      expect(plan.singleWine, (id: 3, name: 'Chablis'));
    });

    test('retourne grouped pour plusieurs vins ajoutes', () {
      final plan = ChatAddFlowPlanner.buildPlacementPlan(const [
        (id: 3, name: 'Chablis'),
        (id: 4, name: 'Margaux'),
      ]);

      expect(plan.type, ChatPlacementPlanType.grouped);
      expect(plan.addedWines.length, 2);
    });
  });
}