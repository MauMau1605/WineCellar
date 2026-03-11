import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';

import 'package:wine_cellar/core/chat_logger.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/ai_prompts.dart';

/// Google Gemini implementation of the AI service
class GeminiService implements AiService {
  final String apiKey;
  final String model;
  final Logger _logger = Logger();
  final ChatLogger _chatLogger = ChatLogger();
  static const String _fallbackModel = 'gemini-2.5-flash-lite';
  static const List<String> _preferredModels = [
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-flash-thinking-exp-01-21',
  ];

  static final List<DateTime> _requestTimestamps = <DateTime>[];
  static int _totalRequests = 0;

  late final GenerativeModel _model;

  /// Reuse a single chat session to avoid recreating it per message
  ChatSession? _chatSession;

  /// Track the last request time for basic rate limiting
  DateTime? _lastRequestTime;
  static const _minRequestInterval = Duration(seconds: 4);
  String? _discoveredModel;

  GeminiService({
    required this.apiKey,
    this.model = _fallbackModel,
  }) {
    _model = GenerativeModel(
      model: model,
      apiKey: apiKey,
      systemInstruction: Content.system(AiPrompts.systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 8000,
      ),
    );
  }

  @override
  Future<String?> discoverVisionModel() async => model;

  /// Reset the chat session (call when starting a new conversation)
  void resetChat() {
    _chatSession = null;
  }

  /// Ensure minimum interval between requests (free tier: 15 RPM)
  Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
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
      provider: 'Gemini',
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
      await _waitForRateLimit();

      // Create or reuse chat session
      if (_chatSession == null) {
        // Build conversation history for a new session
        final history = <Content>[];
        for (final msg in conversationHistory) {
          final role = msg['role'] == 'user' ? 'user' : 'model';
          history.add(Content(role, [TextPart(msg['content'] ?? '')]));
        }
        _chatSession = _model.startChat(history: history);
      }

      // Send the current user message (single API call)
      _recordApiRequest(endpoint: 'chat.sendMessage', modelName: model);
      final response = await _chatSession!.sendMessage(
        Content.text(userMessage),
      );

      final textResponse = response.text ?? '';

      // Extract JSON from response
      final wineDataList = _extractWineData(textResponse);

      return AiChatResult(
        textResponse: _cleanTextResponse(textResponse),
        wineDataList: wineDataList,
      );
    } catch (e) {
      _logger.e('Gemini API error', error: e);

      final errorStr = e.toString();
      String errorMsg = 'Erreur de communication avec Gemini: $errorStr';

      if (errorStr.contains('API_KEY_INVALID') ||
          errorStr.contains('PERMISSION_DENIED')) {
        errorMsg =
            'Clé API Gemini invalide. Vérifiez votre clé dans les paramètres.';
      } else if (errorStr.contains('is not found') ||
          errorStr.contains('not supported for generateContent')) {
        try {
          final availableModel = await _discoverSupportedModel();
          if (availableModel != null && availableModel != model) {
            final fallbackResult = await _analyzeWithModel(
              modelName: availableModel,
              userMessage: userMessage,
              conversationHistory: conversationHistory,
            );
            _chatSession = null;
            return fallbackResult;
          }
        } catch (_) {}

        errorMsg =
            'Le modèle Gemini "$model" n\'est pas disponible pour votre clé API. '
            'Choisissez "gemini-2.5-flash-lite" dans les paramètres.';
      } else if (errorStr.contains('RESOURCE_EXHAUSTED') ||
          errorStr.contains('429') ||
          errorStr.contains('quota')) {
        if (model != _fallbackModel) {
          try {
            final fallbackResult = await _analyzeWithModel(
              modelName: _fallbackModel,
              userMessage: userMessage,
              conversationHistory: conversationHistory,
            );
            _chatSession = null;
            return fallbackResult;
          } catch (_) {
            errorMsg =
                'Limite atteinte sur le modèle $model. Essayez le modèle $_fallbackModel dans les paramètres, '
                'ou attendez quelques minutes avant de réessayer. Détail: $errorStr';
          }
        } else {
          final localRpm = _requestsInLastMinute();
          errorMsg =
              'Limite de requêtes Gemini atteinte. Compteur local: $localRpm requêtes sur 60s '
              '(total session: $_totalRequests). Attendez un moment avant de réessayer. Détail: $errorStr';
        }
      }

      return AiChatResult.error(errorMsg);
    }
  }

  Future<AiChatResult> _analyzeWithModel({
    required String modelName,
    required String userMessage,
    required List<Map<String, String>> conversationHistory,
  }) async {
    final fallback = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(AiPrompts.systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 8000,
      ),
    );

    final history = <Content>[];
    for (final msg in conversationHistory) {
      final role = msg['role'] == 'user' ? 'user' : 'model';
      history.add(Content(role, [TextPart(msg['content'] ?? '')]));
    }

    final chat = fallback.startChat(history: history);
    _recordApiRequest(endpoint: 'chat.sendMessage.fallback', modelName: modelName);
    final response = await chat.sendMessage(Content.text(userMessage));
    final textResponse = response.text ?? '';
    final wineDataList = _extractWineData(textResponse);

    return AiChatResult(
      textResponse: _cleanTextResponse(textResponse),
      wineDataList: wineDataList,
    );
  }

  Future<String?> _discoverSupportedModel() async {
    if (_discoveredModel != null) return _discoveredModel;

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://generativelanguage.googleapis.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    _recordApiRequest(endpoint: 'models.list', modelName: 'v1beta/models');
    final response = await dio.get(
      '/v1beta/models',
      queryParameters: {'key': apiKey},
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return null;

    final models = data['models'];
    if (models is! List) return null;

    final supported = <String>[];
    for (final item in models) {
      if (item is! Map<String, dynamic>) continue;
      final name = item['name'] as String?;
      final methods = item['supportedGenerationMethods'];
      final supportsGenerateContent =
          methods is List && methods.contains('generateContent');
      if (name != null && supportsGenerateContent) {
        supported.add(name.replaceFirst('models/', ''));
      }
    }

    for (final preferred in _preferredModels) {
      if (supported.contains(preferred)) {
        _discoveredModel = preferred;
        return preferred;
      }
    }

    if (supported.isNotEmpty) {
      _discoveredModel = supported.first;
      return supported.first;
    }

    return null;
  }

  @override
  Future<AiChatResult> analyzeWineFromImage({
    required List<int> imageBytes,
    required String mimeType,
    String userMessage = 'Analyse cette photo de bouteille de vin.',
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    try {
      await _waitForRateLimit();

      // Create or reuse chat session
      if (_chatSession == null) {
        final history = <Content>[];
        for (final msg in conversationHistory) {
          final role = msg['role'] == 'user' ? 'user' : 'model';
          history.add(Content(role, [TextPart(msg['content'] ?? '')]));
        }
        _chatSession = _model.startChat(history: history);
      }

      // Send multimodal message: image + text
      _recordApiRequest(endpoint: 'chat.sendMessage.image', modelName: model);
      final response = await _chatSession!.sendMessage(
        Content.multi([
          DataPart(mimeType, Uint8List.fromList(imageBytes)),
          TextPart(userMessage),
        ]),
      );

      final textResponse = response.text ?? '';

      // Extract JSON from response
      final wineDataList = _extractWineData(textResponse);

      return AiChatResult(
        textResponse: _cleanTextResponse(textResponse),
        wineDataList: wineDataList,
      );
    } catch (e) {
      _logger.e('Gemini API error (image)', error: e);

      final errorStr = e.toString();
      String errorMsg = "Erreur d'analyse d'image avec Gemini: $errorStr";

      if (errorStr.contains('API_KEY_INVALID') ||
          errorStr.contains('PERMISSION_DENIED')) {
        errorMsg =
            'Clé API Gemini invalide. Vérifiez votre clé dans les paramètres.';
      } else if (errorStr.contains('RESOURCE_EXHAUSTED') ||
          errorStr.contains('429')) {
        errorMsg =
            'Limite d\'API Gemini atteinte. Attendez quelques minutes.';
      }

      return AiChatResult.error(errorMsg);
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _waitForRateLimit();
      // Use a minimal prompt for the test to consume fewer tokens
      final testModel = GenerativeModel(
        model: model,
        apiKey: apiKey,
        generationConfig: GenerationConfig(maxOutputTokens: 10),
      );
      _recordApiRequest(endpoint: 'generateContent.testConnection', modelName: model);
      final response = await testModel.generateContent([
        Content.text('ok?'),
      ]);
      return response.text != null && response.text!.isNotEmpty;
    } catch (e) {
      _logger.e('Gemini connection test failed', error: e);
      return false;
    }
  }

  /// Extract JSON block from AI response text (supports {"wines":[...]} array and single object)
  List<WineAiResponse> _extractWineData(String response) {
    try {
      // Look for JSON block between ```json and ```
      final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
      final match = jsonRegex.firstMatch(response);

      if (match != null) {
        final jsonStr = match.group(1)!;
        return _parseWineJson(jsonStr);
      }

      // Fallback: try to find raw JSON object/array
      final rawJsonRegex = RegExp(r'\{[\s\S]*"(?:wines|name)"[\s\S]*\}');
      final rawMatch = rawJsonRegex.firstMatch(response);
      if (rawMatch != null) {
        return _parseWineJson(rawMatch.group(0)!);
      }

      return [];
    } catch (e) {
      _logger.w('Failed to parse wine data from Gemini response', error: e);
      return [];
    }
  }

  /// Parse JSON string into list of WineAiResponse
  List<WineAiResponse> _parseWineJson(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      // New format: {"wines": [...]}
      if (decoded.containsKey('wines') && decoded['wines'] is List) {
        return (decoded['wines'] as List)
            .whereType<Map<String, dynamic>>()
            .map((e) => WineAiResponse.fromJson(e))
            .toList();
      }
      // Legacy single object format
      return [WineAiResponse.fromJson(decoded)];
    }
    return [];
  }

  /// Remove the JSON block from the display text
  String _cleanTextResponse(String response) {
    return response
        .replaceAll(RegExp(r'```json\s*[\s\S]*?\s*```'), '')
        .trim();
  }
}
