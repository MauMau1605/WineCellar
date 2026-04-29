import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';

class AiProviderConfigUi {
  final String title;
  final bool usesApiKeyField;
  final String? apiKeyLabel;
  final String? apiKeyHint;
  final bool usesOllamaUrlField;
  final String modelHint;
  final String modelHelper;
  final bool showsVisionModelChip;
  final String? providerInfoText;

  const AiProviderConfigUi({
    required this.title,
    required this.usesApiKeyField,
    required this.apiKeyLabel,
    required this.apiKeyHint,
    required this.usesOllamaUrlField,
    required this.modelHint,
    required this.modelHelper,
    required this.showsVisionModelChip,
    required this.providerInfoText,
  });
}

class AiSettingsProviderConfigHelper {
  AiSettingsProviderConfigHelper._();

  static AiProviderConfigUi build(AiProvider provider) {
    return switch (provider) {
      AiProvider.openai => AiProviderConfigUi(
        title: 'Configuration OpenAI',
        usesApiKeyField: true,
        apiKeyLabel: 'Clé API OpenAI',
        apiKeyHint: 'sk-...',
        usesOllamaUrlField: false,
        modelHint: AppConstants.defaultOpenAiModel,
        modelHelper: 'Recommandé : gpt-4o-mini (pas cher et efficace)',
        showsVisionModelChip: true,
        providerInfoText: null,
      ),
      AiProvider.gemini => AiProviderConfigUi(
        title: 'Configuration Google Gemini',
        usesApiKeyField: true,
        apiKeyLabel: 'Clé API Gemini',
        apiKeyHint: 'AIza...',
        usesOllamaUrlField: false,
        modelHint: AppConstants.defaultGeminiModel,
        modelHelper: 'Recommandé : gemini-2.5-flash-lite',
        showsVisionModelChip: false,
        providerInfoText: 'Obtenez votre clé gratuite sur aistudio.google.com',
      ),
      AiProvider.mistral => AiProviderConfigUi(
        title: 'Configuration Mistral AI',
        usesApiKeyField: true,
        apiKeyLabel: 'Clé API Mistral',
        apiKeyHint: '',
        usesOllamaUrlField: false,
        modelHint: AppConstants.defaultMistralModel,
        modelHelper:
            'Recommandé : mistral-small-latest (bon rapport qualité/prix)',
        showsVisionModelChip: true,
        providerInfoText: 'Obtenez votre clé sur console.mistral.ai',
      ),
      AiProvider.ollama => AiProviderConfigUi(
        title: 'Configuration Ollama',
        usesApiKeyField: false,
        apiKeyLabel: null,
        apiKeyHint: null,
        usesOllamaUrlField: true,
        modelHint: AppConstants.defaultOllamaModel,
        modelHelper: 'Recommandé : llama3 ou mistral',
        showsVisionModelChip: false,
        providerInfoText: null,
      ),
    };
  }
}