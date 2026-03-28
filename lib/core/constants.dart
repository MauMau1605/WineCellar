/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Ma Cave à Vin';
  static const String appVersion = '0.1.0';

  // Database
  static const String databaseName = 'wine_cellar.db';
  static const int databaseVersion = 6;

  // AI defaults
  static const String defaultOllamaUrl = 'http://localhost:11434';
  static const String defaultOpenAiModel = 'gpt-4o-mini';
  static const String defaultGeminiModel = 'gemini-2.5-flash-lite';
  static const String defaultOllamaModel = 'llama3';
  static const String defaultMistralModel = 'mistral-small-latest';

  // Secure storage keys
  static const String keyAiProvider = 'ai_provider';
  static const String keyOpenAiApiKey = 'openai_api_key';
  static const String keyGeminiApiKey = 'gemini_api_key';
  static const String keyMistralApiKey = 'mistral_api_key';
  static const String keyOllamaUrl = 'ollama_url';
  static const String keySelectedModel = 'selected_model';

  // Vision / image analysis settings
  /// Fournisseur dédié à l'analyse d'image (optionnel).
  /// Si absent, le fournisseur principal est utilisé.
  static const String keyVisionProviderOverride = 'vision_provider_override';

  /// Modèle dédié à l'analyse d'image (optionnel — remplace le modèle principal)
  static const String keyVisionModel = 'vision_model';

  /// Clé API dédiée à l'analyse d'image (optionnel — remplace la clé principale)
  static const String keyVisionApiKeyOverride = 'vision_api_key_override';

  /// Si true, utilise l'OCR local (MLKit) au lieu de l'analyse IA multimodale
  static const String keyUseOcrForImages = 'use_ocr_for_images';

  /// Clé API Gemini dédiée à la recherche web (fallback pour compléter les champs estimés)
  static const String keyGeminiFallbackApiKey = 'gemini_fallback_api_key';

  // Expert cellar editor
  static const String keyExpertCellarDraft = 'expert_cellar_draft';

  // Visual theme
  static const String keyAppVisualTheme = 'app_visual_theme';

  // Wine defaults
  static const int maxRating = 5;
  static const int defaultQuantity = 1;
}
