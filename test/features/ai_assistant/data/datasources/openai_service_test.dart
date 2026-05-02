import 'dart:convert';
import 'dart:io';

import 'package:dart_openai/dart_openai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/openai_service.dart';

void main() {
  group('OpenAiService', () {
    test('analyzeWine construit les messages et extrait le JSON', () async {
      late List<OpenAIChatCompletionChoiceMessageModel> capturedMessages;

      final service = OpenAiService(
        apiKey: 'test-key',
        model: 'gpt-custom',
        chatCompletionRunner: ({
          required model,
          required messages,
          required temperature,
          required maxTokens,
        }) async {
          capturedMessages = messages;
          expect(model, 'gpt-custom');
          expect(temperature, 0.3);
          expect(maxTokens, 4000);
          return 'Réponse texte.\n<json>{"wines":[{"name":"Pomerol","color":"red"}]}</json>';
        },
      );

      final result = await service.analyzeWine(
        userMessage: 'Analyse ce vin',
        conversationHistory: const [
          {'role': 'assistant', 'content': 'Contexte précédent'},
        ],
      );

      expect(result.isError, isFalse);
      expect(result.textResponse, 'Réponse texte.');
      expect(result.wineDataList.single.name, 'Pomerol');
      expect(result.wineDataList.single.color, 'red');
      expect(capturedMessages, hasLength(3));
      expect(capturedMessages[0].role, OpenAIChatMessageRole.system);
      expect(capturedMessages[1].role, OpenAIChatMessageRole.assistant);
      expect(capturedMessages[2].role, OpenAIChatMessageRole.user);
    });

    test('testConnection retourne false si le runner échoue', () async {
      final service = OpenAiService(
        apiKey: 'test-key',
        chatCompletionRunner: ({
          required model,
          required messages,
          required temperature,
          required maxTokens,
        }) async {
          throw Exception('boom');
        },
      );

      expect(await service.testConnection(), isFalse);
    });

    test('analyzeWineFromImage retente avec un modèle vision découvert',
        () async {
      late HttpServer server;
      final requests = <Map<String, dynamic>>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        if (request.uri.path == '/v1/models') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'data': [{'id': 'gpt-4o-mini'}]}));
          await request.response.close();
          return;
        }

        if (request.uri.path == '/v1/chat/completions') {
          final raw = await utf8.decoder.bind(request).join();
          final payload = jsonDecode(raw) as Map<String, dynamic>;
          requests.add(payload);

          if (payload['model'] == 'gpt-legacy') {
            request.response
              ..statusCode = 400
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'error': {'message': 'unsupported model'}}));
            await request.response.close();
            return;
          }

          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': 'OK\n<json>{"name":"Margaux","color":"red"}</json>',
                    },
                  },
                ],
              }),
            );
          await request.response.close();
          return;
        }

        request.response.statusCode = 404;
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final service = OpenAiService(
        apiKey: 'test-key',
        model: 'gpt-legacy',
        dioFactory: (options) => Dio(
          BaseOptions(
            baseUrl: baseUri.toString(),
            connectTimeout: options.connectTimeout,
            receiveTimeout: options.receiveTimeout,
            headers: options.headers,
          ),
        ),
      );

      final result = await service.analyzeWineFromImage(
        imageBytes: const [1, 2, 3],
        mimeType: 'image/png',
      );

      expect(result.isError, isFalse);
      expect(result.wineDataList.single.name, 'Margaux');
      expect(requests.map((request) => request['model']).toList(), ['gpt-legacy', 'gpt-4o-mini']);

      final userContent = requests.last['messages'][1]['content'] as List<dynamic>;
      final imageUrl = userContent[1]['image_url']['url'] as String;
      expect(imageUrl, startsWith('data:image/png;base64,'));
    });

    test('discoverVisionModel met en cache le premier modèle préféré trouvé',
        () async {
      late HttpServer server;
      var modelsCallCount = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        if (request.uri.path == '/v1/models') {
          modelsCallCount += 1;
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'data': [
                  {'id': 'text-embedding-3-small'},
                  {'id': 'gpt-4.1-mini'},
                ],
              }),
            );
          await request.response.close();
          return;
        }

        request.response.statusCode = 404;
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final service = OpenAiService(
        apiKey: 'test-key',
        dioFactory: (options) => Dio(
          BaseOptions(baseUrl: baseUri.toString(), headers: options.headers),
        ),
      );

      expect(await service.discoverVisionModel(), 'gpt-4.1-mini');
      expect(await service.discoverVisionModel(), 'gpt-4.1-mini');
      expect(modelsCallCount, 1);
    });

    test('analyzeWineFromImage mappe une 401 en message explicite', () async {
      late HttpServer server;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        request.response
          ..statusCode = 401
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': {'message': 'bad key'}}));
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final service = OpenAiService(
        apiKey: 'bad-key',
        dioFactory: (options) => Dio(
          BaseOptions(baseUrl: baseUri.toString(), headers: options.headers),
        ),
      );

      final result = await service.analyzeWineFromImage(
        imageBytes: const [1],
        mimeType: 'image/jpeg',
      );

      expect(result.isError, isTrue);
      expect(
        result.errorMessage,
        'Clé API OpenAI invalide. Vérifiez votre clé dans les paramètres.',
      );
    });
  });
}