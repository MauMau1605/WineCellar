import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/wine_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/food_category_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/food_category_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/add_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/delete_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/get_wine_by_id.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/export_wines.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/import_wines_from_json.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/parse_csv_import.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/import_wines_from_csv.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/image_text_extractor.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine_from_image.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/extract_text_from_wine_image.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/test_ai_connection.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/openai_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/gemini_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/mistral_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/ollama_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/mlkit_image_text_extractor.dart';

// ============ Database ============

/// Main database instance - singleton
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ============ Secure Storage ============

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// ============ Repositories ============

final wineRepositoryProvider = Provider<WineRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return WineRepositoryImpl(db.wineDao, db.foodCategoryDao);
});

final foodCategoryRepositoryProvider = Provider<FoodCategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FoodCategoryRepositoryImpl(db.foodCategoryDao);
});

// ============ Settings ============

/// Current AI provider setting
final aiProviderSettingProvider =
    StateNotifierProvider<AiProviderNotifier, AiProvider>((ref) {
  return AiProviderNotifier(ref.watch(secureStorageProvider));
});

class AiProviderNotifier extends StateNotifier<AiProvider> {
  final FlutterSecureStorage _storage;

  AiProviderNotifier(this._storage) : super(AiProvider.openai) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: AppConstants.keyAiProvider);
    if (value != null) {
      state = AiProvider.values.firstWhere(
        (p) => p.name == value,
        orElse: () => AiProvider.openai,
      );
    }
  }

  Future<void> setProvider(AiProvider provider) async {
    state = provider;
    await _storage.write(key: AppConstants.keyAiProvider, value: provider.name);
  }
}

/// OpenAI API key
final openAiApiKeyProvider =
    StateNotifierProvider<SecureStringNotifier, String?>((ref) {
  return SecureStringNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyOpenAiApiKey,
  );
});

/// Gemini API key
final geminiApiKeyProvider =
    StateNotifierProvider<SecureStringNotifier, String?>((ref) {
  return SecureStringNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyGeminiApiKey,
  );
});

/// Mistral API key
final mistralApiKeyProvider =
    StateNotifierProvider<SecureStringNotifier, String?>((ref) {
  return SecureStringNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyMistralApiKey,
  );
});

/// Ollama URL
final ollamaUrlProvider =
    StateNotifierProvider<SecureStringNotifier, String?>((ref) {
  return SecureStringNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyOllamaUrl,
  );
});

/// Selected AI model
final selectedModelProvider =
    StateNotifierProvider<SecureStringNotifier, String?>((ref) {
  return SecureStringNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keySelectedModel,
  );
});

/// Reusable notifier for secure string storage
class SecureStringNotifier extends StateNotifier<String?> {
  final FlutterSecureStorage _storage;
  final String _key;

  SecureStringNotifier(this._storage, this._key) : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.read(key: _key);
  }

  Future<void> setValue(String? value) async {
    state = value;
    if (value != null) {
      await _storage.write(key: _key, value: value);
    } else {
      await _storage.delete(key: _key);
    }
  }
}

// ============ AI Service ============

/// AI Service provider - creates the right service based on current settings
final aiServiceProvider = Provider<AiService?>((ref) {
  final provider = ref.watch(aiProviderSettingProvider);
  final apiKey = ref.watch(openAiApiKeyProvider);
  final geminiApiKey = ref.watch(geminiApiKeyProvider);
  final mistralApiKey = ref.watch(mistralApiKeyProvider);
  final ollamaUrl = ref.watch(ollamaUrlProvider);
  final model = ref.watch(selectedModelProvider);

  switch (provider) {
    case AiProvider.openai:
      if (apiKey == null || apiKey.isEmpty) return null;
      return OpenAiService(
        apiKey: apiKey,
        model: model ?? AppConstants.defaultOpenAiModel,
      );
    case AiProvider.gemini:
      if (geminiApiKey == null || geminiApiKey.isEmpty) return null;
      return GeminiService(
        apiKey: geminiApiKey,
        model: _sanitizeGeminiModel(model),
      );
    case AiProvider.mistral:
      if (mistralApiKey == null || mistralApiKey.isEmpty) return null;
      return MistralService(
        apiKey: mistralApiKey,
        model: model ?? AppConstants.defaultMistralModel,
      );
    case AiProvider.ollama:
      return OllamaService(
        baseUrl: ollamaUrl ?? AppConstants.defaultOllamaUrl,
        model: model ?? AppConstants.defaultOllamaModel,
      );
  }
});

String _sanitizeGeminiModel(String? storedModel) {
  final candidate = (storedModel ?? '').trim();

  // Legacy model kept from previous versions: invalid in current Gemini API
  if (candidate.isEmpty || candidate == 'gemini-1.5-flash') {
    return AppConstants.defaultGeminiModel;
  }

  return candidate;
}

// ============ Use Cases — Wine ============

final addWineUseCaseProvider = Provider<AddWineUseCase>((ref) {
  return AddWineUseCase(ref.watch(wineRepositoryProvider));
});

final getWineByIdUseCaseProvider = Provider<GetWineByIdUseCase>((ref) {
  return GetWineByIdUseCase(ref.watch(wineRepositoryProvider));
});

final deleteWineUseCaseProvider = Provider<DeleteWineUseCase>((ref) {
  return DeleteWineUseCase(ref.watch(wineRepositoryProvider));
});

final updateWineUseCaseProvider = Provider<UpdateWineUseCase>((ref) {
  return UpdateWineUseCase(ref.watch(wineRepositoryProvider));
});

final updateWineQuantityUseCaseProvider =
    Provider<UpdateWineQuantityUseCase>((ref) {
  return UpdateWineQuantityUseCase(ref.watch(wineRepositoryProvider));
});

final exportWinesUseCaseProvider = Provider<ExportWinesUseCase>((ref) {
  return ExportWinesUseCase(ref.watch(wineRepositoryProvider));
});

final importWinesFromJsonUseCaseProvider = Provider<ImportWinesFromJsonUseCase>((ref) {
  return ImportWinesFromJsonUseCase(ref.watch(wineRepositoryProvider));
});

final parseCsvImportUseCaseProvider = Provider<ParseCsvImportUseCase>((ref) {
  return ParseCsvImportUseCase(ref.watch(wineRepositoryProvider));
});

final importWinesFromCsvUseCaseProvider = Provider<ImportWinesFromCsvUseCase>((ref) {
  return ImportWinesFromCsvUseCase(ref.watch(wineRepositoryProvider));
});

// ============ Use Cases — AI ============

final imageTextExtractorProvider = Provider<ImageTextExtractor>((ref) {
  return MlKitImageTextExtractor();
});

final extractTextFromWineImageUseCaseProvider =
    Provider<ExtractTextFromWineImageUseCase>((ref) {
  return ExtractTextFromWineImageUseCase(ref.watch(imageTextExtractorProvider));
});

/// Returns null when no AI service is configured yet.
final analyzeWineUseCaseProvider = Provider<AnalyzeWineUseCase?>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  if (aiService == null) return null;
  return AnalyzeWineUseCase(aiService);
});

/// Returns null when no AI service is configured yet.
final analyzeWineFromImageUseCaseProvider =
    Provider<AnalyzeWineFromImageUseCase?>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  if (aiService == null) return null;
  return AnalyzeWineFromImageUseCase(aiService);
});

final testAiConnectionUseCaseProvider =
    Provider<TestAiConnectionUseCase?>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  if (aiService == null) return null;
  return TestAiConnectionUseCase(aiService);
});

/// Discovers which vision-capable model is available for the current AI service.
/// Auto-invalidated when the service changes (API key, provider, model).
final visionModelProvider = FutureProvider.autoDispose<String?>((ref) async {
  final aiService = ref.watch(aiServiceProvider);
  if (aiService == null) return null;
  return aiService.discoverVisionModel();
});
