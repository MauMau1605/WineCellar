import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/reevaluate_wine_from_form_usecase.dart';

class _MockAiService extends Mock implements AiService {}

void main() {
  late _MockAiService mockAiService;
  late ReevaluateWineFromFormUseCase useCase;

  const currentData = WineAiResponse(
    name: 'Chateau Test',
    color: 'red',
    vintage: 2018,
    grapeVarieties: ['Merlot'],
    drinkFromYear: 2026,
    tastingNotes: 'Note initiale',
    estimatedFields: ['drinkFromYear', 'drinkUntilYear', 'grapeVarieties'],
    fieldSources: {
      'drinkFromYear': ['Vivino'],
      'drinkUntilYear': ['CellarTracker'],
    },
  );

  setUp(() {
    mockAiService = _MockAiService();
    useCase = ReevaluateWineFromFormUseCase(mockAiService);
  });

  group('ReevaluateWineFromFormUseCase', () {
    test(
      'returns reevaluated data while preserving locked fields and field sources',
      () async {
        when(
          () => mockAiService.analyzeWine(
            userMessage: any(named: 'userMessage'),
          ),
        ).thenAnswer(
          (_) async => const AiChatResult(
            textResponse: 'Reevaluation terminee',
            wineDataList: [
              WineAiResponse(
                name: 'Chateau Test',
                color: 'red',
                vintage: 2018,
                grapeVarieties: ['Cabernet Sauvignon', 'Merlot'],
                drinkFromYear: 2030,
                drinkUntilYear: 2042,
                tastingNotes: 'Note re-evaluee',
                estimatedFields: [
                  'drinkFromYear',
                  'drinkUntilYear',
                  'grapeVarieties',
                ],
                confidenceNotes: 'Fenetre mise a jour',
              ),
            ],
          ),
        );

        final result = await useCase(
          const ReevaluateWineFromFormParams(
            currentData: currentData,
            lockedFields: {'drinkFromYear', 'grapeVarieties'},
          ),
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('devrait etre Right'),
          (response) {
            expect(response.drinkFromYear, 2026);
            expect(response.grapeVarieties, ['Merlot']);
            expect(response.drinkUntilYear, 2042);
            expect(response.tastingNotes, 'Note re-evaluee');
            expect(response.estimatedFields, ['drinkUntilYear']);
            expect(response.fieldSources, currentData.fieldSources);
            expect(response.confidenceNotes, 'Fenetre mise a jour');
          },
        );

        final captured = verify(
          () => mockAiService.analyzeWine(
            userMessage: captureAny(named: 'userMessage'),
          ),
        ).captured.single as String;

        expect(captured, contains('drinkFromYear'));
        expect(captured, contains('grapeVarieties'));
        expect(captured, contains('Merlot'));
      },
    );

    test('returns Left(AiFailure) when ai service reports an error', () async {
      when(
        () => mockAiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
        ),
      ).thenAnswer(
        (_) async => const AiChatResult(
          textResponse: 'Erreur',
          isError: true,
          errorMessage: 'Service indisponible',
        ),
      );

      final result = await useCase(
        const ReevaluateWineFromFormParams(
          currentData: currentData,
          lockedFields: {},
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AiFailure>());
          expect(failure.message, 'Service indisponible');
        },
        (_) => fail('devrait etre Left'),
      );
    });

    test('returns Left(AiFailure) when reevaluation returns no wine data', () async {
      when(
        () => mockAiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
        ),
      ).thenAnswer(
        (_) async => const AiChatResult(
          textResponse: 'Aucune fiche retournee',
        ),
      );

      final result = await useCase(
        const ReevaluateWineFromFormParams(
          currentData: currentData,
          lockedFields: {},
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AiFailure>());
          expect(
            failure.message,
            'La réévaluation n\'a retourné aucune fiche.',
          );
        },
        (_) => fail('devrait etre Left'),
      );
    });

    test('returns Left(AiFailure) when ai service throws', () async {
      when(
        () => mockAiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
        ),
      ).thenThrow(Exception('timeout'));

      final result = await useCase(
        const ReevaluateWineFromFormParams(
          currentData: currentData,
          lockedFields: {},
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AiFailure>());
          expect(
            failure.message,
            contains('Erreur lors de la réévaluation'),
          );
        },
        (_) => fail('devrait etre Left'),
      );
    });
  });
}