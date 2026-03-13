import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';

/// Settings screen for AI provider configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _geminiApiKeyController = TextEditingController();
  final _mistralApiKeyController = TextEditingController();
  final _ollamaUrlController = TextEditingController();
  final _modelController = TextEditingController();
  final _visionModelController = TextEditingController();
  final _visionApiKeyController = TextEditingController();
  AiProvider? _visionProviderOverride;
  bool _obscureApiKey = true;
  bool _obscureVisionApiKey = true;
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
    final geminiApiKey = ref.read(geminiApiKeyProvider);
    final mistralApiKey = ref.read(mistralApiKeyProvider);
    final ollamaUrl = ref.read(ollamaUrlProvider);
    final model = ref.read(selectedModelProvider);
    final visionProviderName = ref.read(visionProviderOverrideProvider);
    final visionModel = ref.read(visionModelOverrideProvider);
    final visionApiKey = ref.read(visionApiKeyOverrideProvider);

    final parsedVisionProvider = AiProvider.values.where(
      (provider) => provider.name == visionProviderName,
    );

    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _geminiApiKeyController.text = geminiApiKey ?? '';
      _mistralApiKeyController.text = mistralApiKey ?? '';
      _ollamaUrlController.text =
          ollamaUrl ?? AppConstants.defaultOllamaUrl;
      _modelController.text = model ?? '';
      _visionProviderOverride =
          parsedVisionProvider.isEmpty ? null : parsedVisionProvider.first;
      _visionModelController.text = visionModel ?? '';
      _visionApiKeyController.text = visionApiKey ?? '';
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _geminiApiKeyController.dispose();
    _mistralApiKeyController.dispose();
    _ollamaUrlController.dispose();
    _modelController.dispose();
    _visionModelController.dispose();
    _visionApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentProvider = ref.watch(aiProviderSettingProvider);
    final visionModel = ref.watch(visionModelProvider);
    final useOcr = ref.watch(useOcrForImagesProvider);
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
                      switch (provider) {
                        AiProvider.openai => 'GPT-4o-mini recommandé. Nécessite une clé API.',
                        AiProvider.gemini => 'Gemini 2.0 Flash gratuit. Nécessite une clé API Google.',
                        AiProvider.mistral => 'Mistral Small performant. Nécessite une clé API Mistral.',
                        AiProvider.ollama => 'Gratuit, fonctionne hors-ligne. Nécessite Ollama installé.',
                      },
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
                    if (visionModel.hasValue && visionModel.value != null) ...[  
                      const SizedBox(height: 12),
                      _VisionModelChip(modelName: visionModel.value!),
                    ],
                  ],
                ),
              ),
            ),
          ],

          if (currentProvider == AiProvider.gemini) ...[
            Text(
              'Configuration Google Gemini',
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
                      controller: _geminiApiKeyController,
                      decoration: InputDecoration(
                        labelText: 'Clé API Gemini',
                        hintText: 'AIza...',
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
                        hintText: 'gemini-2.5-flash-lite',
                        prefixIcon: Icon(Icons.smart_toy),
                        helperText:
                            'Recommandé : gemini-2.5-flash-lite',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Obtenez votre clé gratuite sur aistudio.google.com',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (currentProvider == AiProvider.mistral) ...[
            Text(
              'Configuration Mistral AI',
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
                      controller: _mistralApiKeyController,
                      decoration: InputDecoration(
                        labelText: 'Clé API Mistral',
                        hintText: '',
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
                        hintText: 'mistral-small-latest',
                        prefixIcon: Icon(Icons.smart_toy),
                        helperText:
                            'Recommandé : mistral-small-latest (bon rapport qualité/prix)',
                      ),
                    ),
                    if (visionModel.hasValue && visionModel.value != null) ...[  
                      const SizedBox(height: 8),
                      _VisionModelChip(modelName: visionModel.value!),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Obtenez votre clé sur console.mistral.ai',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
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

          // -------- Section : Analyse d'image --------
          Text(
            'Analyse d\'image',
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.text_fields_outlined),
                    title: const Text('OCR local (Google MLKit)'),
                    subtitle: const Text(
                      'Extrait le texte de l\'étiquette sur l\'appareil, '
                      'sans envoyer l\'image à l\'IA.\n'
                      'Recommandé si votre fournisseur ne supporte pas la vision.',
                    ),
                    value: useOcr,
                    onChanged: (value) => ref
                        .read(useOcrForImagesProvider.notifier)
                        .setValue(value),
                  ),
                  if (!useOcr) ...[
                    const Divider(height: 24),
                    Text(
                      'Overrides vision IA (optionnels)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AiProvider?>(
                      initialValue: _visionProviderOverride,
                      decoration: const InputDecoration(
                        labelText: 'Fournisseur pour l\'analyse d\'image',
                        prefixIcon: Icon(Icons.hub_outlined),
                        helperText:
                            'Par défaut: même fournisseur que le chat.',
                      ),
                      items: [
                        const DropdownMenuItem<AiProvider?>(
                          value: null,
                          child: Text('Utiliser le fournisseur principal'),
                        ),
                        ...AiProvider.values
                            .where((provider) => provider != AiProvider.ollama)
                            .map(
                              (provider) => DropdownMenuItem<AiProvider?>(
                                value: provider,
                                child: Text(provider.label),
                              ),
                            ),
                      ],
                      onChanged: (value) {
                        setState(() => _visionProviderOverride = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _visionModelController,
                      decoration: const InputDecoration(
                        labelText: 'Modèle dédié à la vision',
                        hintText: 'ex: gpt-4o, gemini-2.0-flash-exp…',
                        prefixIcon: Icon(Icons.camera_alt_outlined),
                        helperText:
                            'Laissez vide pour utiliser le modèle principal.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _visionApiKeyController,
                      decoration: InputDecoration(
                        labelText: 'Clé API dédiée à la vision',
                        hintText: 'sk-… / AIza… / …',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        helperText:
                            'Laissez vide pour utiliser la clé principale.',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureVisionApiKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => _obscureVisionApiKey = !_obscureVisionApiKey,
                          ),
                        ),
                      ),
                      obscureText: _obscureVisionApiKey,
                    ),
                    const SizedBox(height: 8),
                    if (visionModel.hasValue && visionModel.value != null) ...[
                      _VisionModelChip(modelName: visionModel.value!),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'OpenAI : gpt-4o-mini  •  Gemini : gemini-2.0-flash  •  Mistral : pixtral-12b-latest',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

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

    await ref
        .read(geminiApiKeyProvider.notifier)
        .setValue(_geminiApiKeyController.text.isNotEmpty ? _geminiApiKeyController.text : null);

    await ref
        .read(mistralApiKeyProvider.notifier)
        .setValue(_mistralApiKeyController.text.isNotEmpty ? _mistralApiKeyController.text : null);

    await ref.read(ollamaUrlProvider.notifier).setValue(
          _ollamaUrlController.text.isNotEmpty
              ? _ollamaUrlController.text
              : null,
        );

    final defaultModel = switch (currentProvider) {
      AiProvider.openai => AppConstants.defaultOpenAiModel,
      AiProvider.gemini => AppConstants.defaultGeminiModel,
      AiProvider.mistral => AppConstants.defaultMistralModel,
      AiProvider.ollama => AppConstants.defaultOllamaModel,
    };
    await ref.read(selectedModelProvider.notifier).setValue(
          _modelController.text.isNotEmpty ? _modelController.text : defaultModel,
        );

    // Overrides vision (stockés que si non vides)
    await ref.read(visionProviderOverrideProvider.notifier).setValue(
        _visionProviderOverride?.name,
      );
    await ref.read(visionModelOverrideProvider.notifier).setValue(
          _visionModelController.text.isNotEmpty
              ? _visionModelController.text
              : null,
        );
    await ref.read(visionApiKeyOverrideProvider.notifier).setValue(
          _visionApiKeyController.text.isNotEmpty
              ? _visionApiKeyController.text
              : null,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres enregistrés !')),
      );
    }
  }

  Future<void> _testConnection() async {
    // Invalidate vision model cache so it re-discovers with updated settings
    ref.invalidate(visionModelProvider);

    // Save first
    await _saveSettings();

    setState(() => _testingConnection = true);

    final testUseCase = ref.read(testAiConnectionUseCaseProvider);
    if (testUseCase == null) {
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

    final result = await testUseCase(const NoParams());

    setState(() => _testingConnection = false);

    if (mounted) {
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Échec : ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        },
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connexion réussie ! ✅'),
              backgroundColor: Colors.green,
            ),
          );
        },
      );
    }
  }
}

/// Small info chip displayed below the model field when a vision-capable model
/// has been auto-discovered for the current provider.
class _VisionModelChip extends StatelessWidget {
  const _VisionModelChip({required this.modelName});

  final String modelName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.secondary.withAlpha(60),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 14,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Vision disponible : $modelName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
