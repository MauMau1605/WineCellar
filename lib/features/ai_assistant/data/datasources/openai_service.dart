import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:logger/logger.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';

/// OpenAI implementation of the AI service
class OpenAiService implements AiService {
  final String apiKey;
  final String model;
  final Logger _logger = Logger();
  String? _discoveredVisionModel;

  static const int _structuredOutputMaxTokens = 4000;
  static const int _visionStructuredOutputMaxTokens = 2500;

  static const List<String> _preferredVisionModels = [
    'gpt-4o-mini',
    'gpt-4.1-mini',
    'gpt-4o',
    'gpt-4.1',
  ];

  OpenAiService({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
  }) {
    OpenAI.apiKey = apiKey;
  }

  @override
  Future<AiChatResult> analyzeWine({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    try {
      // Build messages list with system prompt + conversation history
      final messages = <OpenAIChatCompletionChoiceMessageModel>[
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
              AiPrompts.systemPrompt,
            ),
          ],
        ),
      ];

      // Add conversation history
      for (final msg in conversationHistory) {
        final role = msg['role'] == 'user'
            ? OpenAIChatMessageRole.user
            : OpenAIChatMessageRole.assistant;
        messages.add(
          OpenAIChatCompletionChoiceMessageModel(
            role: role,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                msg['content'] ?? '',
              ),
            ],
          ),
        );
      }

      // Add current user message
      messages.add(
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(userMessage),
          ],
        ),
      );

      final response = await OpenAI.instance.chat.create(
        model: model,
        messages: messages,
        temperature: 0.3, // Low temperature for more consistent structured output
        maxTokens: _structuredOutputMaxTokens,
      );

      final textResponse = response.choices.first.message.content
              ?.map((item) => item.text)
              .where((text) => text != null)
              .join('') ??
          '';

      // Extract JSON from response
      final wineDataList = _extractWineData(textResponse);

      return AiChatResult(
        textResponse: _cleanTextResponse(textResponse),
        wineDataList: wineDataList,
      );
    } catch (e) {
      _logger.e('OpenAI API error', error: e);
      return AiChatResult.error(
        'Erreur de communication avec OpenAI: ${e.toString()}',
      );
    }
  }

  @override
  Future<AiChatResult> analyzeWineFromImage({
    required List<int> imageBytes,
    required String mimeType,
    String userMessage = 'Analyse cette photo de bouteille de vin.',
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    try {
      return await _analyzeWineFromImageWithModel(
        modelName: model,
        imageBytes: imageBytes,
        mimeType: mimeType,
        userMessage: userMessage,
        conversationHistory: conversationHistory,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      _logger.e('OpenAI image API error', error: e, stackTrace: e.stackTrace);

      if (statusCode == 401) {
        return AiChatResult.error(
          'Clé API OpenAI invalide. Vérifiez votre clé dans les paramètres.',
        );
      }

      if (statusCode == 400 || statusCode == 404) {
        final fallbackModel = await _discoverVisionModel();
        if (fallbackModel != null && fallbackModel != model) {
          try {
            return await _analyzeWineFromImageWithModel(
              modelName: fallbackModel,
              imageBytes: imageBytes,
              mimeType: mimeType,
              userMessage: userMessage,
              conversationHistory: conversationHistory,
            );
          } catch (_) {
            // Keep original contextual message below.
          }
        }

        String? detail;
        if (responseData is Map) {
          final err = responseData['error'];
          if (err is Map) detail = err['message']?.toString();
        }
        return AiChatResult.error(
          'Le modèle OpenAI "$model" ne supporte peut-être pas la vision. '
          'Essayez un modèle multimodal (ex: gpt-4o-mini). '
          '${detail ?? ""}'.trim(),
        );
      }

      return AiChatResult.error(
        'Erreur d\'analyse d\'image avec OpenAI: ${e.message}',
      );
    } catch (e) {
      _logger.e('OpenAI image error', error: e);
      return AiChatResult.error(
        'Erreur d\'analyse d\'image avec OpenAI: ${e.toString()}',
      );
    }
  }

  Future<AiChatResult> _analyzeWineFromImageWithModel({
    required String modelName,
    required List<int> imageBytes,
    required String mimeType,
    required String userMessage,
    required List<Map<String, String>> conversationHistory,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final dataUrl = 'data:$mimeType;base64,$base64Image';

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': AiPrompts.systemPrompt,
      },
    ];

    for (final msg in conversationHistory) {
      final role = msg['role'] == 'user' ? 'user' : 'assistant';
      messages.add({
        'role': role,
        'content': msg['content'] ?? '',
      });
    }

    messages.add({
      'role': 'user',
      'content': [
        {'type': 'text', 'text': userMessage},
        {
          'type': 'image_url',
          'image_url': {'url': dataUrl},
        },
      ],
    });

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.openai.com',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    final response = await dio.post(
      '/v1/chat/completions',
      data: {
        'model': modelName,
        'messages': messages,
        'temperature': 0.1,
        'max_tokens': _visionStructuredOutputMaxTokens,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    final textResponse =
        choices?.firstOrNull?['message']?['content'] as String? ?? '';

    final wineDataList = _extractWineData(textResponse);

    return AiChatResult(
      textResponse: _cleanTextResponse(textResponse),
      wineDataList: wineDataList,
    );
  }

  Future<String?> _discoverVisionModel() async {
    if (_discoveredVisionModel != null) return _discoveredVisionModel;

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.openai.com',
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ),
    );

    final response = await dio.get('/v1/models');
    final data = response.data as Map<String, dynamic>?;
    final models = data?['data'] as List?;
    if (models == null) return null;

    final ids = models
        .whereType<Map>()
        .map((e) => e['id'])
        .whereType<String>()
        .toList();

    for (final preferred in _preferredVisionModels) {
      if (ids.contains(preferred)) {
        _discoveredVisionModel = preferred;
        return preferred;
      }
    }

    final candidates = ids.where(_looksVisionCapable).toList();
    if (candidates.isNotEmpty) {
      _discoveredVisionModel = candidates.first;
      return candidates.first;
    }

    return null;
  }

  bool _looksVisionCapable(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('embedding') ||
        lower.contains('audio') ||
        lower.contains('realtime') ||
        lower.contains('tts')) {
      return false;
    }
    return lower.contains('4o') ||
        lower.contains('vision') ||
        lower.contains('omni') ||
        lower.contains('gpt-4.1');
  }

  @override
  Future<String?> discoverVisionModel() async {
    try {
      return await _discoverVisionModel();
    } catch (_) {
      return null;
    }
  }

  @override
  bool get supportsWebSearch => false;

  @override
  void resetChat() {} // OpenAI is stateless — no session to reset.

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

  @override
  Future<bool> testConnection() async {
    try {
      final response = await OpenAI.instance.chat.create(
        model: model,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text('ping'),
            ],
          ),
        ],
        maxTokens: 5,
      );
      return response.choices.isNotEmpty;
    } catch (e) {
      _logger.e('OpenAI connection test failed', error: e);
      return false;
    }
  }

  /// Extract JSON block from AI response text (supports {"wines":[...]} array and single object)
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
      _logger.w('Failed to parse wine data from AI response', error: e);
      return [];
    }
  }

  /// Parse JSON string into list of WineAiResponse
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

  /// Remove the JSON block from the display text
  String _cleanTextResponse(String response) {
    return response
        .replaceAll(RegExp(r'<json>\s*[\s\S]*?\s*</json>'), '')
        .replaceAll(RegExp(r'```json\s*[\s\S]*?\s*```'), '')
        .trim();
  }
}
