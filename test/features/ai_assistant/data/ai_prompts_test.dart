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

    group('buildAddWineImageMessage', () {
      test('demande le format JSON habituel', () {
        final message = AiPrompts.buildAddWineImageMessage();

        expect(message, contains('format JSON habituel'));
      });

      test('inclut le texte OCR quand fourni', () {
        final message = AiPrompts.buildAddWineImageMessage(
          extractedText: 'Chateau Margaux 2018',
        );

        expect(message, contains('Texte OCR extrait'));
        expect(message, contains('Chateau Margaux 2018'));
      });
    });

    group('buildFoodPairingFromImageMessage', () {
      test('interdit explicitement le JSON', () {
        final message = AiPrompts.buildFoodPairingFromImageMessage();

        expect(message, contains('Ne retourne PAS de bloc JSON'));
      });

      test('demande des suggestions de plats', () {
        final message = AiPrompts.buildFoodPairingFromImageMessage();

        expect(message, contains('suggestions de plats'));
      });
    });

    group('buildWineReviewFromImageMessage', () {
      test('interdit explicitement le JSON', () {
        final message = AiPrompts.buildWineReviewFromImageMessage();

        expect(message, contains('Ne retourne PAS de bloc JSON'));
      });

      test('interdit d\'inventer des notes chiffrées', () {
        final message = AiPrompts.buildWineReviewFromImageMessage();

        expect(message, contains('N\'invente jamais de notes chiffrées'));
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

    group('buildCsvMappingPrompt', () {
      test('inclut toutes les lignes de preview', () {
        final prompt = AiPrompts.buildCsvMappingPrompt(
          previewRows: [
            ['Nom', 'Millésime', 'Couleur'],
            ['Margaux', '2018', 'rouge'],
          ],
        );

        expect(prompt, contains('Ligne 1: Nom | Millésime | Couleur'));
        expect(prompt, contains('Ligne 2: Margaux | 2018 | rouge'));
      });

      test('utilise allRows quand fourni pour analyser plus de lignes', () {
        final previewRows = [
          ['Ligne A'],
          ['Ligne B'],
        ];
        final allRows = [
          ['Ligne A'],
          ['Ligne B'],
          ['Ligne C'],
          ['Ligne D'],
          ['Nom', 'Millésime'],
          ['Margaux', '2018'],
        ];

        final prompt = AiPrompts.buildCsvMappingPrompt(
          previewRows: previewRows,
          allRows: allRows,
        );

        // Doit contenir les 6 lignes de allRows, pas seulement 2 de previewRows
        expect(prompt, contains('6 lignes'));
        expect(prompt, contains('Ligne 5: Nom | Millésime'));
        expect(prompt, contains('Ligne 6: Margaux | 2018'));
      });

      test('fallback sur previewRows quand allRows est null', () {
        final prompt = AiPrompts.buildCsvMappingPrompt(
          previewRows: [
            ['A', 'B'],
            ['C', 'D'],
          ],
          allRows: null,
        );

        expect(prompt, contains('2 lignes'));
        expect(prompt, contains('Ligne 1: A | B'));
      });

      test('demande de parcourir toutes les lignes pour trouver l\'en-tête', () {
        final prompt = AiPrompts.buildCsvMappingPrompt(
          previewRows: [
            ['test'],
          ],
        );

        expect(prompt, contains('TOUTES les lignes'));
        expect(prompt, contains('métadonnées'));
      });

      test('contient les noms de champs attendus', () {
        final prompt = AiPrompts.buildCsvMappingPrompt(
          previewRows: [
            ['test'],
          ],
        );

        expect(prompt, contains('name'));
        expect(prompt, contains('vintage'));
        expect(prompt, contains('producer'));
        expect(prompt, contains('purchasePrice'));
      });

      test('demande de valider le mapping avec les données', () {
        final prompt = AiPrompts.buildCsvMappingPrompt(
          previewRows: [
            ['Nom', 'Millésime'],
            ['Margaux', '2018'],
          ],
        );

        expect(prompt, contains('contenu des lignes de données'));
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
