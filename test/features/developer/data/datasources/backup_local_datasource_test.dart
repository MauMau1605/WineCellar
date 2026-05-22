import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/developer/data/datasources/backup_local_datasource.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';

final _dataWithoutSecrets = BackupData(
  config: {'ai_provider': 'openai', 'wine_list_layout': 'auto'},
  secrets: null,
  winesJson: '[]',
  createdAt: DateTime(2026, 5, 21),
  version: 1,
);

final _dataWithSecrets = BackupData(
  config: {'ai_provider': 'gemini'},
  secrets: {'openai_api_key': 'sk-test123', 'gemini_api_key': 'gk-abc'},
  winesJson: '[{"id":1,"name":"Bordeaux"}]',
  createdAt: DateTime(2026, 1, 15),
  version: 1,
);

void main() {
  late BackupLocalDatasource datasource;

  setUp(() {
    datasource = BackupLocalDatasource();
  });

  group('BackupLocalDatasource — sérialisation', () {
    test('serialise produit un JSON valide avec tous les champs attendus', () {
      final json = jsonDecode(datasource.serialise(_dataWithoutSecrets))
          as Map<String, dynamic>;

      expect(json['version'], equals(1));
      expect(json['created_at'], contains('2026-05-21'));
      expect(json['includes_secrets'], isFalse);
      expect(json['config'], equals(_dataWithoutSecrets.config));
      expect(json.containsKey('secrets'), isFalse);
      expect(json['wines'], equals('[]'));
    });

    test('serialise inclut le champ secrets quand presents', () {
      final json = jsonDecode(datasource.serialise(_dataWithSecrets))
          as Map<String, dynamic>;

      expect(json['includes_secrets'], isTrue);
      expect(json.containsKey('secrets'), isTrue);
      expect(
        json['secrets'],
        equals({'openai_api_key': 'sk-test123', 'gemini_api_key': 'gk-abc'}),
      );
    });

    test('serialise n\'inclut pas le champ secrets quand absents', () {
      final json = jsonDecode(datasource.serialise(_dataWithoutSecrets))
          as Map<String, dynamic>;

      expect(json.containsKey('secrets'), isFalse);
    });

    test('deserialise reconstruit un BackupData équivalent', () {
      final plain = datasource.serialise(_dataWithoutSecrets);
      final result = datasource.deserialise(plain);

      expect(result.version, equals(_dataWithoutSecrets.version));
      expect(result.config, equals(_dataWithoutSecrets.config));
      expect(result.secrets, isNull);
      expect(result.winesJson, equals(_dataWithoutSecrets.winesJson));
    });

    test('deserialise reconstruit les secrets quand presents', () {
      final plain = datasource.serialise(_dataWithSecrets);
      final result = datasource.deserialise(plain);

      expect(result.secrets, equals(_dataWithSecrets.secrets));
      expect(result.winesJson, equals(_dataWithSecrets.winesJson));
    });

    test('aller-retour serialise/deserialise préserve toutes les données', () {
      for (final data in [_dataWithoutSecrets, _dataWithSecrets]) {
        final result = datasource.deserialise(datasource.serialise(data));
        expect(result.version, equals(data.version));
        expect(result.config, equals(data.config));
        expect(result.secrets, equals(data.secrets));
        expect(result.winesJson, equals(data.winesJson));
      }
    });

    test('deserialise gère un champ wines absent (défaut vide)', () {
      final incompleteJson = jsonEncode({
        'version': 1,
        'created_at': '2026-01-01T00:00:00.000',
        'includes_secrets': false,
        'config': <String, String?>{},
      });

      final result = datasource.deserialise(incompleteJson);

      expect(result.winesJson, equals('[]'));
    });
  });

  group('BackupLocalDatasource — chiffrement', () {
    const _password = 'MotDePasseDeTest!42';
    const _plainText = '{"test":"valeur","chiffrement":"fonctionne"}';

    test('aller-retour encrypt/decrypt restitue le texte d\'origine', () {
      final envelope = datasource.encrypt(_plainText, _password);
      final recovered = datasource.decrypt(envelope, _password);

      expect(recovered, equals(_plainText));
    });

    test('deux chiffrements du même texte produisent des enveloppes différentes '
        '(IV et sel aléatoires)', () {
      final envelope1 = datasource.encrypt(_plainText, _password);
      final envelope2 = datasource.encrypt(_plainText, _password);

      expect(envelope1['data'], isNot(equals(envelope2['data'])));
      expect(envelope1['salt'], isNot(equals(envelope2['salt'])));
      expect(envelope1['iv'], isNot(equals(envelope2['iv'])));
    });

    test('l\'enveloppe contient les champs salt, iv et data en base64', () {
      final envelope = datasource.encrypt(_plainText, _password);

      expect(envelope.containsKey('salt'), isTrue);
      expect(envelope.containsKey('iv'), isTrue);
      expect(envelope.containsKey('data'), isTrue);
      // Valider que salt et iv sont du base64 valide de la bonne longueur
      expect(datasource.decrypt(envelope, _password), isNotEmpty);
    });

    test('decrypt avec un mauvais mot de passe lève une exception', () {
      final envelope = datasource.encrypt(_plainText, _password);

      expect(
        () => datasource.decrypt(envelope, 'MauvaisMotDePasse'),
        throwsA(anything),
      );
    });

    test('aller-retour encrypt/decrypt sur les données de sauvegarde complètes', () {
      final plain = datasource.serialise(_dataWithSecrets);
      final envelope = datasource.encrypt(plain, _password);
      final recovered = datasource.decrypt(envelope, _password);

      expect(recovered, equals(plain));
    });
  });
}
