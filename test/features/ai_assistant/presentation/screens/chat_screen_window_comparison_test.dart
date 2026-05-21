import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/cellar_tracker_result.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/vivino_result.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_wine_sources_helper.dart';

void main() {
  group('ChatWineSourcesHelper.buildDrinkingWindowBlock', () {
    VivinoSearchResult vivinoWith(int begin, int end) => VivinoSearchResult(
          status: VivinoSourceStatus.found,
          wineName: 'Vin Test',
          ratingsAverage: 4.0,
          ratingsCount: 100,
          beginConsume: begin,
          endConsume: end,
        );

    CellarTrackerResult ctWith(int begin, int end) => CellarTrackerResult(
          status: CellarTrackerSourceStatus.found,
          wineName: 'Vin Test',
          communityScore: 88.0,
          beginConsume: begin,
          endConsume: end,
        );

    test('fenêtres identiques → affiche fenêtre commune sans avertissement', () {
      final vivino = vivinoWith(2020, 2030);
      final ct = ctWith(2020, 2030);
      final text = ChatWineSourcesHelper.buildDrinkingWindowBlock(vivino, ct);

      expect(text, contains('2020–2030'));
      expect(text, isNot(contains('divergent')));
    });

    test('fenêtres proches (diff ≤ 3 ans) → affiche intersection sans avertissement', () {
      // Vivino 2020–2030, CT 2022–2032 → diff début = 2, diff fin = 2 → ≤ 3
      final vivino = vivinoWith(2020, 2030);
      final ct = ctWith(2022, 2032);
      final text = ChatWineSourcesHelper.buildDrinkingWindowBlock(vivino, ct);

      expect(text, isNot(contains('divergent')));
      // Intersection : max(2020,2022)–min(2030,2032) = 2022–2030
      expect(text, contains('2022–2030'));
    });

    test('fenêtres divergentes (diff > 3 ans sur début) → affiche avertissement', () {
      // diff début = |2015 - 2020| = 5 > 3
      final vivino = vivinoWith(2015, 2025);
      final ct = ctWith(2020, 2030);
      final text = ChatWineSourcesHelper.buildDrinkingWindowBlock(vivino, ct);

      expect(text, contains('divergent'));
      expect(text, contains('2015–2025'));
      expect(text, contains('2020–2030'));
    });

    test('fenêtres divergentes (diff > 3 ans sur fin) → affiche avertissement', () {
      // diff fin = |2025 - 2031| = 6 > 3
      final vivino = vivinoWith(2020, 2025);
      final ct = ctWith(2020, 2031);
      final text = ChatWineSourcesHelper.buildDrinkingWindowBlock(vivino, ct);

      expect(text, contains('divergent'));
    });

    test('divergent avec intersection suffisante → affiche fenêtre commune', () {
      // diff début = 5 → divergent, intersection = max(2018,2023)–min(2030,2030) = 2023–2030 = 7 ans ≥ 2
      final vivino = vivinoWith(2018, 2030);
      final ct = ctWith(2023, 2030);
      final text = ChatWineSourcesHelper.buildDrinkingWindowBlock(vivino, ct);

      expect(text, contains('divergent'));
      expect(text, contains('Fenêtre commune retenue'));
      expect(text, contains('2023–2030'));
    });

    test('divergent sans intersection suffisante → message sans fenêtre commune', () {
      // Vivino 2010–2015, CT 2020–2025 → pas de chevauchement
      final vivino = vivinoWith(2010, 2015);
      final ct = ctWith(2020, 2025);
      final text = ChatWineSourcesHelper.buildDrinkingWindowBlock(vivino, ct);

      expect(text, contains('divergent'));
      expect(text, isNot(contains('Fenêtre commune retenue')));
      expect(text, contains('consultez les deux sources'));
    });

    test('seul Vivino a une fenêtre → label Vivino affiché', () {
      final vivino = VivinoSearchResult(
        status: VivinoSourceStatus.found,
        wineName: 'Vin Test',
        ratingsAverage: 4.0,
        beginConsume: 2020,
        endConsume: 2030,
      );
      final ct = CellarTrackerResult.unconfigured();
      final text = ChatWineSourcesHelper.buildDrinkingWindowBlock(vivino, ct);

      expect(text, contains('(Vivino)'));
      expect(text, contains('2020–2030'));
    });

    test('seul CellarTracker a une fenêtre → label CT affiché', () {
      const vivino = VivinoSearchResult(
        status: VivinoSourceStatus.found,
        wineName: 'Vin Test',
        ratingsAverage: 4.0,
      );
      const ct = CellarTrackerResult(
        status: CellarTrackerSourceStatus.found,
        wineName: 'Vin Test',
        communityScore: 88.0,
        beginConsume: 2022,
        endConsume: 2028,
      );
      final text = ChatWineSourcesHelper.buildDrinkingWindowBlock(vivino, ct);

      expect(text, contains('(CellarTracker)'));
      expect(text, contains('2022–2028'));
    });

    test('aucune fenêtre disponible → chaîne vide', () {
      const vivino = VivinoSearchResult(
        status: VivinoSourceStatus.found,
        wineName: 'Vin Test',
        ratingsAverage: 4.0,
      );
      const ct = CellarTrackerResult(
        status: CellarTrackerSourceStatus.found,
        wineName: 'Vin Test',
        communityScore: 88.0,
      );
      final text = ChatWineSourcesHelper.buildDrinkingWindowBlock(vivino, ct);

      expect(text, isEmpty);
    });
  });

  group('ChatWineSourcesHelper.buildCombinedReviewMarkdown', () {
    test('inclut en-tête des notes si Vivino et CT trouvés', () {
      const vivino = VivinoSearchResult(
        status: VivinoSourceStatus.found,
        wineName: 'Château Margaux',
        vintage: 2015,
        ratingsAverage: 4.5,
        ratingsCount: 12000,
      );
      const ct = CellarTrackerResult(
        status: CellarTrackerSourceStatus.found,
        wineName: 'Château Margaux',
        communityScore: 94.0,
        communityCount: 85,
      );

      final text = ChatWineSourcesHelper.buildCombinedReviewMarkdown(vivino, ct);

      expect(text, contains('Notes moyennes'));
      expect(text, contains('4.5 / 5'));
      expect(text, contains('94 / 100'));
    });

    test('affiche uniquement Vivino si CT non configuré', () {
      const vivino = VivinoSearchResult(
        status: VivinoSourceStatus.found,
        wineName: 'Vosne-Romanée',
        ratingsAverage: 4.3,
        ratingsCount: 500,
      );
      final ct = CellarTrackerResult.unconfigured();

      final text = ChatWineSourcesHelper.buildCombinedReviewMarkdown(vivino, ct);

      expect(text, contains('4.3 / 5'));
      expect(text, isNot(contains('CellarTracker')));
    });
  });
}
