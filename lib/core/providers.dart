import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/wine_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/food_category_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/food_category_repository.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/openai_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/ollama_service.dart';

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
  final ollamaUrl = ref.watch(ollamaUrlProvider);
  final model = ref.watch(selectedModelProvider);

  switch (provider) {
    case AiProvider.openai:
      if (apiKey == null || apiKey.isEmpty) return null;
      return OpenAiService(
        apiKey: apiKey,
        model: model ?? AppConstants.defaultOpenAiModel,
      );
    case AiProvider.ollama:
      return OllamaService(
        baseUrl: ollamaUrl ?? AppConstants.defaultOllamaUrl,
        model: model ?? AppConstants.defaultOllamaModel,
      );
  }
});
