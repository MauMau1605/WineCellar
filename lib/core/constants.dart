/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Ma Cave à Vin';
  static const String appVersion = '0.1.0';

  // Database
  static const String databaseName = 'wine_cellar.db';
  static const int databaseVersion = 3;

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

  // Wine defaults
  static const int maxRating = 5;
  static const int defaultQuantity = 1;
}
