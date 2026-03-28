import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';

void main() {
  group('WineAiResponse', () {
    group('isComplete', () {
      test('retourne true quand name et color sont renseignés', () {
        const response = WineAiResponse(name: 'Margaux', color: 'red');
        expect(response.isComplete, isTrue);
      });

      test('retourne false quand name est null', () {
        const response = WineAiResponse(color: 'red');
        expect(response.isComplete, isFalse);
      });

      test('retourne false quand color est null', () {
        const response = WineAiResponse(name: 'Margaux');
        expect(response.isComplete, isFalse);
      });

      test('retourne false quand les deux sont null', () {
        const response = WineAiResponse();
        expect(response.isComplete, isFalse);
      });
    });

    group('fromJson', () {
      test('parse tous les champs correctement', () {
        final json = {
          'name': 'Château Margaux',
          'appellation': 'Margaux',
          'producer': 'Château Margaux',
          'region': 'Bordeaux',
          'country': 'France',
          'color': 'red',
          'vintage': 2018,
          'grapeVarieties': ['Cabernet Sauvignon', 'Merlot'],
          'quantity': 2,
          'purchasePrice': 350.0,
          'drinkFromYear': 2025,
          'drinkUntilYear': 2045,
          'tastingNotes': 'Puissant et élégant',
          'suggestedFoodPairings': ['Agneau', 'Fromage'],
          'description': 'Grand cru classé',
          'needsMoreInfo': false,
          'followUpQuestion': null,
          'estimatedFields': ['drinkFromYear', 'drinkUntilYear'],
          'confidenceNotes': 'Fenêtre estimée sur la base de l\'appellation',
        };

        final response = WineAiResponse.fromJson(json);

        expect(response.name, 'Château Margaux');
        expect(response.appellation, 'Margaux');
        expect(response.producer, 'Château Margaux');
        expect(response.region, 'Bordeaux');
        expect(response.country, 'France');
        expect(response.color, 'red');
        expect(response.vintage, 2018);
        expect(response.grapeVarieties, ['Cabernet Sauvignon', 'Merlot']);
        expect(response.quantity, 2);
        expect(response.purchasePrice, 350.0);
        expect(response.drinkFromYear, 2025);
        expect(response.drinkUntilYear, 2045);
        expect(response.tastingNotes, 'Puissant et élégant');
        expect(response.suggestedFoodPairings, ['Agneau', 'Fromage']);
        expect(response.description, 'Grand cru classé');
        expect(response.needsMoreInfo, isFalse);
        expect(response.followUpQuestion, isNull);
        expect(
          response.estimatedFields,
          ['drinkFromYear', 'drinkUntilYear'],
        );
        expect(response.confidenceNotes,
            'Fenêtre estimée sur la base de l\'appellation');
      });

      test('utilise les valeurs par défaut pour les champs absents', () {
        final response = WineAiResponse.fromJson({});

        expect(response.name, isNull);
        expect(response.grapeVarieties, isEmpty);
        expect(response.suggestedFoodPairings, isEmpty);
        expect(response.needsMoreInfo, isFalse);
        expect(response.estimatedFields, isEmpty);
        expect(response.confidenceNotes, isNull);
      });

      test('parse purchasePrice depuis un int', () {
        final response = WineAiResponse.fromJson({'purchasePrice': 15});
        expect(response.purchasePrice, 15.0);
      });
    });

    group('toJson', () {
      test('sérialise et désérialise de manière symétrique', () {
        const original = WineAiResponse(
          name: 'Test',
          color: 'white',
          vintage: 2020,
          estimatedFields: ['region'],
          confidenceNotes: 'Basé sur le cépage',
        );

        final json = original.toJson();
        final restored = WineAiResponse.fromJson(json);

        expect(restored.name, original.name);
        expect(restored.color, original.color);
        expect(restored.vintage, original.vintage);
        expect(restored.estimatedFields, original.estimatedFields);
        expect(restored.confidenceNotes, original.confidenceNotes);
      });
    });

    group('mergeWith', () {
      test('complète les champs null avec ceux de other', () {
        const base = WineAiResponse(
          name: 'Margaux',
          color: 'red',
          vintage: 2018,
          estimatedFields: ['region', 'appellation'],
        );
        const completion = WineAiResponse(
          region: 'Bordeaux',
          appellation: 'Margaux AOC',
        );

        final merged = base.mergeWith(completion);

        expect(merged.name, 'Margaux');
        expect(merged.color, 'red');
        expect(merged.vintage, 2018);
        expect(merged.region, 'Bordeaux');
        expect(merged.appellation, 'Margaux AOC');
      });

      test('conserve name, color et vintage de la base', () {
        const base = WineAiResponse(
          name: 'Original',
          color: 'red',
          vintage: 2018,
        );
        const completion = WineAiResponse(
          name: 'Override',
          color: 'white',
          vintage: 2020,
        );

        final merged = base.mergeWith(completion);

        expect(merged.name, 'Original');
        expect(merged.color, 'red');
        expect(merged.vintage, 2018);
      });

      test('remplace grapeVarieties si other est non vide', () {
        const base = WineAiResponse(
          name: 'Test',
          grapeVarieties: ['Merlot'],
          estimatedFields: ['grapeVarieties'],
        );
        const completion = WineAiResponse(
          grapeVarieties: ['Cabernet Sauvignon', 'Merlot', 'Petit Verdot'],
        );

        final merged = base.mergeWith(completion);

        expect(merged.grapeVarieties,
            ['Cabernet Sauvignon', 'Merlot', 'Petit Verdot']);
      });

      test('garde grapeVarieties de base si other est vide', () {
        const base = WineAiResponse(
          name: 'Test',
          grapeVarieties: ['Merlot'],
        );
        const completion = WineAiResponse();

        final merged = base.mergeWith(completion);

        expect(merged.grapeVarieties, ['Merlot']);
      });

      test('retire les champs complétés de estimatedFields', () {
        const base = WineAiResponse(
          name: 'Test',
          estimatedFields: ['region', 'appellation', 'drinkFromYear'],
        );
        const completion = WineAiResponse(
          region: 'Bordeaux',
          drinkFromYear: 2025,
        );

        final merged = base.mergeWith(completion);

        expect(merged.estimatedFields, ['appellation']);
      });
    });

    group('fieldWasCompleted', () {
      test('retourne true pour appellation non null', () {
        const other = WineAiResponse(appellation: 'Margaux');
        expect(WineAiResponse.fieldWasCompleted('appellation', other), isTrue);
      });

      test('retourne false pour appellation null', () {
        const other = WineAiResponse();
        expect(
            WineAiResponse.fieldWasCompleted('appellation', other), isFalse);
      });

      test('retourne true pour grapeVarieties non vide', () {
        const other = WineAiResponse(grapeVarieties: ['Syrah']);
        expect(WineAiResponse.fieldWasCompleted('grapeVarieties', other),
            isTrue);
      });

      test('retourne false pour grapeVarieties vide', () {
        const other = WineAiResponse();
        expect(WineAiResponse.fieldWasCompleted('grapeVarieties', other),
            isFalse);
      });

      test('retourne true pour region non null', () {
        const other = WineAiResponse(region: 'Bordeaux');
        expect(WineAiResponse.fieldWasCompleted('region', other), isTrue);
      });

      test('retourne true pour drinkFromYear non null', () {
        const other = WineAiResponse(drinkFromYear: 2025);
        expect(
            WineAiResponse.fieldWasCompleted('drinkFromYear', other), isTrue);
      });

      test('retourne true pour drinkUntilYear non null', () {
        const other = WineAiResponse(drinkUntilYear: 2035);
        expect(
            WineAiResponse.fieldWasCompleted('drinkUntilYear', other), isTrue);
      });

      test('retourne true pour tastingNotes non null', () {
        const other = WineAiResponse(tastingNotes: 'Fruité');
        expect(
            WineAiResponse.fieldWasCompleted('tastingNotes', other), isTrue);
      });

      test('retourne true pour country non null', () {
        const other = WineAiResponse(country: 'France');
        expect(WineAiResponse.fieldWasCompleted('country', other), isTrue);
      });

      test('retourne true pour producer non null', () {
        const other = WineAiResponse(producer: 'Domaine X');
        expect(WineAiResponse.fieldWasCompleted('producer', other), isTrue);
      });

      test('retourne false pour un champ inconnu', () {
        const other = WineAiResponse(name: 'Test');
        expect(
            WineAiResponse.fieldWasCompleted('unknownField', other), isFalse);
      });
    });
  });
}
