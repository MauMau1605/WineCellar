import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/mistral_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';

void main() {
  group('MistralService', () {
    test('analyzeWine envoie response_format et conserve un historique nettoyé',
        () async {
      late HttpServer server;
      final chatRequests = <Map<String, dynamic>>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        if (request.uri.path == '/v1/chat/completions') {
          final raw = await utf8.decoder.bind(request).join();
          final payload = jsonDecode(raw) as Map<String, dynamic>;
          chatRequests.add(payload);

          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': 'Réponse\n<json>{"name":"Cahors","color":"red"}</json>',
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

      final service = MistralService(
        apiKey: 'test-key',
        model: 'mistral-test',
        dio: Dio(
          BaseOptions(baseUrl: baseUri.toString()),
        ),
        enableLogging: false,
      );

      final first = await service.analyzeWine(
        userMessage: 'Premier ${AiPrompts.forceJsonOnlyToken} message',
        conversationHistory: const [
          {'role': 'assistant', 'content': 'ignored history'},
        ],
      );
      final second = await service.analyzeWine(
        userMessage: 'Deuxième message',
        conversationHistory: const [
          {'role': 'user', 'content': 'should be ignored'},
        ],
      );

      expect(first.isError, isFalse);
      expect(first.wineDataList.single.name, 'Cahors');
      expect(second.isError, isFalse);

      expect(chatRequests.first['response_format'], {'type': 'json_object'});
      final secondMessages = chatRequests.last['messages'] as List<dynamic>;
      expect(secondMessages[1]['content'], 'Premier  message'.trim());
      expect(secondMessages[2]['role'], 'assistant');
      expect(secondMessages.last['content'], 'Deuxième message');
    });

    test('resetChat vide l historique de session', () async {
      late HttpServer server;
      final chatRequests = <Map<String, dynamic>>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        final raw = await utf8.decoder.bind(request).join();
        chatRequests.add(jsonDecode(raw) as Map<String, dynamic>);

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'OK'},
                },
              ],
            }),
          );
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final service = MistralService(
        apiKey: 'test-key',
        dio: Dio(BaseOptions(baseUrl: baseUri.toString())),
        enableLogging: false,
      );

      await service.analyzeWine(userMessage: 'Message 1');
      service.resetChat();
      await service.analyzeWine(
        userMessage: 'Message 2',
        conversationHistory: const [
          {'role': 'assistant', 'content': 'restored history'},
        ],
      );

      final secondMessages = chatRequests.last['messages'] as List<dynamic>;
      expect(secondMessages[1]['content'], 'restored history');
      expect(secondMessages.last['content'], 'Message 2');
    });

    test('analyzeWineFromImage retente avec un modèle pixtral découvert',
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
            ..write(
              jsonEncode({
                'data': [
                  {'id': 'pixtral-large-latest'},
                ],
              }),
            );
          await request.response.close();
          return;
        }

        if (request.uri.path == '/v1/chat/completions') {
          final raw = await utf8.decoder.bind(request).join();
          final payload = jsonDecode(raw) as Map<String, dynamic>;
          requests.add(payload);

          if (payload['model'] == 'mistral-small-latest') {
            request.response
              ..statusCode = 400
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'message': 'vision unsupported'}));
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
                      'content': '<json>{"name":"Bandol","color":"red"}</json>',
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

      final service = MistralService(
        apiKey: 'test-key',
        dio: Dio(BaseOptions(baseUrl: baseUri.toString())),
        enableLogging: false,
      );

      final result = await service.analyzeWineFromImage(
        imageBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
      );

      expect(result.isError, isFalse);
      expect(result.wineDataList.single.name, 'Bandol');
      expect(requests.map((request) => request['model']).toList(), [
        'mistral-small-latest',
        'pixtral-large-latest',
      ]);
    });

    test('discoverVisionModel met en cache le modèle pixtral préféré',
        () async {
      late HttpServer server;
      var callCount = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUri = Uri.parse('http://${server.address.address}:${server.port}');

      server.listen((request) async {
        callCount += 1;
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': [
                {'id': 'mistral-small-latest'},
                {'id': 'pixtral-12b-latest'},
              ],
            }),
          );
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final service = MistralService(
        apiKey: 'test-key',
        dio: Dio(BaseOptions(baseUrl: baseUri.toString())),
        enableLogging: false,
      );

      expect(await service.discoverVisionModel(), 'pixtral-12b-latest');
      expect(await service.discoverVisionModel(), 'pixtral-12b-latest');
      expect(callCount, 1);
    });

    test('testConnection retourne false sur erreur réseau', () async {
      final service = MistralService(
        apiKey: 'test-key',
        dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1')),
        enableLogging: false,
      );

      expect(await service.testConnection(), isFalse);
    });
  });
}