import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/ai_assistant/data/ai_prompts.dart';

void main() {
  group('AiPrompts', () {
    group('buildFieldCompletionMessage', () {
      test('inclut le nom du vin', () {
        final message = AiPrompts.buildFieldCompletionMessage(
          wineName: 'Château Margaux',
          vintage: null,
          color: null,
          appellation: null,
          fieldsToComplete: ['region'],
        );

        expect(message, contains('Château Margaux'));
      });

      test('inclut le millésime quand fourni', () {
        final message = AiPrompts.buildFieldCompletionMessage(
          wineName: 'Test',
          vintage: 2018,
          color: null,
          appellation: null,
          fieldsToComplete: ['region'],
        );

        expect(message, contains('2018'));
      });

      test('n\'inclut pas le millésime quand null', () {
        final message = AiPrompts.buildFieldCompletionMessage(
          wineName: 'Test',
          vintage: null,
          color: null,
          appellation: null,
          fieldsToComplete: ['region'],
        );

        expect(message, isNot(contains('Millésime')));
      });

      test('inclut la couleur quand fournie', () {
        final message = AiPrompts.buildFieldCompletionMessage(
          wineName: 'Test',
          vintage: null,
          color: 'red',
          appellation: null,
          fieldsToComplete: ['region'],
        );

        expect(message, contains('red'));
      });

      test('inclut l\'appellation quand fournie', () {
        final message = AiPrompts.buildFieldCompletionMessage(
          wineName: 'Test',
          vintage: null,
          color: null,
          appellation: 'Saint-Émilion',
          fieldsToComplete: ['region'],
        );

        expect(message, contains('Saint-Émilion'));
      });

      test('liste les champs à compléter', () {
        final message = AiPrompts.buildFieldCompletionMessage(
          wineName: 'Test',
          vintage: null,
          color: null,
          appellation: null,
          fieldsToComplete: ['region', 'drinkFromYear', 'grapeVarieties'],
        );

        expect(message, contains('region'));
        expect(message, contains('drinkFromYear'));
        expect(message, contains('grapeVarieties'));
      });
    });

    group('buildGroundedReviewMessage', () {
      test('inclut la question utilisateur', () {
        final message = AiPrompts.buildGroundedReviewMessage(
          userQuestion: 'Que penses-tu du Château Margaux 2018 ?',
        );

        expect(message, contains('Château Margaux 2018'));
      });

      test('contient l\'instruction de recherche Google', () {
        final message = AiPrompts.buildGroundedReviewMessage(
          userQuestion: 'test',
        );

        expect(message, contains('recherche Google'));
      });
    });

    group('buildMissingJsonRecoveryMessage', () {
      test('inclut la demande utilisateur et la réponse précédente', () {
        final message = AiPrompts.buildMissingJsonRecoveryMessage(
          originalUserMessage: 'J\'ai acheté un Montcalmès 2019',
          previousAssistantResponse: 'Analyse cohérente sans JSON',
        );

        expect(message, contains('Montcalmès 2019'));
        expect(message, contains('Analyse cohérente sans JSON'));
      });

      test('demande uniquement un bloc json entre balises', () {
        final message = AiPrompts.buildMissingJsonRecoveryMessage(
          originalUserMessage: 'test',
          previousAssistantResponse: 'test',
        );

        expect(message, contains('UNIQUEMENT le bloc JSON final'));
        expect(message, contains('<json>'));
        expect(message, contains('</json>'));
      });
    });

    group('buildWineReviewMessage', () {
      test('inclut la question utilisateur', () {
        final message = AiPrompts.buildWineReviewMessage(
          userQuestion: 'Avis sur le Pétrus 2010 ?',
        );

        expect(message, contains('Pétrus 2010'));
      });

      test('contient les règles anti-hallucination', () {
        final message = AiPrompts.buildWineReviewMessage(
          userQuestion: 'test',
        );

        expect(message, contains('ANTI-HALLUCINATION'));
        expect(message, contains('N\'INVENTE JAMAIS'));
      });

      test('indique l\'absence d\'accès internet', () {
        final message = AiPrompts.buildWineReviewMessage(
          userQuestion: 'test',
        );

        expect(message, contains('PAS accès à internet'));
      });
    });

    group('buildCellarSearchMessage', () {
      test('inclut la question utilisateur et le résumé de la cave', () {
        final message = AiPrompts.buildCellarSearchMessage(
          userQuestion: 'Quel vin avec un gigot ?',
          cellarSummary: 'Margaux 2018 (rouge, 2 bouteilles)',
        );

        expect(message, contains('gigot'));
        expect(message, contains('Margaux 2018'));
      });

      test('contient l\'instruction de ne pas retourner de JSON', () {
        final message = AiPrompts.buildCellarSearchMessage(
          userQuestion: 'test',
          cellarSummary: 'vide',
        );

        expect(message, contains('IGNORER l\'instruction de retourner un bloc JSON'));
      });

      test('inclut l\'année actuelle', () {
        final message = AiPrompts.buildCellarSearchMessage(
          userQuestion: 'test',
          cellarSummary: 'vide',
        );

        expect(message, contains("L'année actuelle est ${DateTime.now().year}"));
      });
    });

    group('systemPrompt', () {
      test('contient les instructions estimatedFields', () {
        final prompt = AiPrompts.systemPrompt;

        expect(prompt, contains('estimatedFields'));
      });

      test('contient les instructions confidenceNotes', () {
        final prompt = AiPrompts.systemPrompt;

        expect(prompt, contains('confidenceNotes'));
      });

      test('inclut l\'année actuelle', () {
        final prompt = AiPrompts.systemPrompt;

        expect(prompt, contains("L'année actuelle est ${DateTime.now().year}"));
      });

      test('impose de terminer par un bloc json', () {
        final prompt = AiPrompts.systemPrompt;

        expect(prompt, contains('RÉPONSE OBLIGATOIRE'));
        expect(prompt, contains('<json>'));
      });
    });

    group('groundedReviewSystemPrompt', () {
      test('contient les instructions de citation des sources', () {
        final prompt = AiPrompts.groundedReviewSystemPrompt;

        expect(prompt, contains('CITE LA SOURCE'));
      });

      test('contient l\'instruction de se baser sur les résultats Google', () {
        final prompt = AiPrompts.groundedReviewSystemPrompt;

        expect(prompt, contains('résultats de recherche Google'));
      });
    });

    group('fieldCompletionSystemPrompt', () {
      test('contient l\'instruction de retourner du JSON', () {
        final prompt = AiPrompts.fieldCompletionSystemPrompt;

        expect(prompt, contains('<json>'));
      });

      test('contient l\'instruction anti-invention', () {
        final prompt = AiPrompts.fieldCompletionSystemPrompt;

        expect(prompt, contains('N\'INVENTE RIEN'));
      });
    });
  });
}
