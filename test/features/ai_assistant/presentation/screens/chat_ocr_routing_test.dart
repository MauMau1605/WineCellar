import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/screens/chat_screen.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/vivino_datasource.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/cellar_tracker_datasource.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/vivino_result.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/cellar_tracker_result.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';

class MockVivinoDatasource extends Mock implements VivinoDatasource {}
class MockCellarTrackerDatasource extends Mock implements CellarTrackerDatasource {}
class MockSecureStorage extends Mock implements FlutterSecureStorage {}
class MockAnalyzeWineUseCase extends Mock implements AnalyzeWineUseCase {}
class MockAiService extends Mock implements AiService {}

void main() {
  late MockVivinoDatasource mockVivino;
  late MockCellarTrackerDatasource mockCT;
  late MockSecureStorage mockStorage;
  late MockAnalyzeWineUseCase mockAnalyzeWine;
  late MockAiService mockAiService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      },
    );
    registerFallbackValue(const AnalyzeWineParams(userMessage: ''));
  });

  setUp(() {
    mockVivino = MockVivinoDatasource();
    mockCT = MockCellarTrackerDatasource();
    mockStorage = MockSecureStorage();
    mockAnalyzeWine = MockAnalyzeWineUseCase();
    mockAiService = MockAiService();

    // Default mocks to avoid crashes
    when(() => mockVivino.searchWineWithReviews(wineName: any(named: 'wineName')))
        .thenAnswer((_) async => const VivinoSearchResult(status: VivinoSourceStatus.notFound));
    when(() => mockCT.searchWine(wineName: any(named: 'wineName')))
        .thenAnswer((_) async => const CellarTrackerResult(status: CellarTrackerSourceStatus.notFound));
    when(() => mockStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async => Future.value());
    
    // Mock successful but empty AI response to avoid null errors in Either.fold
    when(() => mockAnalyzeWine.call(any())).thenAnswer((_) async => const Right(AiChatResult(textResponse: 'OK')));
    when(() => mockAiService.supportsWebSearch).thenReturn(false);
  });

  group('ChatAssistant OCR Routing & Persistence', () {
    testWidgets('utilise le texte OCR pour la recherche Vivino en mode Avis', (tester) async {
      // 1. Setup providers
      final container = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        chatSessionModeProvider.overrideWith((ref) => ChatSessionModeNotifier(mockStorage)),
        vivinoDatasourceProvider.overrideWithValue(mockVivino),
        cellarTrackerDatasourceProvider.overrideWithValue(mockCT),
        aiServiceProvider.overrideWithValue(mockAiService),
        analyzeWineUseCaseProvider.overrideWithValue(mockAnalyzeWine),
        geminiWebSearchServiceProvider.overrideWith((ref) => null),
      ]);

      // Force mode wineReview
      await container.read(chatSessionModeProvider.notifier).setMode(ChatAssistantMode.wineReview);

      // 2. Pump ChatScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 3. Find ChatScreenState to trigger _sendText manually
      final chatState = tester.state<ChatScreenState>(find.byType(ChatScreen));

      // 4. Act: Simulate OCR extraction result being sent
      const ocrText = 'Chateau Margaux 2015';
      
      await tester.runAsync(() async {
        await chatState.invokeSendTextWithOcr(ocrText);
      });
      
      await tester.pumpAndSettle();

      // 5. Assert: Vivino should have been called with OCR text
      verify(() => mockVivino.searchWineWithReviews(wineName: ocrText)).called(1);
    });
  });
}

extension on ChatScreenState {
  Future<void> invokeSendTextWithOcr(String ocrText) {
    return sendTextInternal(
      '🔍 Photo analysée...',
      searchQueryOverride: ocrText,
    );
  }
}
