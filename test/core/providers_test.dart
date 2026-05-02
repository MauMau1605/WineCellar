import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/gemini_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/ollama_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/openai_service.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

Future<void> _flushAsyncLoad() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('core providers notifiers', () {
    late _MockSecureStorage storage;

    setUp(() {
      storage = _MockSecureStorage();
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    });

    test('AppVisualThemeNotifier charge le thème sauvegardé et persiste les changements',
        () async {
      when(() => storage.read(key: AppConstants.keyAppVisualTheme))
          .thenAnswer((_) async => 'garageIndustrial');

      final notifier = AppVisualThemeNotifier(storage);
      await _flushAsyncLoad();

      expect(notifier.state, VirtualCellarTheme.garageIndustrial);

      await notifier.setTheme(VirtualCellarTheme.stoneCave);
      expect(notifier.state, VirtualCellarTheme.stoneCave);
      verify(
        () => storage.write(
          key: AppConstants.keyAppVisualTheme,
          value: VirtualCellarTheme.stoneCave.name,
        ),
      ).called(1);

      await notifier.setTheme(null);
      expect(notifier.state, isNull);
      verify(() => storage.delete(key: AppConstants.keyAppVisualTheme)).called(1);
    });

    test('WineListLayoutNotifier charge et sauvegarde la mise en page', () async {
      when(() => storage.read(key: AppConstants.keyWineListLayout))
          .thenAnswer((_) async => 'masterDetailVertical');

      final notifier = WineListLayoutNotifier(storage);
      await _flushAsyncLoad();

      expect(notifier.state, WineListLayout.masterDetailVertical);

      await notifier.setLayout(WineListLayout.list);
      expect(notifier.state, WineListLayout.list);
      verify(
        () => storage.write(
          key: AppConstants.keyWineListLayout,
          value: WineListLayout.list.name,
        ),
      ).called(1);
    });

    test('SplitRatioNotifier charge une valeur valide et clamp les mises à jour',
        () async {
      when(() => storage.read(key: AppConstants.keySplitRatioHorizontal))
          .thenAnswer((_) async => '0.8');

      final notifier = SplitRatioNotifier(
        storage,
        AppConstants.keySplitRatioHorizontal,
        0.35,
      );
      await _flushAsyncLoad();

      expect(notifier.state, 0.8);

      await notifier.setRatio(1.5);
      expect(notifier.state, 0.9);
      verify(
        () => storage.write(
          key: AppConstants.keySplitRatioHorizontal,
          value: '0.9',
        ),
      ).called(1);
    });

    test('SecureStringNotifier charge puis efface la valeur', () async {
      when(() => storage.read(key: 'sample_key')).thenAnswer((_) async => 'abc');

      final notifier = SecureStringNotifier(storage, 'sample_key');
      await _flushAsyncLoad();

      expect(notifier.state, 'abc');

      await notifier.setValue('xyz');
      expect(notifier.state, 'xyz');
      verify(() => storage.write(key: 'sample_key', value: 'xyz')).called(1);

      await notifier.setValue(null);
      expect(notifier.state, isNull);
      verify(() => storage.delete(key: 'sample_key')).called(1);
    });

    test('SecureBoolNotifier lit et écrit le booléen en storage', () async {
      when(() => storage.read(key: 'flag_key')).thenAnswer((_) async => 'true');

      final notifier = SecureBoolNotifier(storage, 'flag_key');
      await _flushAsyncLoad();

      expect(notifier.state, isTrue);

      await notifier.setValue(false);
      expect(notifier.state, isFalse);
      verify(() => storage.write(key: 'flag_key', value: 'false')).called(1);
    });
  });

  group('AI service providers', () {
    ProviderContainer createContainer({
      required AiProvider provider,
      String? openAiKey,
      String? geminiKey,
      String? mistralKey,
      String? ollamaUrl,
      String? selectedModel,
      String? visionProvider,
      String? visionModel,
      String? visionKey,
      String? geminiFallbackKey,
    }) {
      final storage = _MockSecureStorage();
      final storedValues = <String, String?>{
        AppConstants.keyAiProvider: provider.name,
        AppConstants.keyOpenAiApiKey: openAiKey,
        AppConstants.keyGeminiApiKey: geminiKey,
        AppConstants.keyMistralApiKey: mistralKey,
        AppConstants.keyOllamaUrl: ollamaUrl,
        AppConstants.keySelectedModel: selectedModel,
        AppConstants.keyVisionProviderOverride: visionProvider,
        AppConstants.keyVisionModel: visionModel,
        AppConstants.keyVisionApiKeyOverride: visionKey,
        AppConstants.keyGeminiFallbackApiKey: geminiFallbackKey,
      };
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        return storedValues[key];
      });
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      return ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
        ],
      );
    }

    Future<void> warmProviders(ProviderContainer container) async {
      container.read(aiProviderSettingProvider);
      container.read(openAiApiKeyProvider);
      container.read(geminiApiKeyProvider);
      container.read(mistralApiKeyProvider);
      container.read(ollamaUrlProvider);
      container.read(selectedModelProvider);
      container.read(visionProviderOverrideProvider);
      container.read(visionModelOverrideProvider);
      container.read(visionApiKeyOverrideProvider);
      container.read(geminiFallbackApiKeyProvider);
      await _flushAsyncLoad();
    }

    test('aiServiceProvider retourne null pour OpenAI sans clé', () async {
      final container = createContainer(provider: AiProvider.openai);
      addTearDown(container.dispose);

      await warmProviders(container);

      expect(container.read(aiServiceProvider), isNull);
    });

    test('aiServiceProvider sanitize le modèle Gemini legacy', () async {
      final container = createContainer(
        provider: AiProvider.gemini,
        geminiKey: 'gem-key',
        selectedModel: 'gemini-1.5-flash',
      );
      addTearDown(container.dispose);

      await warmProviders(container);

      final service = container.read(aiServiceProvider);

      expect(service, isA<GeminiService>());
      expect((service! as GeminiService).model, AppConstants.defaultGeminiModel);
    });

    test('aiServiceProvider construit Ollama avec les valeurs par défaut', () async {
      final container = createContainer(provider: AiProvider.ollama);
      addTearDown(container.dispose);

      await warmProviders(container);

      final service = container.read(aiServiceProvider);
      final ollamaService = service! as OllamaService;

      expect(service, isA<OllamaService>());
      expect(ollamaService.baseUrl, AppConstants.defaultOllamaUrl);
      expect(ollamaService.model, AppConstants.defaultOllamaModel);
    });

    test('visionAiServiceProvider délègue au service principal sans override', () async {
      final container = createContainer(
        provider: AiProvider.openai,
        openAiKey: 'open-key',
        selectedModel: 'gpt-custom',
      );
      addTearDown(container.dispose);

      await warmProviders(container);

      final mainService = container.read(aiServiceProvider);
      final visionService = container.read(visionAiServiceProvider);

      expect(identical(mainService, visionService), isTrue);
      expect(visionService, isA<OpenAiService>());
      expect((visionService! as OpenAiService).model, 'gpt-custom');
    });

    test('visionAiServiceProvider retourne null quand Ollama est forcé', () async {
      final container = createContainer(
        provider: AiProvider.openai,
        openAiKey: 'open-key',
        visionProvider: AiProvider.ollama.name,
      );
      addTearDown(container.dispose);

      await warmProviders(container);

      expect(container.read(visionAiServiceProvider), isNull);
    });

    test('visionAiServiceProvider construit un service dédié avec provider override', () async {
      final container = createContainer(
        provider: AiProvider.openai,
        openAiKey: 'open-key',
        selectedModel: 'gpt-4o',
        visionProvider: AiProvider.gemini.name,
        visionKey: 'vision-gemini-key',
      );
      addTearDown(container.dispose);

      await warmProviders(container);

      final visionService = container.read(visionAiServiceProvider);

      expect(visionService, isA<GeminiService>());
      expect((visionService! as GeminiService).model, AppConstants.defaultGeminiModel);
    });

    test('geminiWebSearchServiceProvider utilise la clé fallback hors provider Gemini', () async {
      final container = createContainer(
        provider: AiProvider.openai,
        openAiKey: 'open-key',
        geminiFallbackKey: 'fallback-gemini',
      );
      addTearDown(container.dispose);

      await warmProviders(container);

      final service = container.read(geminiWebSearchServiceProvider);

      expect(service, isA<GeminiService>());
      expect(service!.model, AppConstants.defaultGeminiModel);
    });

    test('geminiWebSearchServiceProvider réutilise la clé principale Gemini', () async {
      final container = createContainer(
        provider: AiProvider.gemini,
        geminiKey: 'main-gemini',
        selectedModel: 'gemini-1.5-flash',
      );
      addTearDown(container.dispose);

      await warmProviders(container);

      final service = container.read(geminiWebSearchServiceProvider);

      expect(service, isA<GeminiService>());
      expect(service!.model, AppConstants.defaultGeminiModel);
    });
  });
}