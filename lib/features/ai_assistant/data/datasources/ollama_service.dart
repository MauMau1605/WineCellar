import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';

/// Ollama (local) implementation of the AI service
class OllamaService implements AiService {
  final String baseUrl;
  final String model;
  final Dio _dio;
  final Logger _logger = Logger();

  @override
  bool get supportsWebSearch => false;

  @override
  void resetChat() {} // Ollama is stateless — no session to reset.

  @override
  Future<AiChatResult> analyzeWineWithWebSearch({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
    String? systemPromptOverride,
  }) async {
    return analyzeWine(
      userMessage: userMessage,
      conversationHistory: conversationHistory,
    );
  }

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

      final wineDataList = _extractWineData(textResponse);

      return AiChatResult(
        textResponse: _cleanTextResponse(textResponse),
        wineDataList: wineDataList,
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
  Future<AiChatResult> analyzeWineFromImage({
    required List<int> imageBytes,
    required String mimeType,
    String userMessage = 'Analyse cette photo de bouteille de vin.',
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    return AiChatResult.error(
      'L\'analyse d\'image directe n\'est pas disponible avec le provider Ollama actuellement.',
    );
  }

  @override
  Future<String?> discoverVisionModel() async => null;

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

  List<WineAiResponse> _extractWineData(String response) {
    try {
      // 1. Look for JSON block between <json> and </json> tags (as requested by system prompt)
      final xmlJsonRegex = RegExp(r'<json>\s*([\s\S]*?)\s*</json>');
      final xmlMatch = xmlJsonRegex.firstMatch(response);
      if (xmlMatch != null) {
        return _parseWineJson(xmlMatch.group(1)!);
      }

      // 2. Look for JSON block between ```json and ```
      final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
      final match = jsonRegex.firstMatch(response);
      if (match != null) {
        return _parseWineJson(match.group(1)!);
      }

      // 3. Fallback: try to find raw JSON object/array
      final rawJsonRegex = RegExp(r'\{[\s\S]*"(?:wines|name)"[\s\S]*\}');
      final rawMatch = rawJsonRegex.firstMatch(response);
      if (rawMatch != null) {
        return _parseWineJson(rawMatch.group(0)!);
      }

      return [];
    } catch (e) {
      _logger.w('Failed to parse wine data from Ollama response', error: e);
      return [];
    }
  }

  List<WineAiResponse> _parseWineJson(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('wines') && decoded['wines'] is List) {
        return (decoded['wines'] as List)
            .whereType<Map<String, dynamic>>()
            .map((e) => WineAiResponse.fromJson(e))
            .toList();
      }
      return [WineAiResponse.fromJson(decoded)];
    }
    return [];
  }

  String _cleanTextResponse(String response) {
    return response
        .replaceAll(RegExp(r'<json>\s*[\s\S]*?\s*</json>'), '')
        .replaceAll(RegExp(r'```json\s*[\s\S]*?\s*```'), '')
        .trim();
  }
}
