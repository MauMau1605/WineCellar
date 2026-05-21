import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/cellar_tracker_datasource.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/cellar_tracker_result.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage mockStorage;
  late CellarTrackerDatasource datasource;

  setUp(() {
    mockStorage = _MockSecureStorage();
    datasource = CellarTrackerDatasource(mockStorage);
  });

  // ---------------------------------------------------------------------------
  // Tests de formatage (sans réseau)
  // ---------------------------------------------------------------------------

  group('formatAsMarkdown', () {
    test('retourne chaîne vide si statut != found', () {
      expect(
        CellarTrackerDatasource.formatAsMarkdown(
          CellarTrackerResult.unconfigured(),
        ),
        isEmpty,
      );
      expect(
        CellarTrackerDatasource.formatAsMarkdown(
          CellarTrackerResult.notFound(),
        ),
        isEmpty,
      );
      expect(
        CellarTrackerDatasource.formatAsMarkdown(
          CellarTrackerResult.unavailable(),
        ),
        isEmpty,
      );
    });

    test('affiche score, fenêtre et notes si présents', () {
      const result = CellarTrackerResult(
        status: CellarTrackerSourceStatus.found,
        wineName: 'Château Margaux',
        vintage: 2015,
        communityScore: 93.0,
        communityCount: 120,
        beginConsume: 2020,
        endConsume: 2035,
        notes: [
          CellarTrackerNote(rating: 95.0, note: 'Magnifique bouquet floral.'),
          CellarTrackerNote(rating: 90.0, note: 'Tannins soyeux.'),
        ],
      );

      final text = CellarTrackerDatasource.formatAsMarkdown(result);

      expect(text, contains('Château Margaux'));
      expect(text, contains('2015'));
      expect(text, contains('93 / 100'));
      expect(text, contains('120 avis'));
      expect(text, contains('2020–2035'));
      expect(text, contains('Magnifique bouquet floral.'));
      expect(text, contains('95/100'));
    });

    test('omet la fenêtre si beginConsume ou endConsume est null', () {
      const result = CellarTrackerResult(
        status: CellarTrackerSourceStatus.found,
        wineName: 'Vin test',
        communityScore: 85.0,
        beginConsume: null,
        endConsume: 2030,
      );

      final text = CellarTrackerDatasource.formatAsMarkdown(result);

      expect(text, isNot(contains('Fenêtre')));
      expect(text, contains('85 / 100'));
    });

    test('omet les notes si la liste est vide', () {
      const result = CellarTrackerResult(
        status: CellarTrackerSourceStatus.found,
        wineName: 'Vin test',
        communityScore: 88.0,
        notes: [],
      );

      final text = CellarTrackerDatasource.formatAsMarkdown(result);
      expect(text, isNot(contains('Avis CellarTracker')));
    });
  });

  // ---------------------------------------------------------------------------
  // Tests statut non configuré
  // ---------------------------------------------------------------------------

  group('searchWine — identifiants absents', () {
    test('retourne unconfigured si user est null', () async {
      when(
        () => mockStorage.read(key: AppConstants.keyCellarTrackerUser),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.read(key: AppConstants.keyCellarTrackerPassword),
      ).thenAnswer((_) async => 'pass');

      final result = await datasource.searchWine(wineName: 'Château Margaux');

      expect(result.status, CellarTrackerSourceStatus.unconfigured);
    });

    test('retourne unconfigured si password est vide', () async {
      when(
        () => mockStorage.read(key: AppConstants.keyCellarTrackerUser),
      ).thenAnswer((_) async => 'user');
      when(
        () => mockStorage.read(key: AppConstants.keyCellarTrackerPassword),
      ).thenAnswer((_) async => '');

      final result = await datasource.searchWine(wineName: 'Château Margaux');

      expect(result.status, CellarTrackerSourceStatus.unconfigured);
    });

    test('retourne unconfigured si les deux sont absents', () async {
      when(
        () => mockStorage.read(key: AppConstants.keyCellarTrackerUser),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.read(key: AppConstants.keyCellarTrackerPassword),
      ).thenAnswer((_) async => null);

      final result = await datasource.searchWine(wineName: 'Test');

      expect(result.status, CellarTrackerSourceStatus.unconfigured);
    });
  });
}
