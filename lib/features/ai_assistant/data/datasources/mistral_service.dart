import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'package:wine_cellar/core/chat_logger.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/ai_prompts.dart';

/// Mistral AI implementation of the AI service using the OpenAI-compatible API.
/// API docs: https://docs.mistral.ai/api/
class MistralService implements AiService {
  final String apiKey;
  final String model;
  final Dio _dio;
  final Logger _logger = Logger();
  final ChatLogger _chatLogger = ChatLogger();

  static final List<DateTime> _requestTimestamps = <DateTime>[];
  static int _totalRequests = 0;

  /// Conversation history maintained for session reuse
  final List<Map<String, String>> _sessionHistory = [];

  MistralService({
    required this.apiKey,
    this.model = 'mistral-small-latest',
  }) : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.mistral.ai',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ));

  /// Reset the conversation session
  void resetChat() {
    _sessionHistory.clear();
  }

  int _requestsInLastMinute() {
    final now = DateTime.now();
    _requestTimestamps
        .removeWhere((ts) => now.difference(ts) > const Duration(minutes: 1));
    return _requestTimestamps.length;
  }

  void _recordApiRequest({required String endpoint, required String modelName}) {
    final now = DateTime.now();
    _requestTimestamps.add(now);
    _totalRequests += 1;
    final rpm = _requestsInLastMinute();

    _chatLogger.logApiCall(
      provider: 'Mistral',
      model: modelName,
      requestSummary:
          'endpoint=$endpoint | local_rpm_60s=$rpm | total_session=$_totalRequests',
    );
  }

  @override
  Future<AiChatResult> analyzeWine({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    try {
      // Build messages list with system prompt
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': AiPrompts.systemPrompt},
      ];

      // Use session history if available, otherwise use provided history
      if (_sessionHistory.isNotEmpty) {
        messages.addAll(_sessionHistory);
      } else if (conversationHistory.isNotEmpty) {
        messages.addAll(conversationHistory);
      }

      // Add current user message
      messages.add({'role': 'user', 'content': userMessage});

      _recordApiRequest(endpoint: 'chat/completions', modelName: model);

      final response = await _dio.post(
        '/v1/chat/completions',
        data: {
          'model': model,
          'messages': messages,
          'temperature': 0.3,
          'max_tokens': 8000,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      final textResponse =
          choices?.firstOrNull?['message']?['content'] as String? ?? '';

      // Update session history
      _sessionHistory.add({'role': 'user', 'content': userMessage});
      _sessionHistory.add({'role': 'assistant', 'content': textResponse});

      final wineDataList = _extractWineData(textResponse);

      return AiChatResult(
        textResponse: _cleanTextResponse(textResponse),
        wineDataList: wineDataList,
      );
    } on DioException catch (e) {
      _logger.e('Mistral API error', error: e);

      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      String errorMsg = 'Erreur de communication avec Mistral: ${e.message}';

      if (statusCode == 401) {
        errorMsg =
            'Clé API Mistral invalide. Vérifiez votre clé dans les paramètres.';
      } else if (statusCode == 429) {
        errorMsg =
            'Limite de requêtes Mistral atteinte. Attendez un moment avant de réessayer.';
      } else if (statusCode == 400) {
        final detail = responseData is Map ? responseData['message'] : null;
        errorMsg =
            'Requête invalide Mistral (modèle "$model" indisponible ?). ${detail ?? e.message}';
      }

      return AiChatResult.error(errorMsg);
    } catch (e) {
      _logger.e('Mistral error', error: e);
      return AiChatResult.error('Erreur Mistral: ${e.toString()}');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      _recordApiRequest(endpoint: 'models', modelName: 'list');
      final response = await _dio.get('/v1/models');
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Mistral connection test failed', error: e);
      return false;
    }
  }

  /// Extract JSON block from AI response text (supports {"wines":[...]} and single object)
  List<WineAiResponse> _extractWineData(String response) {
    try {
      final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
      final match = jsonRegex.firstMatch(response);

      if (match != null) {
        final jsonStr = match.group(1)!;
        return _parseWineJson(jsonStr);
      }

      final rawJsonRegex = RegExp(r'\{[\s\S]*"(?:wines|name)"[\s\S]*\}');
      final rawMatch = rawJsonRegex.firstMatch(response);
      if (rawMatch != null) {
        return _parseWineJson(rawMatch.group(0)!);
      }

      return [];
    } catch (e) {
      _logger.w('Failed to parse wine data from Mistral response', error: e);
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
        .replaceAll(RegExp(r'```json\s*[\s\S]*?\s*```'), '')
        .trim();
  }
}
