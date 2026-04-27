import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_request_strategy.dart';

class ChatAutoWebCompletionPlan {
  final List<int> indicesToMarkAttempted;
  final List<List<int>> completionBatches;

  const ChatAutoWebCompletionPlan({
    required this.indicesToMarkAttempted,
    required this.completionBatches,
  });

  bool get hasWork => completionBatches.isNotEmpty;
  int get totalBatches => completionBatches.length;
}

class ChatAutoWebCompletionPlanner {
  ChatAutoWebCompletionPlanner._();

  static ChatAutoWebCompletionPlan build({
    required List<WineAiResponse> wines,
    required Set<int> attemptedIndices,
    required Set<int> addedIndices,
    required int batchSize,
  }) {
    final indicesToMarkAttempted = <int>[];
    final indicesToComplete = <int>[];

    for (var index = 0; index < wines.length; index++) {
      if (attemptedIndices.contains(index)) continue;
      if (addedIndices.contains(index)) continue;

      final wine = wines[index];
      if (wine.name == null || wine.estimatedFields.isEmpty) continue;

      final decision = AiRequestStrategy.decideWebSearchForWineCompletion(wine);
      if (!decision.shouldUseWebSearch) {
        indicesToMarkAttempted.add(index);
        continue;
      }

      indicesToComplete.add(index);
    }

    final completionBatches = <List<int>>[];
    for (var start = 0; start < indicesToComplete.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, indicesToComplete.length);
      completionBatches.add(indicesToComplete.sublist(start, end));
    }

    return ChatAutoWebCompletionPlan(
      indicesToMarkAttempted: indicesToMarkAttempted,
      completionBatches: completionBatches,
    );
  }

  static String buildBatchProgressMessage({
    required int batchNumber,
    required int totalBatches,
    required int batchSize,
  }) {
    return '🌐 Complétion internet — lot $batchNumber/$totalBatches '
        '($batchSize vin(s))…';
  }
}