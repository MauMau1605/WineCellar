import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';

/// Settings screen for AI provider configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _ollamaUrlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _obscureApiKey = true;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Wait for providers to load initial values
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final apiKey = ref.read(openAiApiKeyProvider);
    final ollamaUrl = ref.read(ollamaUrlProvider);
    final model = ref.read(selectedModelProvider);

    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _ollamaUrlController.text =
          ollamaUrl ?? AppConstants.defaultOllamaUrl;
      _modelController.text = model ?? '';
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _ollamaUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentProvider = ref.watch(aiProviderSettingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: AI Provider
          Text(
            'Fournisseur d\'IA',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<AiProvider>(
              groupValue: currentProvider,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(aiProviderSettingProvider.notifier)
                      .setProvider(value);
                }
              },
              child: Column(
                children: AiProvider.values.map((provider) {
                  return RadioListTile<AiProvider>(
                    title: Text(provider.label),
                    subtitle: Text(
                      provider == AiProvider.openai
                          ? 'GPT-4o-mini recommandé. Nécessite une clé API.'
                          : 'Gratuit, fonctionne hors-ligne. Nécessite Ollama installé.',
                    ),
                    value: provider,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Provider-specific settings
          if (currentProvider == AiProvider.openai) ...[
            Text(
              'Configuration OpenAI',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        labelText: 'Clé API OpenAI',
                        hintText: 'sk-...',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                      ),
                      obscureText: _obscureApiKey,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Modèle',
                        hintText: 'gpt-4o-mini',
                        prefixIcon: Icon(Icons.smart_toy),
                        helperText:
                            'Recommandé : gpt-4o-mini (pas cher et efficace)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (currentProvider == AiProvider.ollama) ...[
            Text(
              'Configuration Ollama',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _ollamaUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL du serveur Ollama',
                        hintText: 'http://localhost:11434',
                        prefixIcon: Icon(Icons.link),
                        helperText: 'Défaut: http://localhost:11434',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Modèle',
                        hintText: 'llama3',
                        prefixIcon: Icon(Icons.smart_toy),
                        helperText: 'Recommandé : llama3 ou mistral',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Save & Test buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: _testingConnection
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: Text(
                      _testingConnection ? 'Test...' : 'Tester la connexion'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // About section
          Text(
            'À propos',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.wine_bar),
              title: const Text(AppConstants.appName),
              subtitle: Text('Version ${AppConstants.appVersion}'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final currentProvider = ref.read(aiProviderSettingProvider);

    await ref
        .read(openAiApiKeyProvider.notifier)
        .setValue(_apiKeyController.text.isNotEmpty ? _apiKeyController.text : null);

    await ref.read(ollamaUrlProvider.notifier).setValue(
          _ollamaUrlController.text.isNotEmpty
              ? _ollamaUrlController.text
              : null,
        );

    final defaultModel = currentProvider == AiProvider.openai
        ? AppConstants.defaultOpenAiModel
        : AppConstants.defaultOllamaModel;
    await ref.read(selectedModelProvider.notifier).setValue(
          _modelController.text.isNotEmpty ? _modelController.text : defaultModel,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres enregistrés !')),
      );
    }
  }

  Future<void> _testConnection() async {
    // Save first
    await _saveSettings();

    setState(() => _testingConnection = true);

    final aiService = ref.read(aiServiceProvider);
    if (aiService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez configurer la clé API d\'abord'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _testingConnection = false);
      return;
    }

    final success = await aiService.testConnection();

    setState(() => _testingConnection = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Connexion réussie ! ✅' : 'Échec de la connexion ❌',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
