import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_request_strategy.dart';

void main() {
  group('AiRequestStrategy.decideWebSearchForWineCompletion', () {
    test('desactive la recherche web si le nom du vin est absent', () {
      const wine = WineAiResponse(
        name: '   ',
        vintage: 2022,
        estimatedFields: ['producer'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isFalse);
      expect(decision.reason, 'Nom du vin absent.');
    });

    test('active la recherche web pour des champs critiques avec identite suffisante', () {
      const wine = WineAiResponse(
        name: 'Chateau Test',
        vintage: 2019,
        estimatedFields: ['producer', 'drinkUntilYear'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isTrue);
    });

    test('active la recherche web pour 3+ champs estimés même si faible valeur', () {
      const wine = WineAiResponse(
        name: 'Sancerre Test',
        vintage: 2022,
        estimatedFields: ['country', 'region', 'grapeVarieties'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isTrue);
    });

    test('desactive la recherche web si moins de 3 champs estimés sans champ critique', () {
      const wine = WineAiResponse(
        name: 'Sancerre Test',
        vintage: 2022,
        estimatedFields: ['country', 'region'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isFalse);
    });

    test('desactive la recherche web sans signaux d identite', () {
      const wine = WineAiResponse(
        name: 'Vin inconnu',
        estimatedFields: ['producer', 'drinkFromYear'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isFalse);
    });

    test('active la recherche web si le producteur suffit a identifier le vin', () {
      const wine = WineAiResponse(
        name: 'Cuvee Test',
        producer: 'Domaine Exemple',
        estimatedFields: ['drinkFromYear'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isTrue);
      expect(
        decision.reason,
        'Champs critiques à confirmer via sources web.',
      );
    });

    test(
        'active la recherche web pour un vin recent sans fenetre de degustation '
        'meme si estimatedFields est vide', () {
      // Régression : vin récent (≤ 3 ans) → modèle refuse d'estimer
      // drinkFromYear/Until → estimatedFields vide → la recherche internet
      // ne se lançait pas.
      final recentVintage = DateTime.now().year - 2;
      final wine = WineAiResponse(
        name: 'Chateau Petrus',
        vintage: recentVintage,
        appellation: 'Pomerol',
        producer: 'Chateau Petrus',
        // drinkFromYear / drinkUntilYear intentionnellement null
        estimatedFields: const [],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isTrue);
    });

    test(
        'active la recherche web pour un vin recent sans fenetre de degustation '
        'avec quelques champs estimes non critiques', () {
      final recentVintage = DateTime.now().year - 1;
      final wine = WineAiResponse(
        name: 'Domaine de la Romanee-Conti',
        vintage: recentVintage,
        appellation: 'Vosne-Romanee',
        // drinkFromYear / drinkUntilYear intentionnellement null
        estimatedFields: const ['region'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isTrue);
    });

    test(
        'desactive la recherche web quand fenetre de degustation absente '
        'mais millésime trop ancien pour etre bloque par la règle recent', () {
      // Millésime > 3 ans : le modèle AURAIT dû estimer → pas de règle spéciale.
      // estimatedFields vide → pas de recherche.
      final oldVintage = DateTime.now().year - 5;
      final wine = WineAiResponse(
        name: 'Vin ancien',
        vintage: oldVintage,
        appellation: 'Bordeaux',
        estimatedFields: const [],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isFalse);
    });

    test(
        'desactive la recherche web quand fenetre de degustation absente '
        'mais millésime inconnu', () {
      // Sans millésime, on ne peut pas utiliser la règle des vins récents.
      const wine = WineAiResponse(
        name: 'Vin sans millesime',
        appellation: 'Bordeaux',
        // vintage intentionnellement null
        estimatedFields: [],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isFalse);
    });
  });

  group('AiRequestStrategy.detectAddWineMessageIntent', () {
    test('retourne newWine quand aucune fiche en cours', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'J ai achete un Chablis 2020',
        currentWineData: const [],
      );

      expect(intent, AddWineMessageIntent.newWine);
    });

    test('retourne refineCurrentWine pour message de correction explicite', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'En fait le millesime est 2018',
        currentWineData: const [
          WineAiResponse(name: 'Cotes du Rhone', vintage: 2020),
        ],
      );

      expect(intent, AddWineMessageIntent.refineCurrentWine);
    });

    test('retourne newWine pour message explicite nouveau vin', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'Nouveau vin: Domaine X 2019',
        currentWineData: const [
          WineAiResponse(name: 'Premier vin', vintage: 2021),
        ],
      );

      expect(intent, AddWineMessageIntent.newWine);
    });

    test('retourne unclear pour un message vide si un vin est deja en cours', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: '   ',
        currentWineData: const [
          WineAiResponse(name: 'Premier vin', vintage: 2021),
        ],
      );

      expect(intent, AddWineMessageIntent.unclear);
    });

    test('normalise accents et apostrophes pour detecter un nouveau vin', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'J’ai achete un autre vin : Chablis 2020',
        currentWineData: const [
          WineAiResponse(name: 'Premier vin', vintage: 2021),
        ],
      );

      expect(intent, AddWineMessageIntent.newWine);
    });

    test('priorise newWine quand des marqueurs new et refine coexistent', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'En fait je veux ajouter un autre vin, un Chablis 2021',
        currentWineData: const [
          WineAiResponse(name: 'Premier vin', vintage: 2021),
        ],
      );

      expect(intent, AddWineMessageIntent.newWine);
    });

    test('retourne newWine pour millesime et identite implicite', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'Bordeaux 2019',
        currentWineData: const [
          WineAiResponse(name: 'Premier vin', vintage: 2021),
        ],
      );

      expect(intent, AddWineMessageIntent.newWine);
    });

    test('retourne unclear pour message ambigu', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'ok merci',
        currentWineData: const [
          WineAiResponse(name: 'Premier vin', vintage: 2021),
        ],
      );

      expect(intent, AddWineMessageIntent.unclear);
    });
  });
}
