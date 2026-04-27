import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_missing_json_recovery.dart';

class _MockAnalyzeWineUseCase extends Mock implements AnalyzeWineUseCase {}

class _FakeAnalyzeWineParams extends Fake implements AnalyzeWineParams {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAnalyzeWineParams());
  });

  late _MockAnalyzeWineUseCase analyzeUseCase;
  late List<String> loggedErrors;
  late List<String> loggedResponses;
  late ChatMissingJsonRecovery recovery;

  setUp(() {
    analyzeUseCase = _MockAnalyzeWineUseCase();
    loggedErrors = [];
    loggedResponses = [];
    recovery = ChatMissingJsonRecovery(
      analyzeUseCase: analyzeUseCase,
      logError: loggedErrors.add,
      logAiResponse: loggedResponses.add,
    );
  });

  group('ChatMissingJsonRecovery', () {
    test('retourne une liste vide sans appeler l IA si la reponse assistant est vide',
        () async {
      final result = await recovery.recoverWineDataIfMissing(
        baseHistory: const [],
        originalUserMessage: 'Margaux 2015',
        assistantResponse: '   ',
      );

      expect(result, isEmpty);
      verifyNever(() => analyzeUseCase(any()));
    });

    test('construit l historique de reparation et retourne les vins recuperes',
        () async {
      when(() => analyzeUseCase(any())).thenAnswer(
        (_) async => const Right(
          AiChatResult(
            textResponse: 'JSON réparé',
            wineDataList: [WineAiResponse(name: 'Margaux', vintage: 2015)],
          ),
        ),
      );

      final result = await recovery.recoverWineDataIfMissing(
        baseHistory: const [
          {'role': 'user', 'content': 'Bonjour'},
        ],
        originalUserMessage: 'Margaux 2015',
        assistantResponse: 'Réponse sans JSON',
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Margaux');
      expect(loggedResponses, ['JSON réparé']);

      final captured = verify(() => analyzeUseCase(captureAny())).captured.single
          as AnalyzeWineParams;
      expect(
        captured.userMessage,
        AiPrompts.buildMissingJsonRecoveryMessage(
          originalUserMessage: 'Margaux 2015',
          previousAssistantResponse: 'Réponse sans JSON',
        ),
      );
      expect(captured.conversationHistory, const [
        {'role': 'user', 'content': 'Bonjour'},
        {'role': 'user', 'content': 'Margaux 2015'},
        {'role': 'assistant', 'content': 'Réponse sans JSON'},
      ]);
    });

    test('retourne une liste vide et journalise l erreur si la reparation echoue',
        () async {
      when(() => analyzeUseCase(any())).thenAnswer(
        (_) async => Left(AiFailure('Service indisponible')),
      );

      final result = await recovery.recoverWineDataIfMissing(
        baseHistory: const [],
        originalUserMessage: 'Margaux 2015',
        assistantResponse: 'Réponse sans JSON',
      );

      expect(result, isEmpty);
      expect(
        loggedErrors,
        ['Échec de récupération de la fiche vin: Service indisponible'],
      );
      expect(loggedResponses, isEmpty);
    });

    test('ne journalise pas de reponse IA si aucun vin n a ete recupere',
        () async {
      when(() => analyzeUseCase(any())).thenAnswer(
        (_) async => const Right(
          AiChatResult(
            textResponse: 'Toujours pas de JSON utile',
            wineDataList: [],
          ),
        ),
      );

      final result = await recovery.recoverWineDataIfMissing(
        baseHistory: const [],
        originalUserMessage: 'Margaux 2015',
        assistantResponse: 'Réponse sans JSON',
      );

      expect(result, isEmpty);
      expect(loggedResponses, isEmpty);
    });
  });
}