import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/wine_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/food_category_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/virtual_cellar_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/food_category_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/add_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/delete_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/get_wine_by_id.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/export_wines.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/import_wines_from_json.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/parse_csv_import.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/import_wines_from_csv.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/get_all_virtual_cellars.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/create_virtual_cellar.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_virtual_cellar.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/delete_virtual_cellar.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/place_wine_in_cellar.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/remove_bottle_placement.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/get_wine_placements.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/move_bottles_in_cellar.dart';
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
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

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
  return WineRepositoryImpl(
    db.wineDao,
    db.foodCategoryDao,
    db.virtualCellarDao,
    db.bottlePlacementDao,
  );
});

final foodCategoryRepositoryProvider = Provider<FoodCategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FoodCategoryRepositoryImpl(db.foodCategoryDao);
});

final virtualCellarRepositoryProvider = Provider<VirtualCellarRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return VirtualCellarRepositoryImpl(db.virtualCellarDao, db.bottlePlacementDao);
});

// ============ Visual Theme ============

/// Transient theme override set by the cellar detail screen.
/// When non-null, the entire app adopts this cellar's visual identity.
final immersiveCellarThemeProvider = StateProvider<VirtualCellarTheme?>((ref) {
  return null;
});

/// Persistent global visual theme chosen in Settings.
/// When non-null and no immersive override is active, the app uses this theme.
final appVisualThemeProvider =
    StateNotifierProvider<AppVisualThemeNotifier, VirtualCellarTheme?>((ref) {
  return AppVisualThemeNotifier(ref.watch(secureStorageProvider));
});

class AppVisualThemeNotifier extends StateNotifier<VirtualCellarTheme?> {
  final FlutterSecureStorage _storage;

  AppVisualThemeNotifier(this._storage) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final value =
        await _storage.read(key: AppConstants.keyAppVisualTheme);
    if (value != null && value.isNotEmpty) {
      state = VirtualCellarTheme.values.cast<VirtualCellarTheme?>().firstWhere(
            (t) => t?.name == value,
            orElse: () => null,
          );
    }
  }

  Future<void> setTheme(VirtualCellarTheme? theme) async {
    state = theme;
    if (theme != null) {
      await _storage.write(
          key: AppConstants.keyAppVisualTheme, value: theme.name);
    } else {
      await _storage.delete(key: AppConstants.keyAppVisualTheme);
    }
  }
}

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

// ---- Vision / image analysis overrides ----

/// Modèle dédié à l'analyse d'image (optionnel).
/// Si renseigné, remplace le modèle principal pour l'analyse de photos.
final visionProviderOverrideProvider =
    StateNotifierProvider<SecureStringNotifier, String?>((ref) {
  return SecureStringNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyVisionProviderOverride,
  );
});

/// Modèle dédié à l'analyse d'image (optionnel).
/// Si renseigné, remplace le modèle principal pour l'analyse de photos.
final visionModelOverrideProvider =
    StateNotifierProvider<SecureStringNotifier, String?>((ref) {
  return SecureStringNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyVisionModel,
  );
});

/// Clé API dédiée à l'analyse d'image (optionnel).
/// Si renseignée, remplace la clé principale pour l'analyse de photos.
final visionApiKeyOverrideProvider =
    StateNotifierProvider<SecureStringNotifier, String?>((ref) {
  return SecureStringNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyVisionApiKeyOverride,
  );
});

/// Si true, l'analyse de photos utilise l'OCR local (MLKit)
/// au lieu d'envoyer l'image à l'IA multimodale.
final useOcrForImagesProvider =
    StateNotifierProvider<SecureBoolNotifier, bool>((ref) {
  return SecureBoolNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyUseOcrForImages,
  );
});

/// Clé API Gemini dédiée à la recherche web (fallback).
/// Permet de compléter les champs estimés via Gemini Search même si
/// le fournisseur principal est Mistral/OpenAI/Ollama.
final geminiFallbackApiKeyProvider =
    StateNotifierProvider<SecureStringNotifier, String?>((ref) {
  return SecureStringNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyGeminiFallbackApiKey,
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

/// Reusable notifier for a boolean stored as a string in secure storage.
class SecureBoolNotifier extends StateNotifier<bool> {
  final FlutterSecureStorage _storage;
  final String _key;

  SecureBoolNotifier(this._storage, this._key) : super(false) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    if (value != null) state = value == 'true';
  }

  Future<void> setValue(bool value) async {
    state = value;
    await _storage.write(key: _key, value: value.toString());
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

String _defaultModelForProvider(AiProvider provider) {
  switch (provider) {
    case AiProvider.openai:
      return AppConstants.defaultOpenAiModel;
    case AiProvider.gemini:
      return AppConstants.defaultGeminiModel;
    case AiProvider.mistral:
      return AppConstants.defaultMistralModel;
    case AiProvider.ollama:
      return AppConstants.defaultOllamaModel;
  }
}

/// Service IA dédié à l'analyse d'images, avec prise en charge des overrides
/// de modèle et de clé API configurés dans les paramètres.
///
/// - Si aucun override n'est défini : délègue directement à [aiServiceProvider].
/// - Si un modèle vision est défini : l'utilise à la place du modèle principal.
/// - Si une clé API vision est définie : l'utilise à la place de la clé principale.
/// - Ollama ne supporte pas la vision : retourne toujours null.
final visionAiServiceProvider = Provider<AiService?>((ref) {
  final mainProvider = ref.watch(aiProviderSettingProvider);
  final visionProviderOverride = ref.watch(visionProviderOverrideProvider);
  final visionModelOverride = ref.watch(visionModelOverrideProvider);
  final visionApiKeyOverride = ref.watch(visionApiKeyOverrideProvider);

  final provider = AiProvider.values.firstWhere(
    (candidate) => candidate.name == visionProviderOverride,
    orElse: () => mainProvider,
  );

  final hasVisionModel =
      visionModelOverride != null && visionModelOverride.isNotEmpty;
  final hasVisionKey =
      visionApiKeyOverride != null && visionApiKeyOverride.isNotEmpty;

  // Ollama ne supporte pas la vision, quelle que soit la configuration.
  if (provider == AiProvider.ollama) return null;

  // Sans override, on délègue au service principal.
  if (!hasVisionModel && !hasVisionKey) {
    return ref.watch(aiServiceProvider);
  }

  // Avec au moins un override, on construit un service vision dédié.
  final mainOpenAiKey = ref.watch(openAiApiKeyProvider);
  final mainGeminiKey = ref.watch(geminiApiKeyProvider);
  final mainMistralKey = ref.watch(mistralApiKeyProvider);
  final mainModel = ref.watch(selectedModelProvider);

  String effectiveModel() {
    if (hasVisionModel) return visionModelOverride;

    // Si un fournisseur vision spécifique est choisi, on évite de réutiliser
    // le modèle principal (souvent d'un autre fournisseur).
    final hasProviderOverride =
        visionProviderOverride != null && visionProviderOverride.isNotEmpty;
    if (hasProviderOverride) {
      return _defaultModelForProvider(provider);
    }

    return mainModel ?? _defaultModelForProvider(provider);
  }

  String effectiveKey(String? mainKey) {
    if (hasVisionKey) return visionApiKeyOverride;
    return mainKey ?? '';
  }

  switch (provider) {
    case AiProvider.openai:
      final key = effectiveKey(mainOpenAiKey);
      if (key.isEmpty) return null;
      return OpenAiService(
        apiKey: key,
        model: effectiveModel(),
      );
    case AiProvider.gemini:
      final key = effectiveKey(mainGeminiKey);
      if (key.isEmpty) return null;
      return GeminiService(
        apiKey: key,
        model: _sanitizeGeminiModel(effectiveModel()),
      );
    case AiProvider.mistral:
      final key = effectiveKey(mainMistralKey);
      if (key.isEmpty) return null;
      return MistralService(
        apiKey: key,
        model: effectiveModel(),
      );
    case AiProvider.ollama:
      return null;
  }
});

// ============ Use Cases — Wine ============

final addWineUseCaseProvider = Provider<AddWineUseCase>((ref) {
  return AddWineUseCase(ref.watch(wineRepositoryProvider));
});

/// GeminiService dédié à la recherche web (complétion de champs estimés).
/// Utilise la clé fallback Gemini si le fournisseur principal n'est pas Gemini,
/// sinon réutilise la clé Gemini principale.
final geminiWebSearchServiceProvider = Provider<GeminiService?>((ref) {
  final mainProvider = ref.watch(aiProviderSettingProvider);
  final mainGeminiKey = ref.watch(geminiApiKeyProvider);
  final fallbackKey = ref.watch(geminiFallbackApiKeyProvider);

  // Si Gemini est le fournisseur principal, utiliser sa clé.
  if (mainProvider == AiProvider.gemini) {
    if (mainGeminiKey == null || mainGeminiKey.isEmpty) return null;
    final model = ref.watch(selectedModelProvider);
    return GeminiService(
      apiKey: mainGeminiKey,
      model: _sanitizeGeminiModel(model),
    );
  }

  // Sinon, utiliser la clé fallback.
  if (fallbackKey == null || fallbackKey.isEmpty) return null;
  return GeminiService(
    apiKey: fallbackKey,
    model: AppConstants.defaultGeminiModel,
  );
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

// ============ Use Cases — Virtual Cellar ============

final getAllVirtualCellarsUseCaseProvider =
    Provider<GetAllVirtualCellarsUseCase>((ref) {
  return GetAllVirtualCellarsUseCase(ref.watch(virtualCellarRepositoryProvider));
});

final createVirtualCellarUseCaseProvider =
    Provider<CreateVirtualCellarUseCase>((ref) {
  return CreateVirtualCellarUseCase(ref.watch(virtualCellarRepositoryProvider));
});

final updateVirtualCellarUseCaseProvider =
    Provider<UpdateVirtualCellarUseCase>((ref) {
  return UpdateVirtualCellarUseCase(ref.watch(virtualCellarRepositoryProvider));
});

final deleteVirtualCellarUseCaseProvider =
    Provider<DeleteVirtualCellarUseCase>((ref) {
  return DeleteVirtualCellarUseCase(ref.watch(virtualCellarRepositoryProvider));
});

final placeWineInCellarUseCaseProvider =
    Provider<PlaceWineInCellarUseCase>((ref) {
  return PlaceWineInCellarUseCase(ref.watch(virtualCellarRepositoryProvider));
});

final removeBottlePlacementUseCaseProvider =
    Provider<RemoveBottlePlacementUseCase>((ref) {
  return RemoveBottlePlacementUseCase(
    ref.watch(virtualCellarRepositoryProvider),
  );
});

final getWinePlacementsUseCaseProvider =
    Provider<GetWinePlacementsUseCase>((ref) {
  return GetWinePlacementsUseCase(ref.watch(virtualCellarRepositoryProvider));
});

final moveBottlesInCellarUseCaseProvider =
    Provider<MoveBottlesInCellar>((ref) {
  return MoveBottlesInCellar(ref.watch(virtualCellarRepositoryProvider));
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
/// Utilise [visionAiServiceProvider] pour respecter les overrides
/// de modèle/clé API dédiés à l'analyse d'images.
final analyzeWineFromImageUseCaseProvider =
    Provider<AnalyzeWineFromImageUseCase?>((ref) {
  final visionService = ref.watch(visionAiServiceProvider);
  if (visionService == null) return null;
  return AnalyzeWineFromImageUseCase(visionService);
});

final testAiConnectionUseCaseProvider =
    Provider<TestAiConnectionUseCase?>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  if (aiService == null) return null;
  return TestAiConnectionUseCase(aiService);
});

/// Discovers which vision-capable model is available.
/// Utilise [visionAiServiceProvider] pour refléter les overrides éventuels.
/// Auto-invalidated when the service changes (API key, provider, model).
final visionModelProvider = FutureProvider.autoDispose<String?>((ref) async {
  final visionService = ref.watch(visionAiServiceProvider);
  if (visionService == null) return null;
  return visionService.discoverVisionModel();
});

// ============ Developer Mode ============

/// Whether the developer mode is enabled.
///
/// Future: wrap the setter with `if (!kReleaseMode)` to hide in production.
final developerModeProvider =
    StateNotifierProvider<SecureBoolNotifier, bool>((ref) {
  return SecureBoolNotifier(
    ref.watch(secureStorageProvider),
    AppConstants.keyDeveloperMode,
  );
});
