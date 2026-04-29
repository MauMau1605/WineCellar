import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/settings/presentation/helpers/ai_settings_form_helper.dart';

void main() {
  group('AiSettingsFormHelper.buildInitialState', () {
    test('applique les valeurs par defaut et parse le provider vision', () {
      final state = AiSettingsFormHelper.buildInitialState(
        openAiApiKey: 'sk-test',
        ollamaUrl: null,
        visionProviderName: 'gemini',
      );

      expect(state.openAiApiKey, 'sk-test');
      expect(state.ollamaUrl, AppConstants.defaultOllamaUrl);
      expect(state.visionProviderOverride, AiProvider.gemini);
    });

    test('ignore un provider vision inconnu', () {
      final state = AiSettingsFormHelper.buildInitialState(
        visionProviderName: 'unknown',
      );

      expect(state.visionProviderOverride, isNull);
    });
  });

  group('AiSettingsFormHelper helpers', () {
    test('retourne le bon titre de configuration', () {
      expect(
        AiSettingsFormHelper.configTitle(AiProvider.openai),
        'Configuration OpenAI',
      );
      expect(
        AiSettingsFormHelper.configTitle(AiProvider.gemini),
        'Configuration Google Gemini',
      );
    });

    test('retourne le bon modele par defaut pour chaque provider', () {
      expect(
        AiSettingsFormHelper.defaultModelFor(AiProvider.openai),
        AppConstants.defaultOpenAiModel,
      );
      expect(
        AiSettingsFormHelper.defaultModelFor(AiProvider.gemini),
        AppConstants.defaultGeminiModel,
      );
      expect(
        AiSettingsFormHelper.defaultModelFor(AiProvider.mistral),
        AppConstants.defaultMistralModel,
      );
      expect(
        AiSettingsFormHelper.defaultModelFor(AiProvider.ollama),
        AppConstants.defaultOllamaModel,
      );
    });
  });

  group('AiSettingsFormHelper.buildSaveData', () {
    test('normalise les champs vides en null et garde le modele saisi', () {
      final saveData = AiSettingsFormHelper.buildSaveData(
        currentProvider: AiProvider.gemini,
        openAiApiKey: '  ',
        geminiApiKey: ' AIza-test ',
        mistralApiKey: '',
        ollamaUrl: '  ',
        model: ' gemini-custom ',
        visionProviderOverride: AiProvider.openai,
        visionModel: ' gpt-4o ',
        visionApiKey: ' sk-vision ',
        geminiFallbackKey: '  AIza-fallback  ',
      );

      expect(saveData.openAiApiKey, isNull);
      expect(saveData.geminiApiKey, 'AIza-test');
      expect(saveData.mistralApiKey, isNull);
      expect(saveData.ollamaUrl, isNull);
      expect(saveData.selectedModel, 'gemini-custom');
      expect(saveData.visionProviderOverrideName, 'openai');
      expect(saveData.visionModel, 'gpt-4o');
      expect(saveData.visionApiKey, 'sk-vision');
      expect(saveData.geminiFallbackKey, 'AIza-fallback');
    });

    test('retombe sur le modele par defaut si le champ modele est vide', () {
      final saveData = AiSettingsFormHelper.buildSaveData(
        currentProvider: AiProvider.ollama,
        openAiApiKey: '',
        geminiApiKey: '',
        mistralApiKey: '',
        ollamaUrl: 'http://localhost:11434',
        model: '   ',
        visionProviderOverride: null,
        visionModel: '',
        visionApiKey: '',
        geminiFallbackKey: '',
      );

      expect(saveData.selectedModel, AppConstants.defaultOllamaModel);
      expect(saveData.visionProviderOverrideName, isNull);
    });
  });
}