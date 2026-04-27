import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

typedef ChatAddedWineRecord = ({int id, String name});

enum ChatPreAddResolution { cancel, edit, continueAdd }

enum ChatSingleAddGuardType {
  invalidIndex,
  cancelled,
  editRequested,
  incompleteWine,
  proceed,
}

class ChatSingleAddGuard {
  final ChatSingleAddGuardType type;
  final WineAiResponse? wineData;

  const ChatSingleAddGuard._({required this.type, this.wineData});

  const ChatSingleAddGuard.invalidIndex()
    : this._(type: ChatSingleAddGuardType.invalidIndex);

  const ChatSingleAddGuard.cancelled()
    : this._(type: ChatSingleAddGuardType.cancelled);

  const ChatSingleAddGuard.editRequested()
    : this._(type: ChatSingleAddGuardType.editRequested);

  const ChatSingleAddGuard.incompleteWine({required WineAiResponse wineData})
    : this._(type: ChatSingleAddGuardType.incompleteWine, wineData: wineData);

  const ChatSingleAddGuard.proceed({required WineAiResponse wineData})
    : this._(type: ChatSingleAddGuardType.proceed, wineData: wineData);
}

enum ChatDuplicateResolution { cancel, incrementExisting, createNew }

enum ChatDuplicateActionType {
  cancelled,
  rejectMissingExistingId,
  incrementExistingQuantity,
  addNewReference,
}

class ChatDuplicateAction {
  final ChatDuplicateActionType type;
  final int? wineId;
  final int? newQuantity;

  const ChatDuplicateAction._({
    required this.type,
    this.wineId,
    this.newQuantity,
  });

  const ChatDuplicateAction.cancelled()
    : this._(type: ChatDuplicateActionType.cancelled);

  const ChatDuplicateAction.rejectMissingExistingId()
    : this._(type: ChatDuplicateActionType.rejectMissingExistingId);

  const ChatDuplicateAction.incrementExistingQuantity({
    required int wineId,
    required int newQuantity,
  }) : this._(
         type: ChatDuplicateActionType.incrementExistingQuantity,
         wineId: wineId,
         newQuantity: newQuantity,
       );

  const ChatDuplicateAction.addNewReference()
    : this._(type: ChatDuplicateActionType.addNewReference);
}

enum ChatBulkAddPreparationType { cancel, editFirstComplete, addEligibleWines }

class ChatBulkAddPreparation {
  final ChatBulkAddPreparationType type;
  final int? editWineIndex;
  final List<int> indicesToAdd;

  const ChatBulkAddPreparation._({
    required this.type,
    this.editWineIndex,
    this.indicesToAdd = const [],
  });

  const ChatBulkAddPreparation.cancel()
    : this._(type: ChatBulkAddPreparationType.cancel);

  const ChatBulkAddPreparation.editFirstComplete({required int editWineIndex})
    : this._(
         type: ChatBulkAddPreparationType.editFirstComplete,
         editWineIndex: editWineIndex,
       );

  const ChatBulkAddPreparation.addEligibleWines({required List<int> indicesToAdd})
    : this._(
         type: ChatBulkAddPreparationType.addEligibleWines,
         indicesToAdd: indicesToAdd,
       );
}

enum ChatPlacementPlanType { none, single, grouped }

class ChatPlacementPlan {
  final ChatPlacementPlanType type;
  final ChatAddedWineRecord? singleWine;
  final List<ChatAddedWineRecord> addedWines;

  const ChatPlacementPlan._({
    required this.type,
    this.singleWine,
    this.addedWines = const [],
  });

  const ChatPlacementPlan.none() : this._(type: ChatPlacementPlanType.none);

  const ChatPlacementPlan.single({required ChatAddedWineRecord singleWine})
    : this._(type: ChatPlacementPlanType.single, singleWine: singleWine);

  const ChatPlacementPlan.grouped({required List<ChatAddedWineRecord> addedWines})
    : this._(type: ChatPlacementPlanType.grouped, addedWines: addedWines);
}

class ChatAddFlowPlanner {
  ChatAddFlowPlanner._();

  static ChatSingleAddGuard guardSingleAdd({
    required int wineIndex,
    required List<WineAiResponse> wines,
    required bool askManualEditBeforeAdd,
    required ChatPreAddResolution resolution,
  }) {
    if (wineIndex < 0 || wineIndex >= wines.length) {
      return const ChatSingleAddGuard.invalidIndex();
    }

    if (askManualEditBeforeAdd) {
      switch (resolution) {
        case ChatPreAddResolution.cancel:
          return const ChatSingleAddGuard.cancelled();
        case ChatPreAddResolution.edit:
          return const ChatSingleAddGuard.editRequested();
        case ChatPreAddResolution.continueAdd:
          break;
      }
    }

    final wineData = wines[wineIndex];
    if (!wineData.isComplete) {
      return ChatSingleAddGuard.incompleteWine(wineData: wineData);
    }
    return ChatSingleAddGuard.proceed(wineData: wineData);
  }

  static ChatDuplicateAction resolveDuplicate({
    required WineEntity candidate,
    required WineEntity? duplicate,
    required ChatDuplicateResolution resolution,
  }) {
    if (duplicate == null) {
      return const ChatDuplicateAction.addNewReference();
    }

    switch (resolution) {
      case ChatDuplicateResolution.cancel:
        return const ChatDuplicateAction.cancelled();
      case ChatDuplicateResolution.createNew:
        return const ChatDuplicateAction.addNewReference();
      case ChatDuplicateResolution.incrementExisting:
        if (duplicate.id == null) {
          return const ChatDuplicateAction.rejectMissingExistingId();
        }
        return ChatDuplicateAction.incrementExistingQuantity(
          wineId: duplicate.id!,
          newQuantity: duplicate.quantity + candidate.quantity,
        );
    }
  }

  static ChatBulkAddPreparation prepareBulkAdd({
    required List<WineAiResponse> wines,
    required Set<int> addedIndices,
    required ChatPreAddResolution resolution,
  }) {
    switch (resolution) {
      case ChatPreAddResolution.cancel:
        return const ChatBulkAddPreparation.cancel();
      case ChatPreAddResolution.edit:
        final firstEditableIndex = wines.indexWhere((wine) => wine.isComplete);
        if (firstEditableIndex >= 0) {
          return ChatBulkAddPreparation.editFirstComplete(
            editWineIndex: firstEditableIndex,
          );
        }
        return const ChatBulkAddPreparation.cancel();
      case ChatPreAddResolution.continueAdd:
        final indicesToAdd = <int>[];
        for (var i = 0; i < wines.length; i++) {
          if (!addedIndices.contains(i) && wines[i].isComplete) {
            indicesToAdd.add(i);
          }
        }
        return ChatBulkAddPreparation.addEligibleWines(indicesToAdd: indicesToAdd);
    }
  }

  static ChatPlacementPlan buildPlacementPlan(
    List<ChatAddedWineRecord> addedWines,
  ) {
    if (addedWines.isEmpty) {
      return const ChatPlacementPlan.none();
    }
    if (addedWines.length == 1) {
      return ChatPlacementPlan.single(singleWine: addedWines.first);
    }
    return ChatPlacementPlan.grouped(addedWines: addedWines);
  }
}