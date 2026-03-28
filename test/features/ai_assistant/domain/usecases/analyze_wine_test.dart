import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine.dart';

class _MockAiService extends Mock implements AiService {}

void main() {
  late _MockAiService mockAiService;
  late AnalyzeWineUseCase useCase;

  setUp(() {
    mockAiService = _MockAiService();
    useCase = AnalyzeWineUseCase(mockAiService);
  });

  const successResult = AiChatResult(
    textResponse: 'Voici les infos du vin.',
    wineDataList: [WineAiResponse(name: 'Margaux', color: 'red')],
  );

  const errorResult = AiChatResult(
    textResponse: 'Erreur',
    isError: true,
    errorMessage: 'Service indisponible',
  );

  group('AnalyzeWineUseCase', () {
    group('sans recherche web', () {
      test('appelle analyzeWine et retourne Right en cas de succès', () async {
        when(() => mockAiService.analyzeWine(
              userMessage: any(named: 'userMessage'),
              conversationHistory: any(named: 'conversationHistory'),
            )).thenAnswer((_) async => successResult);

        final result = await useCase.call(const AnalyzeWineParams(
          userMessage: 'un Margaux 2018',
        ));

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('devrait être Right'),
          (r) {
            expect(r.textResponse, 'Voici les infos du vin.');
            expect(r.wineDataList.length, 1);
            expect(r.wineDataList.first.name, 'Margaux');
          },
        );

        verify(() => mockAiService.analyzeWine(
              userMessage: 'un Margaux 2018',
              conversationHistory: const [],
            )).called(1);
        verifyNever(() => mockAiService.analyzeWineWithWebSearch(
              userMessage: any(named: 'userMessage'),
              conversationHistory: any(named: 'conversationHistory'),
            ));
      });

      test('retourne AiFailure quand le résultat est en erreur', () async {
        when(() => mockAiService.analyzeWine(
              userMessage: any(named: 'userMessage'),
              conversationHistory: any(named: 'conversationHistory'),
            )).thenAnswer((_) async => errorResult);

        final result = await useCase.call(const AnalyzeWineParams(
          userMessage: 'test',
        ));

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<AiFailure>());
            expect(failure.message, 'Service indisponible');
          },
          (_) => fail('devrait être Left'),
        );
      });

      test('retourne AiFailure quand une exception est levée', () async {
        when(() => mockAiService.analyzeWine(
              userMessage: any(named: 'userMessage'),
              conversationHistory: any(named: 'conversationHistory'),
            )).thenThrow(Exception('timeout'));

        final result = await useCase.call(const AnalyzeWineParams(
          userMessage: 'test',
        ));

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<AiFailure>());
            expect(failure.message,
                'Erreur de communication avec le service IA.');
          },
          (_) => fail('devrait être Left'),
        );
      });
    });

    group('avec recherche web', () {
      test('appelle analyzeWineWithWebSearch quand useWebSearch est true',
          () async {
        when(() => mockAiService.analyzeWineWithWebSearch(
              userMessage: any(named: 'userMessage'),
              conversationHistory: any(named: 'conversationHistory'),
            )).thenAnswer((_) async => const AiChatResult(
              textResponse: 'Avis vérifié',
              webSources: [
                WebSource(uri: 'https://example.com', title: 'Example'),
              ],
            ));

        final result = await useCase.call(const AnalyzeWineParams(
          userMessage: 'avis Margaux 2018',
          useWebSearch: true,
        ));

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('devrait être Right'),
          (r) {
            expect(r.textResponse, 'Avis vérifié');
            expect(r.webSources.length, 1);
          },
        );

        verify(() => mockAiService.analyzeWineWithWebSearch(
              userMessage: 'avis Margaux 2018',
              conversationHistory: const [],
            )).called(1);
        verifyNever(() => mockAiService.analyzeWine(
              userMessage: any(named: 'userMessage'),
              conversationHistory: any(named: 'conversationHistory'),
            ));
      });

      test('retourne AiFailure quand la recherche web échoue', () async {
        when(() => mockAiService.analyzeWineWithWebSearch(
              userMessage: any(named: 'userMessage'),
              conversationHistory: any(named: 'conversationHistory'),
            )).thenAnswer((_) async => errorResult);

        final result = await useCase.call(const AnalyzeWineParams(
          userMessage: 'test',
          useWebSearch: true,
        ));

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<AiFailure>()),
          (_) => fail('devrait être Left'),
        );
      });
    });

    group('AnalyzeWineParams', () {
      test('useWebSearch est false par défaut', () {
        const params = AnalyzeWineParams(userMessage: 'test');
        expect(params.useWebSearch, isFalse);
        expect(params.conversationHistory, isEmpty);
      });

      test('conserve l\'historique de conversation', () {
        const params = AnalyzeWineParams(
          userMessage: 'test',
          conversationHistory: [
            {'role': 'user', 'content': 'hello'},
          ],
        );
        expect(params.conversationHistory.length, 1);
      });
    });
  });
}
