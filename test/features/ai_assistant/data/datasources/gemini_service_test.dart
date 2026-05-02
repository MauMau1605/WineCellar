import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/gemini_service.dart';

void main() {
  group('GeminiService', () {
    test('analyzeWineWithWebSearch envoie la requête attendue et extrait les sources',
        () async {
      late HttpServer server;
      late Map<String, dynamic> capturedPayload;
      late Map<String, String> capturedQueryParameters;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        capturedQueryParameters = request.uri.queryParameters;
        final raw = await utf8.decoder.bind(request).join();
        capturedPayload = jsonDecode(raw) as Map<String, dynamic>;

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Synthèse web validée'},
                    ],
                  },
                  'groundingMetadata': {
                    'groundingChunks': [
                      {
                        'web': {
                          'uri': 'https://example.com/source',
                          'title': 'Source test',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
          );
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final service = GeminiService(
        apiKey: 'gem-key',
        model: 'gemini-test',
        dioFactory: (options) => Dio(
          BaseOptions(
            baseUrl: baseUri.toString(),
            connectTimeout: options.connectTimeout,
            receiveTimeout: options.receiveTimeout,
          ),
        ),
        enableLogging: false,
      );

      final result = await service.analyzeWineWithWebSearch(
        userMessage: 'Recherche des infos fiables',
        conversationHistory: const [
          {'role': 'assistant', 'content': 'Contexte'},
        ],
        systemPromptOverride: 'Prompt dédié',
      );

      expect(service.supportsWebSearch, isTrue);
      expect(result.isError, isFalse);
      expect(result.textResponse, 'Synthèse web validée');
      expect(result.webSources.single.uri, 'https://example.com/source');
      expect(result.webSources.single.title, 'Source test');
      expect(capturedQueryParameters['key'], 'gem-key');
      expect(capturedPayload['systemInstruction']['parts'][0]['text'], 'Prompt dédié');
      expect(capturedPayload['tools'], [
        {'google_search': {}},
      ]);
    });

    test('analyzeWineWithWebSearch mappe une 429 en message utilisateur',
        () async {
      late HttpServer server;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        request.response
          ..statusCode = 429
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': {'message': 'quota exceeded'}}));
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final service = GeminiService(
        apiKey: 'gem-key',
        dioFactory: (options) => Dio(BaseOptions(baseUrl: baseUri.toString())),
        enableLogging: false,
      );

      final result = await service.analyzeWineWithWebSearch(
        userMessage: 'Recherche',
      );

      expect(result.isError, isTrue);
      expect(
        result.errorMessage,
        'Limite de requêtes Gemini atteinte. Attendez quelques minutes.',
      );
    });

    test('analyzeWineWithWebSearch remonte le détail d erreur Gemini', () async {
      late HttpServer server;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        request.response
          ..statusCode = 400
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': {'message': 'invalid prompt'}}));
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final service = GeminiService(
        apiKey: 'gem-key',
        dioFactory: (options) => Dio(BaseOptions(baseUrl: baseUri.toString())),
        enableLogging: false,
      );

      final result = await service.analyzeWineWithWebSearch(
        userMessage: 'Recherche',
      );

      expect(result.isError, isTrue);
      expect(result.errorMessage, 'Erreur Gemini: invalid prompt');
    });

    test('discoverVisionModel retourne simplement le modèle configuré', () async {
      final service = GeminiService(apiKey: 'gem-key', model: 'gemini-2.0-flash');

      expect(await service.discoverVisionModel(), 'gemini-2.0-flash');
    });
  });
}