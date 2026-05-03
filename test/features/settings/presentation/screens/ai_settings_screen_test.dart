import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/test_ai_connection.dart';
import 'package:wine_cellar/features/settings/presentation/screens/ai_settings_screen.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _FakeAiService implements AiService {
  _FakeAiService({required this.connectionResult});

  final bool connectionResult;
  int connectionTestCallCount = 0;

  @override
  Future<AiChatResult> analyzeWine({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    return const AiChatResult(textResponse: 'unused');
  }

  @override
  Future<AiChatResult> analyzeWineFromImage({
    required List<int> imageBytes,
    required String mimeType,
    String userMessage = '',
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    return const AiChatResult(textResponse: 'unused');
  }

  @override
  Future<AiChatResult> analyzeWineWithWebSearch({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
    String? systemPromptOverride,
  }) async {
    return const AiChatResult(textResponse: 'unused');
  }

  @override
  void resetChat() {}

  @override
  bool get supportsWebSearch => false;

  @override
  Future<String?> discoverVisionModel() async => 'gpt-4o';

  @override
  Future<bool> testConnection() async {
    connectionTestCallCount += 1;
    return connectionResult;
  }
}

void main() {
  group('AiSettingsScreen', () {
    late _MockSecureStorage storage;

    setUp(() {
      storage = _MockSecureStorage();
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => storage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
    });

    testWidgets('persiste le fournisseur, les champs et l option OCR', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpScreen(
        tester,
        storage: storage,
        storedValues: {
          AppConstants.keyAiProvider: AiProvider.openai.name,
          AppConstants.keyUseOcrForImages: 'false',
        },
      );

      expect(find.text('Configuration OpenAI'), findsOneWidget);
      expect(find.text('Overrides vision IA (optionnels)'), findsOneWidget);

      await tester.tap(find.text('Ollama (local)'));
      await tester.pumpAndSettle();

      verify(
        () => storage.write(
          key: AppConstants.keyAiProvider,
          value: AiProvider.ollama.name,
        ),
      ).called(1);

      await tester.enterText(
        _findTextField('URL du serveur Ollama'),
        ' http://127.0.0.1:11434 ',
      );
      await tester.enterText(_findTextField('Modèle'), '');

      await tester.tap(find.text('OCR local (Google MLKit)'));
      await tester.pumpAndSettle();

      verify(
        () =>
            storage.write(key: AppConstants.keyUseOcrForImages, value: 'true'),
      ).called(1);
      expect(find.text('Overrides vision IA (optionnels)'), findsNothing);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      verify(
        () => storage.write(
          key: AppConstants.keyOllamaUrl,
          value: 'http://127.0.0.1:11434',
        ),
      ).called(greaterThanOrEqualTo(1));
      verify(
        () => storage.write(
          key: AppConstants.keySelectedModel,
          value: AppConstants.defaultOllamaModel,
        ),
      ).called(1);
      expect(find.text('Paramètres IA enregistrés !'), findsOneWidget);
    });

    testWidgets('teste la connexion et affiche un succes', (tester) async {
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _FakeAiService(connectionResult: true);

      await _pumpScreen(
        tester,
        storage: storage,
        storedValues: {AppConstants.keyAiProvider: AiProvider.openai.name},
        overrides: [
          testAiConnectionUseCaseProvider.overrideWithValue(
            TestAiConnectionUseCase(service),
          ),
          visionModelProvider.overrideWith((ref) async => 'gpt-4o'),
        ],
      );

      await tester.enterText(_findTextField('Clé API OpenAI'), 'sk-test');
      await tester.tap(find.text('Tester la connexion'));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(
        () =>
            storage.write(key: AppConstants.keyOpenAiApiKey, value: 'sk-test'),
      ).called(1);
      expect(find.text('Paramètres IA enregistrés !'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('Connexion réussie !'), findsOneWidget);
      expect(find.text('Vision disponible : gpt-4o'), findsWidgets);
      expect(service.connectionTestCallCount, 1);
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _MockSecureStorage storage,
  Map<String, String?> storedValues = const {},
  List<Override> overrides = const [],
}) async {
  when(() => storage.read(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    final key = invocation.namedArguments[#key] as String;
    return storedValues[key];
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        ...overrides,
      ],
      child: const MaterialApp(home: AiSettingsScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pumpAndSettle();
}

Finder _findTextField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}
