import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/settings/presentation/helpers/ai_settings_provider_config_helper.dart';

void main() {
  group('AiSettingsProviderConfigHelper.build', () {
    test('retourne la bonne config OpenAI', () {
      final config = AiSettingsProviderConfigHelper.build(AiProvider.openai);

      expect(config.title, 'Configuration OpenAI');
      expect(config.usesApiKeyField, isTrue);
      expect(config.apiKeyLabel, 'Clé API OpenAI');
      expect(config.apiKeyHint, 'sk-...');
      expect(config.usesOllamaUrlField, isFalse);
      expect(config.modelHint, AppConstants.defaultOpenAiModel);
      expect(config.showsVisionModelChip, isTrue);
      expect(config.providerInfoText, isNull);
    });

    test('retourne la bonne config Gemini', () {
      final config = AiSettingsProviderConfigHelper.build(AiProvider.gemini);

      expect(config.title, 'Configuration Google Gemini');
      expect(config.usesApiKeyField, isTrue);
      expect(config.apiKeyLabel, 'Clé API Gemini');
      expect(config.apiKeyHint, 'AIza...');
      expect(config.modelHint, AppConstants.defaultGeminiModel);
      expect(config.showsVisionModelChip, isFalse);
      expect(config.providerInfoText, contains('aistudio.google.com'));
    });

    test('retourne la bonne config Mistral', () {
      final config = AiSettingsProviderConfigHelper.build(AiProvider.mistral);

      expect(config.title, 'Configuration Mistral AI');
      expect(config.usesApiKeyField, isTrue);
      expect(config.apiKeyLabel, 'Clé API Mistral');
      expect(config.modelHint, AppConstants.defaultMistralModel);
      expect(config.showsVisionModelChip, isTrue);
      expect(config.providerInfoText, contains('console.mistral.ai'));
    });

    test('retourne la bonne config Ollama', () {
      final config = AiSettingsProviderConfigHelper.build(AiProvider.ollama);

      expect(config.title, 'Configuration Ollama');
      expect(config.usesApiKeyField, isFalse);
      expect(config.usesOllamaUrlField, isTrue);
      expect(config.modelHint, AppConstants.defaultOllamaModel);
      expect(config.modelHelper, contains('llama3'));
      expect(config.providerInfoText, isNull);
    });
  });
}