import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import 'package:logger/logger.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/ai_prompts.dart';

/// OpenAI implementation of the AI service
class OpenAiService implements AiService {
  final String apiKey;
  final String model;
  final Logger _logger = Logger();

  OpenAiService({
    required this.apiKey,
    this.model = 'gpt-3.5-turbo',
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
        maxTokens: 1500,
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
        .replaceAll(RegExp(r'```json\s*[\s\S]*?\s*```'), '')
        .trim();
  }
}
