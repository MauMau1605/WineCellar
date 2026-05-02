import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/ollama_service.dart';

void main() {
  group('OllamaService', () {
    late HttpServer server;
    late Uri baseUri;
    late List<Map<String, dynamic>> chatRequests;
    late String chatResponseContent;

    setUp(() async {
      chatRequests = [];
      chatResponseContent =
          'Analyse terminée.\n<json>{"wines":[{"name":"Bordeaux","color":"red"}]}</json>';

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        if (request.uri.path == '/api/chat' && request.method == 'POST') {
          final raw = await utf8.decoder.bind(request).join();
          chatRequests.add(jsonDecode(raw) as Map<String, dynamic>);

          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'message': {'content': chatResponseContent},
              }),
            );
          await request.response.close();
          return;
        }

        if (request.uri.path == '/api/tags' && request.method == 'GET') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'models': [{'name': 'llama3'}]}));
          await request.response.close();
          return;
        }

        request.response.statusCode = 404;
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('analyzeWine envoie le bon payload et extrait le JSON structuré',
        () async {
      final service = OllamaService(
        baseUrl: baseUri.toString(),
        model: 'llama3.2',
      );

      final result = await service.analyzeWine(
        userMessage: 'Analyse cette bouteille',
        conversationHistory: const [
          {'role': 'assistant', 'content': 'Contexte précédent'},
        ],
      );

      expect(result.isError, isFalse);
      expect(result.textResponse, 'Analyse terminée.');
      expect(result.wineDataList, hasLength(1));
      expect(result.wineDataList.single.name, 'Bordeaux');
      expect(result.wineDataList.single.color, 'red');

      expect(chatRequests, hasLength(1));
      expect(chatRequests.single['model'], 'llama3.2');
      expect(chatRequests.single['stream'], isFalse);
      expect(chatRequests.single['messages'], isA<List<dynamic>>());

      final messages = chatRequests.single['messages'] as List<dynamic>;
      expect(messages[0]['role'], 'system');
      expect(messages[1]['role'], 'assistant');
      expect(messages[2]['role'], 'user');
      expect(messages[2]['content'], 'Analyse cette bouteille');
    });

    test('analyzeWineWithWebSearch délègue à analyzeWine', () async {
      chatResponseContent = 'Réponse simple';
      final service = OllamaService(baseUrl: baseUri.toString());

      final result = await service.analyzeWineWithWebSearch(
        userMessage: 'Recherche web demandée',
      );

      expect(service.supportsWebSearch, isFalse);
      expect(result.isError, isFalse);
      expect(result.textResponse, 'Réponse simple');
      expect(chatRequests, hasLength(1));
      expect((chatRequests.single['messages'] as List<dynamic>).last['content'],
          'Recherche web demandée');
    });

    test('testConnection interroge /api/tags et discoverVisionModel reste null',
        () async {
      final service = OllamaService(baseUrl: baseUri.toString());

      expect(await service.testConnection(), isTrue);
      expect(await service.discoverVisionModel(), isNull);
    });

    test('analyzeWineFromImage retourne l erreur d indisponibilité explicite',
        () async {
      final service = OllamaService(baseUrl: baseUri.toString());

      final result = await service.analyzeWineFromImage(
        imageBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
      );

      expect(result.isError, isTrue);
      expect(
        result.errorMessage,
        'L\'analyse d\'image directe n\'est pas disponible avec le provider Ollama actuellement.',
      );
    });

    test('retourne un message clair si Ollama est inaccessible', () async {
      final service = OllamaService(baseUrl: 'http://127.0.0.1:1');

      final result = await service.analyzeWine(userMessage: 'Ping');

      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Impossible de se connecter à Ollama'));
      expect(await service.testConnection(), isFalse);
    });
  });
}