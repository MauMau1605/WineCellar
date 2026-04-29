import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_image_analysis_helper.dart';

void main() {
  group('ChatImageAnalysisHelper.planCapture', () {
    test('retourne noop si une analyse est deja en cours', () {
      final plan = ChatImageAnalysisHelper.planCapture(
        isLoading: true,
        useOcr: true,
        hasVisionUseCase: false,
      );

      expect(plan.type, ChatImageCapturePlanType.noop);
    });

    test('demande une configuration vision si le mode vision est indisponible', () {
      final plan = ChatImageAnalysisHelper.planCapture(
        isLoading: false,
        useOcr: false,
        hasVisionUseCase: false,
      );

      expect(plan.type, ChatImageCapturePlanType.requireVisionConfiguration);
    });

    test('autorise la branche OCR quand elle est active', () {
      final plan = ChatImageAnalysisHelper.planCapture(
        isLoading: false,
        useOcr: true,
        hasVisionUseCase: false,
      );

      expect(plan.type, ChatImageCapturePlanType.proceedWithOcr);
    });

    test('autorise la branche vision si le use case existe', () {
      final plan = ChatImageAnalysisHelper.planCapture(
        isLoading: false,
        useOcr: false,
        hasVisionUseCase: true,
      );

      expect(plan.type, ChatImageCapturePlanType.proceedWithVision);
    });
  });

  group('ChatImageAnalysisHelper.buildConversationHistory', () {
    test('filtre les messages systeme et mappe les roles vers l API', () {
      final history = ChatImageAnalysisHelper.buildConversationHistory([
        ChatMessage(
          id: '1',
          content: 'Bonjour',
          role: ChatRole.system,
          timestamp: DateTime(2026),
        ),
        ChatMessage(
          id: '2',
          content: 'Mon vin',
          role: ChatRole.user,
          timestamp: DateTime(2026),
        ),
        ChatMessage(
          id: '3',
          content: 'Analyse',
          role: ChatRole.assistant,
          timestamp: DateTime(2026),
        ),
      ]);

      expect(history, [
        {'role': 'user', 'content': 'Mon vin'},
        {'role': 'assistant', 'content': 'Analyse'},
      ]);
    });
  });

  group('ChatImageAnalysisHelper.buildVisionParams', () {
    test('construit les params avec historique filtre', () {
      final params = ChatImageAnalysisHelper.buildVisionParams(
        imageBytes: const [1, 2, 3],
        mimeType: 'image/png',
        userMessage: 'Analyse cette image',
        messages: [
          ChatMessage(
            id: '2',
            content: 'Mon vin',
            role: ChatRole.user,
            timestamp: DateTime(2026),
          ),
        ],
      );

      expect(params.imageBytes, [1, 2, 3]);
      expect(params.mimeType, 'image/png');
      expect(params.userMessage, 'Analyse cette image');
      expect(params.conversationHistory, [
        {'role': 'user', 'content': 'Mon vin'},
      ]);
    });
  });
}