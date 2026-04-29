import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';

class AiSettingsFormState {
  final String openAiApiKey;
  final String geminiApiKey;
  final String mistralApiKey;
  final String ollamaUrl;
  final String model;
  final AiProvider? visionProviderOverride;
  final String visionModel;
  final String visionApiKey;
  final String geminiFallbackKey;

  const AiSettingsFormState({
    required this.openAiApiKey,
    required this.geminiApiKey,
    required this.mistralApiKey,
    required this.ollamaUrl,
    required this.model,
    required this.visionProviderOverride,
    required this.visionModel,
    required this.visionApiKey,
    required this.geminiFallbackKey,
  });
}

class AiSettingsSaveData {
  final String? openAiApiKey;
  final String? geminiApiKey;
  final String? mistralApiKey;
  final String? ollamaUrl;
  final String selectedModel;
  final String? visionProviderOverrideName;
  final String? visionModel;
  final String? visionApiKey;
  final String? geminiFallbackKey;

  const AiSettingsSaveData({
    required this.openAiApiKey,
    required this.geminiApiKey,
    required this.mistralApiKey,
    required this.ollamaUrl,
    required this.selectedModel,
    required this.visionProviderOverrideName,
    required this.visionModel,
    required this.visionApiKey,
    required this.geminiFallbackKey,
  });
}

class AiSettingsFormHelper {
  AiSettingsFormHelper._();

  static AiSettingsFormState buildInitialState({
    String? openAiApiKey,
    String? geminiApiKey,
    String? mistralApiKey,
    String? ollamaUrl,
    String? model,
    String? visionProviderName,
    String? visionModel,
    String? visionApiKey,
    String? geminiFallbackKey,
  }) {
    final parsedVisionProvider = AiProvider.values.where(
      (provider) => provider.name == visionProviderName,
    );

    return AiSettingsFormState(
      openAiApiKey: openAiApiKey ?? '',
      geminiApiKey: geminiApiKey ?? '',
      mistralApiKey: mistralApiKey ?? '',
      ollamaUrl: ollamaUrl ?? AppConstants.defaultOllamaUrl,
      model: model ?? '',
      visionProviderOverride:
          parsedVisionProvider.isEmpty ? null : parsedVisionProvider.first,
      visionModel: visionModel ?? '',
      visionApiKey: visionApiKey ?? '',
      geminiFallbackKey: geminiFallbackKey ?? '',
    );
  }

  static String configTitle(AiProvider provider) {
    return switch (provider) {
      AiProvider.openai => 'Configuration OpenAI',
      AiProvider.gemini => 'Configuration Google Gemini',
      AiProvider.mistral => 'Configuration Mistral AI',
      AiProvider.ollama => 'Configuration Ollama',
    };
  }

  static String defaultModelFor(AiProvider provider) {
    return switch (provider) {
      AiProvider.openai => AppConstants.defaultOpenAiModel,
      AiProvider.gemini => AppConstants.defaultGeminiModel,
      AiProvider.mistral => AppConstants.defaultMistralModel,
      AiProvider.ollama => AppConstants.defaultOllamaModel,
    };
  }

  static AiSettingsSaveData buildSaveData({
    required AiProvider currentProvider,
    required String openAiApiKey,
    required String geminiApiKey,
    required String mistralApiKey,
    required String ollamaUrl,
    required String model,
    required AiProvider? visionProviderOverride,
    required String visionModel,
    required String visionApiKey,
    required String geminiFallbackKey,
  }) {
    final trimmedModel = model.trim();

    return AiSettingsSaveData(
      openAiApiKey: _trimToNull(openAiApiKey),
      geminiApiKey: _trimToNull(geminiApiKey),
      mistralApiKey: _trimToNull(mistralApiKey),
      ollamaUrl: _trimToNull(ollamaUrl),
      selectedModel: trimmedModel.isEmpty
          ? defaultModelFor(currentProvider)
          : trimmedModel,
      visionProviderOverrideName: visionProviderOverride?.name,
      visionModel: _trimToNull(visionModel),
      visionApiKey: _trimToNull(visionApiKey),
      geminiFallbackKey: _trimToNull(geminiFallbackKey),
    );
  }

  static String? _trimToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}