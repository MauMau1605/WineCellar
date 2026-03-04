import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/ai_prompts.dart';

/// Ollama (local) implementation of the AI service
class OllamaService implements AiService {
  final String baseUrl;
  final String model;
  final Dio _dio;
  final Logger _logger = Logger();

  OllamaService({
    this.baseUrl = 'http://localhost:11434',
    this.model = 'llama3',
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
        ));

  @override
  Future<AiChatResult> analyzeWine({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    try {
      // Build messages list
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': AiPrompts.systemPrompt},
      ];

      // Add history
      messages.addAll(conversationHistory);

      // Add current message
      messages.add({'role': 'user', 'content': userMessage});

      final response = await _dio.post(
        '/api/chat',
        data: {
          'model': model,
          'messages': messages,
          'stream': false,
          'options': {
            'temperature': 0.3,
          },
        },
      );

      final textResponse =
          response.data['message']?['content'] as String? ?? '';

      final wineData = _extractWineData(textResponse);

      return AiChatResult(
        textResponse: _cleanTextResponse(textResponse),
        wineData: wineData,
      );
    } on DioException catch (e) {
      _logger.e('Ollama API error', error: e);
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return AiChatResult.error(
          'Impossible de se connecter à Ollama sur $baseUrl. '
          'Vérifiez qu\'Ollama est bien lancé (ollama serve).',
        );
      }
      return AiChatResult.error(
        'Erreur Ollama: ${e.message}',
      );
    } catch (e) {
      _logger.e('Ollama error', error: e);
      return AiChatResult.error('Erreur: ${e.toString()}');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/api/tags');
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Ollama connection test failed', error: e);
      return false;
    }
  }

  WineAiResponse? _extractWineData(String response) {
    try {
      final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
      final match = jsonRegex.firstMatch(response);

      if (match != null) {
        final jsonStr = match.group(1)!;
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return WineAiResponse.fromJson(json);
      }

      final rawJsonRegex = RegExp(r'\{[\s\S]*"name"[\s\S]*\}');
      final rawMatch = rawJsonRegex.firstMatch(response);
      if (rawMatch != null) {
        final json = jsonDecode(rawMatch.group(0)!) as Map<String, dynamic>;
        return WineAiResponse.fromJson(json);
      }

      return null;
    } catch (e) {
      _logger.w('Failed to parse wine data from Ollama response', error: e);
      return null;
    }
  }

  String _cleanTextResponse(String response) {
    return response
        .replaceAll(RegExp(r'```json\s*[\s\S]*?\s*```'), '')
        .trim();
  }
}
