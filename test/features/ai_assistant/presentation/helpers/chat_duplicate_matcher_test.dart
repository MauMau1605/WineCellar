import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_duplicate_matcher.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

void main() {
  group('ChatDuplicateMatcher.normalize', () {
    test('normalise accents, casse et espaces multiples', () {
      expect(
        ChatDuplicateMatcher.normalize('  Château   Margaux '),
        'chateau margaux',
      );
    });
  });

  group('ChatDuplicateMatcher.findPotentialDuplicate', () {
    test('trouve un doublon sur nom, millesime et producteur normalises', () {
      final duplicate = ChatDuplicateMatcher.findPotentialDuplicate(
        candidate: const WineEntity(
          name: 'Chateau Margaux',
          producer: 'Domaine Test',
          vintage: 2015,
          color: WineColor.red,
        ),
        existingWines: const [
          WineEntity(
            id: 9,
            name: 'Château Margaux',
            producer: 'Domaine Test',
            vintage: 2015,
            color: WineColor.red,
          ),
        ],
      );

      expect(duplicate, isNotNull);
      expect(duplicate!.id, 9);
    });

    test('retourne null si le producteur differe', () {
      final duplicate = ChatDuplicateMatcher.findPotentialDuplicate(
        candidate: const WineEntity(
          name: 'Chateau Margaux',
          producer: 'Domaine A',
          vintage: 2015,
          color: WineColor.red,
        ),
        existingWines: const [
          WineEntity(
            id: 9,
            name: 'Château Margaux',
            producer: 'Domaine B',
            vintage: 2015,
            color: WineColor.red,
          ),
        ],
      );

      expect(duplicate, isNull);
    });

    test('retourne null si le millesime differe', () {
      final duplicate = ChatDuplicateMatcher.findPotentialDuplicate(
        candidate: const WineEntity(
          name: 'Chateau Margaux',
          producer: 'Domaine Test',
          vintage: 2016,
          color: WineColor.red,
        ),
        existingWines: const [
          WineEntity(
            id: 9,
            name: 'Château Margaux',
            producer: 'Domaine Test',
            vintage: 2015,
            color: WineColor.red,
          ),
        ],
      );

      expect(duplicate, isNull);
    });

    test('considere les producteurs absents comme comparables entre eux', () {
      final duplicate = ChatDuplicateMatcher.findPotentialDuplicate(
        candidate: const WineEntity(
          name: 'Chateau Margaux',
          vintage: 2015,
          color: WineColor.red,
        ),
        existingWines: const [
          WineEntity(
            id: 9,
            name: 'Château Margaux',
            vintage: 2015,
            color: WineColor.red,
          ),
        ],
      );

      expect(duplicate, isNotNull);
      expect(duplicate!.id, 9);
    });
  });
}