import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_request_strategy.dart';

class ChatAddIntentResolution {
  final ChatAddIntentResolutionType type;
  final AddWineMessageIntent? intent;

  const ChatAddIntentResolution._({required this.type, this.intent});

  const ChatAddIntentResolution.resolved({required AddWineMessageIntent intent})
    : this._(type: ChatAddIntentResolutionType.resolved, intent: intent);

  const ChatAddIntentResolution.needsClarification()
    : this._(type: ChatAddIntentResolutionType.needsClarification);
}

enum ChatAddIntentResolutionType { resolved, needsClarification }

class ChatAddIntentHelper {
  ChatAddIntentHelper._();

  static const clarificationDialogTitle = 'Précision ou nouveau vin ?';
  static const clarificationDialogMessage =
      'Je ne suis pas sûr de l intention de ce message.\n'
      'Souhaitez-vous corriger le vin en cours ou démarrer un nouveau vin ?';

  static ChatAddIntentResolution resolve({
    required String userMessage,
    required List<WineAiResponse> currentWineData,
  }) {
    final detected = AiRequestStrategy.detectAddWineMessageIntent(
      userMessage: userMessage,
      currentWineData: currentWineData,
    );

    if (detected == AddWineMessageIntent.unclear) {
      return const ChatAddIntentResolution.needsClarification();
    }

    return ChatAddIntentResolution.resolved(intent: detected);
  }
}