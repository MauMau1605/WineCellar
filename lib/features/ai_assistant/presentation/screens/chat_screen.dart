import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wine_cellar/core/chat_logger.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_request_strategy.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine_from_image.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/extract_text_from_wine_image.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/widgets/chat_bubble.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/widgets/wine_preview_card.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';
import 'package:wine_cellar/features/ai_assistant/data/ai_prompts.dart';

enum _DuplicateChoice { incrementExisting, createNew }

enum _PreAddChoice { edit, continueAdd }

enum _PlacementChoice { none, associateOnly, placeInSlot }

class _CreateNewCellarChoice {
  const _CreateNewCellarChoice();
}

/// The three modes available in the AI chat.
enum _ChatMode { addWine, foodPairing, wineReview }

/// Data passed from the add-wine screen to pre-fill the AI chat.
class PrefillData {
  /// Text shown in the chat bubble (field list only).
  final String displayText;

  /// Full prompt sent to the AI (instructions + field list).
  final String aiPrompt;

  const PrefillData({required this.displayText, required this.aiPrompt});
}

/// AI Chat screen for adding wines via natural language
class ChatScreen extends ConsumerStatefulWidget {
  /// Set before navigating to /chat to pre-fill and auto-send.
  static PrefillData? pendingPrefill;

  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  static List<ChatMessage> _sessionMessages = [];
  static List<WineAiResponse> _sessionWineDataList = [];
  static _ChatMode _sessionChatMode = _ChatMode.addWine;

  final List<ChatMessage> _messages = [];
  List<WineAiResponse> _currentWineDataList = [];
  final Set<int> _addedWineIndices = {};
  final Set<int> _manuallyEditedWineIndices = {};
  final Set<int> _autoWebCompletionAttemptedIndices = {};
  bool _isLoading = false;
  _ChatMode _chatMode = _ChatMode.addWine;
  final _chatLogger = ChatLogger();
  PrefillData? _prefillData;

  @override
  void initState() {
    super.initState();
    // Consume and clear the pending prefill data (if any).
    _prefillData = ChatScreen.pendingPrefill;
    ChatScreen.pendingPrefill = null;

    if (_sessionMessages.isEmpty) {
      _chatLogger.startSession();
      _messages.add(_buildWelcomeMessage());
      _cacheConversationState();
    } else {
      _messages.addAll(_sessionMessages);
      _currentWineDataList = List<WineAiResponse>.from(_sessionWineDataList);
      _chatMode = _sessionChatMode;
    }
    _handlePrefillMessage();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiService = ref.watch(aiServiceProvider);
    final analyzeUseCase = ref.watch(analyzeWineUseCaseProvider);
    final isConfigured = aiService != null && analyzeUseCase != null;
    final hasWebSearch = aiService?.supportsWebSearch == true ||
        ref.watch(geminiWebSearchServiceProvider) != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant IA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Ouvrir le dossier des logs',
            onPressed: _showLogsInfo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Remettre l\'historique à zéro',
            onPressed: _confirmResetConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          // API key warning
          if (!isConfigured)
            MaterialBanner(
              content: const Text(
                'Configurez votre clé API dans les paramètres pour utiliser l\'assistant IA.',
              ),
              leading: const Icon(Icons.warning_amber, color: Colors.orange),
              actions: [
                TextButton(
                  onPressed: () => context.go('/settings'),
                  child: const Text('Paramètres'),
                ),
              ],
            ),

          // Mode selector
          _buildModeSelector(),

          // No-internet warning (only when AI is configured but no web access)
          if (isConfigured && !hasWebSearch)
            _buildNoWebSearchBanner(theme),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _chatMode == _ChatMode.foodPairing
                              ? 'L\'IA cherche dans votre cave...'
                              : _chatMode == _ChatMode.wineReview
                                  ? 'Recherche d\'avis sur internet...'
                                  : 'L\'IA analyse votre vin...',
                        ),
                      ],
                    ),
                  );
                }

                final message = _messages[index];
                return Column(
                  children: [
                    ChatBubble(
                      message: message,
                      onLinkTap: _handleAssistantLinkTap,
                    ),
                    // Show wine preview cards after the last AI message
                    if (message.role == ChatRole.assistant &&
                        _currentWineDataList.isNotEmpty &&
                        index == _messages.length - 1)
                      ..._buildWinePreviewCards(context),
                  ],
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Photo button
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    onPressed: isConfigured && !_isLoading
                        ? _captureWinePhotoAndAnalyze
                        : null,
                    tooltip: 'Photo ou galerie',
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: _chatMode == _ChatMode.foodPairing
                            ? 'Décrivez votre repas...'
                            : _chatMode == _ChatMode.wineReview
                                ? 'Quel vin souhaitez-vous évaluer ?'
                                : 'Décrivez votre vin...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: isConfigured && !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: isConfigured && !_isLoading
                        ? _sendMessage
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    await _sendText(text);
  }

  Future<void> _captureWinePhotoAndAnalyze() async {
    if (_isLoading) return;

    final useOcr = ref.read(useOcrForImagesProvider);

    // En mode vision IA, on vérifie qu'un service est configuré.
    if (!useOcr) {
      final analyzeImageUseCase = ref.read(analyzeWineFromImageUseCaseProvider);
      if (analyzeImageUseCase == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Configurez votre clé API avant d\'utiliser la caméra.',
            ),
          ),
        );
        return;
      }
    }

    final source = await _showImageSourceDialog();
    if (source == null) return;

    final imagePicker = ImagePicker();
    final image = await imagePicker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
    );

    if (image == null) return;

    final sourceText = source == ImageSource.camera ? 'caméra' : 'galerie';

    setState(() {
      _messages.add(
        ChatMessage(
          id: _uuid.v4(),
          content: '📷 Image envoyée depuis $sourceText',
          role: ChatRole.user,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    if (useOcr) {
      await _analyzeWithOcr(image.path);
    } else {
      await _analyzeWithVision(image.path);
    }
  }

  /// Branche OCR : extrait le texte via MLKit puis envoie au chat texte.
  Future<void> _analyzeWithOcr(String imagePath) async {
    final extractUseCase = ref.read(extractTextFromWineImageUseCaseProvider);
    final either = await extractUseCase(
      ExtractTextFromWineImageParams(imagePath: imagePath),
    );

    if (!mounted) return;

    either.fold(
      (failure) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (extractedText) async {
        setState(() => _isLoading = false);
        // Texte visible dans le chat (résumé).
        const displayText = '🔍 Texte extrait par OCR — analyse en cours…';
        // Prompt complet envoyé à l\'IA.
        final aiPrompt =
            'J\'ai photographié une étiquette de vin. '
            'Voici le texte extrait par OCR :\n\n$extractedText\n\n'
            'Analyse ces informations et retourne la réponse '
            'au format JSON habituel, sans raisonnement long.';
        await _sendText(displayText, aiMessage: aiPrompt);
      },
    );
  }

  /// Branche vision IA : envoie les bytes de l\'image directement au modèle multimodal.
  Future<void> _analyzeWithVision(String imagePath) async {
    final analyzeImageUseCase = ref.read(analyzeWineFromImageUseCaseProvider);
    if (analyzeImageUseCase == null) {
      setState(() => _isLoading = false);
      return;
    }

    final imageBytes = await File(imagePath).readAsBytes();
    final mimeType = _guessMimeTypeFromPath(imagePath);
    final history = _messages
        .where((m) => m.role != ChatRole.system)
        .map(
          (m) => {
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();

    final either = await analyzeImageUseCase(
      AnalyzeWineFromImageParams(
        imageBytes: imageBytes,
        mimeType: mimeType,
        userMessage:
            'Extrait les informations du vin visibles sur l\'image et retourne la réponse au format JSON habituel, sans raisonnement long.',
        conversationHistory: history,
      ),
    );

    if (!mounted) return;

    either.fold(
      (failure) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (result) {
        _chatLogger.logAiResponse(result.textResponse);

        setState(() {
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content: result.textResponse,
              role: ChatRole.assistant,
              timestamp: DateTime.now(),
            ),
          );
          _currentWineDataList = result.wineDataList;
          _addedWineIndices.clear();
          _isLoading = false;
        });
        _cacheConversationState();
        _scrollToBottom();
      },
    );
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choisir une image'),
        content: const Text('Sélectionnez la source de l\'image à analyser.'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galerie'),
          ),
          TextButton.icon(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Caméra'),
          ),
        ],
      ),
    );
  }

  String _guessMimeTypeFromPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Sends a message to the AI.
  ///
  /// [text] is displayed in the chat bubble.
  /// If [aiMessage] is provided it is sent to the AI instead of [text],
  /// allowing the visible message to differ from the actual prompt.
  Future<void> _sendText(String text, {String? aiMessage}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    final analyzeUseCase = ref.read(analyzeWineUseCaseProvider);
    if (analyzeUseCase == null) return;

    AddWineMessageIntent? addWineIntent;
    if (aiMessage == null && _chatMode == _ChatMode.addWine) {
      addWineIntent = await _resolveAddWineIntent(trimmed);
      if (addWineIntent == null) return;
    }

    final isNewWineRequest = addWineIntent == AddWineMessageIntent.newWine;

    if (isNewWineRequest) {
      _resetAiServiceChatSession();
    }

    setState(() {
      _messages.add(
        ChatMessage(
          id: _uuid.v4(),
          content: trimmed,
          role: ChatRole.user,
          timestamp: DateTime.now(),
        ),
      );

      if (isNewWineRequest) {
        _currentWineDataList = [];
        _addedWineIndices.clear();
        _manuallyEditedWineIndices.clear();
        _autoWebCompletionAttemptedIndices.clear();
      }

      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    var history = _messages
        .where((m) => m.role != ChatRole.system)
        .map(
          (m) => {
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();

    if (history.isNotEmpty) history.removeLast();
    if (isNewWineRequest) {
      // Fresh conversation context for a new wine request.
      history = const [];
    }

    String messageToSend = aiMessage?.trim() ?? trimmed;
    List<WineEntity> cellarWinesForSearch = const [];
    if (aiMessage == null && _chatMode == _ChatMode.foodPairing) {
      final wines = await ref.read(wineRepositoryProvider).getAllWines();
      cellarWinesForSearch = wines;
      final cellarSummary = _buildCellarSummary(wines);
      messageToSend = AiPrompts.buildCellarSearchMessage(
        userQuestion: trimmed,
        cellarSummary: cellarSummary,
      );
    } else if (aiMessage == null && _chatMode == _ChatMode.wineReview) {
      final aiService = ref.read(aiServiceProvider);
      final geminiWebSearch = ref.read(geminiWebSearchServiceProvider);
      if (aiService != null && aiService.supportsWebSearch) {
        messageToSend = AiPrompts.buildGroundedReviewMessage(
          userQuestion: trimmed,
        );
      } else if (geminiWebSearch != null) {
        // Fallback: use Gemini web search service directly
        messageToSend = AiPrompts.buildGroundedReviewMessage(
          userQuestion: trimmed,
        );
      } else {
        messageToSend = AiPrompts.buildWineReviewMessage(
          userQuestion: trimmed,
        );
      }
    } else if (aiMessage == null && _chatMode == _ChatMode.addWine) {
      if (addWineIntent == AddWineMessageIntent.newWine) {
        messageToSend = AiPrompts.buildNewWineStandaloneMessage(
          userMessage: trimmed,
        );
      } else if (addWineIntent == AddWineMessageIntent.refineCurrentWine) {
        messageToSend = AiPrompts.buildCurrentWineRefinementMessage(
          userMessage: trimmed,
          currentWineSummary: _buildCurrentWineSummaryForRefinement(),
        );
      }
    }

    _chatLogger.logUserMessage(trimmed);

    final mainServiceSupportsWebSearch =
        ref.read(aiServiceProvider)?.supportsWebSearch == true;
    final geminiWebSearch = ref.read(geminiWebSearchServiceProvider);
    final useWebSearchForReview = _chatMode == _ChatMode.wineReview &&
        (mainServiceSupportsWebSearch || geminiWebSearch != null);

    // If review mode with fallback Gemini (main service doesn't support web search),
    // call the Gemini service directly instead of going through the main use case.
    if (useWebSearchForReview && !mainServiceSupportsWebSearch && geminiWebSearch != null) {
      try {
        final result = await geminiWebSearch.analyzeWineWithWebSearch(
          userMessage: messageToSend,
          conversationHistory: history,
        );
        if (!mounted) return;
        _handleWebSearchResult(result);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content: 'Erreur de recherche web : $e',
              role: ChatRole.assistant,
              timestamp: DateTime.now(),
            ),
          );
        });
      }
      _cacheConversationState();
      _scrollToBottom();
      return;
    }

    final either = await analyzeUseCase(
      AnalyzeWineParams(
        userMessage: messageToSend,
        conversationHistory: history,
        useWebSearch: useWebSearchForReview,
      ),
    );

    await either.fold(
      (failure) async {
        _chatLogger.logError(failure.message);
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content: failure.message,
              role: ChatRole.assistant,
              timestamp: DateTime.now(),
            ),
          );
        });
      },
      (result) async {
        _chatLogger.logAiResponse(result.textResponse);
        final assistantText = _chatMode == _ChatMode.foodPairing
            ? _appendWineDetailLinksToResponse(
                result.textResponse,
                cellarWinesForSearch,
              )
            : result.textResponse;

        var recoveredWineDataList = result.wineDataList;
        if (_chatMode == _ChatMode.addWine && recoveredWineDataList.isEmpty) {
          recoveredWineDataList = await _recoverWineDataIfMissing(
            analyzeUseCase: analyzeUseCase,
            baseHistory: history,
            originalUserMessage: messageToSend,
            assistantResponse: result.textResponse,
          );
        }

        final chatSources = _chatSourcesFromWebSources(result.webSources);
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content: assistantText,
              role: ChatRole.assistant,
              timestamp: DateTime.now(),
              webSources: chatSources,
              collapseSourcesByDefault: chatSources.isNotEmpty,
            ),
          );

          if (recoveredWineDataList.isNotEmpty) {
            _currentWineDataList = recoveredWineDataList;
            _addedWineIndices.clear();
            _autoWebCompletionAttemptedIndices.clear();
          }
        });

        if (_chatMode == _ChatMode.addWine && _isAutoWebCompletionEnabled()) {
          await _autoCompleteEstimatedFieldsIfNeeded();
        }
      },
    );
    _cacheConversationState();
    _scrollToBottom();
  }

  /// Handle a web search result (used by fallback Gemini path).
  void _handleWebSearchResult(AiChatResult result) {
    _chatLogger.logAiResponse(result.textResponse);
    final assistantText = result.textResponse;
    final chatSources = _chatSourcesFromWebSources(result.webSources);
    setState(() {
      _isLoading = false;
      _messages.add(
        ChatMessage(
          id: _uuid.v4(),
          content: assistantText,
          role: ChatRole.assistant,
          timestamp: DateTime.now(),
          webSources: chatSources,
          collapseSourcesByDefault: chatSources.isNotEmpty,
        ),
      );
    });
  }

  bool _isAutoWebCompletionEnabled() {
    final geminiService = ref.read(geminiWebSearchServiceProvider);
    return geminiService != null;
  }

  static const int _webCompletionBatchSize = 10;

  Future<void> _autoCompleteEstimatedFieldsIfNeeded() async {
    if (_chatMode != _ChatMode.addWine) return;
    if (!_isAutoWebCompletionEnabled()) return;

    // Collect all indices requiring web completion.
    final indicesToComplete = <int>[];
    for (var i = 0; i < _currentWineDataList.length; i++) {
      if (_autoWebCompletionAttemptedIndices.contains(i)) continue;
      if (_addedWineIndices.contains(i)) continue;

      final wine = _currentWineDataList[i];
      if (wine.name == null || wine.estimatedFields.isEmpty) continue;

      final decision = AiRequestStrategy.decideWebSearchForWineCompletion(wine);
      if (!decision.shouldUseWebSearch) {
        _autoWebCompletionAttemptedIndices.add(i);
        continue;
      }

      indicesToComplete.add(i);
    }

    if (indicesToComplete.isEmpty) return;

    final totalBatches =
        (indicesToComplete.length / _webCompletionBatchSize).ceil();

    for (var batchNum = 0; batchNum < totalBatches; batchNum++) {
      final start = batchNum * _webCompletionBatchSize;
      final end = (start + _webCompletionBatchSize)
          .clamp(0, indicesToComplete.length);
      final batchIndices = indicesToComplete.sublist(start, end);

      // Show a progress message only when multiple batches are needed.
      if (totalBatches > 1) {
        setState(() {
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content:
                  '🌐 Complétion internet — lot ${batchNum + 1}/$totalBatches '
                  '(${batchIndices.length} vin(s))…',
              role: ChatRole.system,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }

      for (final i in batchIndices) {
        _autoWebCompletionAttemptedIndices.add(i);
        await _completeWithWebSearch(i, triggeredAutomatically: true);
        if (!mounted) return;
      }
    }
  }

  List<ChatSource> _chatSourcesFromWebSources(List<WebSource> webSources) {
    final seen = <String>{};
    return webSources
        .where((source) => seen.add(source.uri))
        .map((source) => ChatSource(title: source.title, uri: source.uri))
        .toList();
  }

  void _handleAssistantLinkTap(String href) {
    if (!mounted) return;
    // Internal app routes
    if (href.startsWith('/')) {
      context.push(href);
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    // Internal wine detail links
    if (uri.path.startsWith('/cellar/wine/')) {
      context.push(uri.path);
      return;
    }
    // External web links (from grounded search sources)
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<List<WineAiResponse>> _recoverWineDataIfMissing({
    required AnalyzeWineUseCase analyzeUseCase,
    required List<Map<String, String>> baseHistory,
    required String originalUserMessage,
    required String assistantResponse,
  }) async {
    if (assistantResponse.trim().isEmpty) return const [];

    final repairHistory = <Map<String, String>>[
      ...baseHistory,
      {
        'role': 'user',
        'content': originalUserMessage,
      },
      {
        'role': 'assistant',
        'content': assistantResponse,
      },
    ];

    final repairEither = await analyzeUseCase(
      AnalyzeWineParams(
        userMessage: AiPrompts.buildMissingJsonRecoveryMessage(
          originalUserMessage: originalUserMessage,
          previousAssistantResponse: assistantResponse,
        ),
        conversationHistory: repairHistory,
      ),
    );

    return repairEither.fold(
      (failure) {
        _chatLogger.logError(
          'Échec de récupération de la fiche vin: ${failure.message}',
        );
        return const <WineAiResponse>[];
      },
      (repairResult) {
        if (repairResult.wineDataList.isNotEmpty) {
          _chatLogger.logAiResponse(repairResult.textResponse);
        }
        return repairResult.wineDataList;
      },
    );
  }

  String _appendWineDetailLinksToResponse(
    String responseText,
    List<WineEntity> cellarWines,
  ) {
    if (cellarWines.isEmpty || responseText.contains('/cellar/wine/')) {
      return responseText;
    }

    final normalizedResponse = _normalizeForDuplicate(responseText);
    final matched = <WineEntity>[];

    for (final wine in cellarWines) {
      if (wine.id == null) continue;
      final normalizedDisplayName = _normalizeForDuplicate(wine.displayName);
      final normalizedName = _normalizeForDuplicate(wine.name);
      final isMentioned =
          normalizedDisplayName.isNotEmpty &&
              normalizedResponse.contains(normalizedDisplayName) ||
          (normalizedName.isNotEmpty &&
              normalizedResponse.contains(normalizedName));
      if (isMentioned) {
        matched.add(wine);
      }
    }

    if (matched.isEmpty) return responseText;

    final uniqueById = <int, WineEntity>{
      for (final wine in matched) wine.id!: wine,
    };
    final links = uniqueById.values
        .take(5)
        .map((wine) {
          return '- [${wine.displayName}](/cellar/wine/${wine.id})';
        })
        .join('\n');

    return '$responseText\n\nAcces rapide aux fiches des vins proposes :\n$links';
  }

  void _handlePrefillMessage() {
    final data = _prefillData;
    _prefillData = null;
    if (data == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Ensure we are in add-wine mode, not search or review mode.
      if (_chatMode != _ChatMode.addWine) {
        _onModeChanged(_ChatMode.addWine);
      }

      final analyzeUseCase = ref.read(analyzeWineUseCaseProvider);
      if (analyzeUseCase == null) {
        // AI not configured – just fill the text field so the user can
        // configure AI and send manually.
        _textController.text = data.displayText;
        return;
      }

      // Show the field list in the chat bubble but send the full
      // AI instruction prompt.
      await _sendText(data.displayText, aiMessage: data.aiPrompt);
    });
  }

  /// Build preview cards for all wines in the current list
  List<Widget> _buildWinePreviewCards(BuildContext context) {
    final cards = <Widget>[];
    // "Add all" button when multiple complete wines
    final completeWines = _currentWineDataList
        .where((w) => w.isComplete)
        .toList();
    final allAdded = _addedWineIndices.length >= completeWines.length;
    if (_currentWineDataList.length > 1 &&
        completeWines.isNotEmpty &&
        !allAdded) {
      cards.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            onPressed: () => _addAllWinesToCellar(context),
            icon: const Icon(Icons.playlist_add, size: 20),
            label: Text(
              'Ajouter les ${completeWines.length - _addedWineIndices.length} vin(s) à la cave',
            ),
          ),
        ),
      );
    }
    for (var i = 0; i < _currentWineDataList.length; i++) {
      final alreadyAdded = _addedWineIndices.contains(i);
      final wineData = _currentWineDataList[i];
      cards.add(
        WinePreviewCard(
          wineData: wineData,
          onConfirm: alreadyAdded ? null : () => _addWineToCellar(context, i),
          onEdit: alreadyAdded ? null : () => _editWineDataDialog(i),
          onForceAdd: (alreadyAdded || wineData.isComplete)
              ? null
              : () => _forceAddIncompleteWine(context, i),
        ),
      );


    }
    return cards;
  }

  /// Complete estimated fields for a wine using Gemini web search.
  Future<void> _completeWithWebSearch(
    int wineIndex, {
    bool triggeredAutomatically = false,
  }) async {
    if (wineIndex < 0 || wineIndex >= _currentWineDataList.length) return;

    final geminiService = ref.read(geminiWebSearchServiceProvider);
    if (geminiService == null) return;

    final wine = _currentWineDataList[wineIndex];
    if (wine.estimatedFields.isEmpty || wine.name == null) return;

    setState(() => _isLoading = true);

    if (!triggeredAutomatically) {
      setState(() {
        _messages.add(
          ChatMessage(
            id: _uuid.v4(),
            content: '🌐 Recherche d\'informations complémentaires pour '
                '**${wine.name}**…',
            role: ChatRole.system,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }

    try {
      final message = AiPrompts.buildFieldCompletionMessage(
        wineName: wine.name!,
        vintage: wine.vintage,
        color: wine.color,
        appellation: wine.appellation,
        fieldsToComplete: wine.estimatedFields,
      );

      final result = await geminiService.analyzeWineWithWebSearch(
        userMessage: message,
        systemPromptOverride: AiPrompts.fieldCompletionSystemPrompt,
      );

      if (!mounted) return;

      if (result.isError) {
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content: '❌ ${result.errorMessage}',
              role: ChatRole.assistant,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      // Try to parse the JSON complement from the response
      final complementData = _extractCompletionJson(result.textResponse);

      if (complementData == null) {
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content: '⚠️ Aucune information complémentaire trouvée '
                  'dans les résultats de recherche.\n\n'
                  '${result.textResponse}',
              role: ChatRole.assistant,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      final complement = WineAiResponse.fromJson(complementData);

      // Count how many fields were actually completed
      final completedFields = wine.estimatedFields
          .where((f) => WineAiResponse.fieldWasCompleted(f, complement))
          .toList();

      if (completedFields.isEmpty) {
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content: '⚠️ La recherche n\'a pas permis de confirmer '
                  'les informations estimées.\n\n'
                  '${result.textResponse}',
              role: ChatRole.assistant,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      // Merge and update
      final merged = wine.mergeWith(complement);
      final chatSources = _chatSourcesFromWebSources(result.webSources);
      setState(() {
        _currentWineDataList[wineIndex] = merged;
        _isLoading = false;

        _messages.add(
          ChatMessage(
            id: _uuid.v4(),
            content: triggeredAutomatically
                ? '✅ **${completedFields.length} champ(s) auto-complété(s)** '
                    'via la recherche internet :\n'
                    '${completedFields.map((f) => '• $f').join('\n')}'
                : '✅ **${completedFields.length} champ(s) complété(s)** '
                    'via la recherche Google :\n'
                    '${completedFields.map((f) => '• $f').join('\n')}',
            role: ChatRole.assistant,
            timestamp: DateTime.now(),
            webSources: chatSources,
            collapseSourcesByDefault: chatSources.isNotEmpty,
          ),
        );
      });
      _cacheConversationState();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(
          ChatMessage(
            id: _uuid.v4(),
            content: '❌ Erreur lors de la recherche web : $e',
            role: ChatRole.assistant,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  /// Extract JSON from a Gemini response that may contain markdown code blocks.
  Map<String, dynamic>? _extractCompletionJson(String text) {
    // Try to extract JSON from ```json ... ``` block
    final jsonBlockRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonBlockRegex.firstMatch(text);
    if (match != null) {
      try {
        final decoded = jsonDecode(match.group(1)!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // Try to find a JSON object directly in the text
    final braceStart = text.indexOf('{');
    final braceEnd = text.lastIndexOf('}');
    if (braceStart >= 0 && braceEnd > braceStart) {
      try {
        final decoded = jsonDecode(text.substring(braceStart, braceEnd + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }

  Future<void> _addAllWinesToCellar(BuildContext context) async {
    final preAddChoice = await _askManualEditBeforeAdd();
    if (!context.mounted || preAddChoice == null) return;

    if (preAddChoice == _PreAddChoice.edit) {
      final firstEditableIndex = _currentWineDataList.indexWhere(
        (wine) => wine.isComplete,
      );
      if (firstEditableIndex >= 0) {
        await _editWineDataDialog(firstEditableIndex);
      }
      return;
    }

    // Collect all added wine IDs for a single grouped placement dialog.
    final addedWines = <({int id, String name})>[];
    for (var i = 0; i < _currentWineDataList.length; i++) {
      if (!_addedWineIndices.contains(i) &&
          _currentWineDataList[i].isComplete) {
        final newId = await _addWineToCellar(
          context,
          i,
          askManualEditBeforeAdd: false,
          skipPlacementDialog: true,
        );
        if (!context.mounted) return;
        if (newId != null) {
          addedWines.add((
            id: newId,
            name: _currentWineDataList[i].name ?? 'Vin $i',
          ));
        }
      }
    }

    if (addedWines.isEmpty) return;
    if (!mounted) return;

    if (addedWines.length == 1) {
      // Single wine → classic individual dialog.
      _askPlaceInCellar(addedWines.first.id, addedWines.first.name);
    } else {
      // Multiple wines → single grouped placement dialog.
      _askPlaceInCellarGrouped(addedWines);
    }
  }

  /// Forces adding an incomplete wine by asking the user to fill in only the
  /// missing required fields (name and/or color) via a mini-dialog.
  Future<void> _forceAddIncompleteWine(
    BuildContext context,
    int wineIndex,
  ) async {
    if (wineIndex < 0 || wineIndex >= _currentWineDataList.length) return;
    final wineData = _currentWineDataList[wineIndex];
    final completed =
        await _showCompleteMissingFieldsDialog(context, wineData);
    if (completed == null || !context.mounted) return;
    setState(() {
      _currentWineDataList[wineIndex] = completed;
    });
    await _addWineToCellar(context, wineIndex, askManualEditBeforeAdd: false);
  }

  /// Shows a dialog with only the missing required fields (name and/or color)
  /// and returns a completed [WineAiResponse], or null if cancelled.
  Future<WineAiResponse?> _showCompleteMissingFieldsDialog(
    BuildContext context,
    WineAiResponse wineData,
  ) async {
    final nameController = TextEditingController(text: wineData.name ?? '');
    WineColor? selectedColor = wineData.color != null
        ? WineColor.values.where((c) => c.name == wineData.color).firstOrNull
        : null;

    final result = await showDialog<WineAiResponse>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final nameEmpty =
              wineData.name == null && nameController.text.trim().isEmpty;
          final colorMissing = wineData.color == null && selectedColor == null;
          final canConfirm = !nameEmpty && !colorMissing;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Compléter les champs manquants'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wineData.name == null) ...[
                    const Text('Nom *',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Nom du vin',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (wineData.color == null) ...[
                    const Text('Couleur *',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: WineColor.values.map((color) {
                        return ChoiceChip(
                          label: Text('${color.emoji} ${color.label}'),
                          selected: selectedColor == color,
                          onSelected: (selected) => setDialogState(() {
                            selectedColor = selected ? color : null;
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: canConfirm
                    ? () => Navigator.of(context).pop(
                          WineAiResponse(
                            name: wineData.name ?? nameController.text.trim(),
                            color: wineData.color ?? selectedColor!.name,
                            appellation: wineData.appellation,
                            producer: wineData.producer,
                            region: wineData.region,
                            country: wineData.country,
                            vintage: wineData.vintage,
                            grapeVarieties: wineData.grapeVarieties,
                            quantity: wineData.quantity,
                            purchasePrice: wineData.purchasePrice,
                            drinkFromYear: wineData.drinkFromYear,
                            drinkUntilYear: wineData.drinkUntilYear,
                            tastingNotes: wineData.tastingNotes,
                            suggestedFoodPairings: wineData.suggestedFoodPairings,
                            description: wineData.description,
                            needsMoreInfo: wineData.needsMoreInfo,
                            followUpQuestion: wineData.followUpQuestion,
                            estimatedFields: wineData.estimatedFields,
                            confidenceNotes: wineData.confidenceNotes,
                          ),
                        )
                    : null,
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    return result;
  }

  /// Adds a single wine and returns its new database ID on success, or null.
  /// When [skipPlacementDialog] is true the caller is responsible for
  /// showing the placement dialog (used by [_addAllWinesToCellar]).
  Future<int?> _addWineToCellar(
    BuildContext context,
    int wineIndex, {
    bool askManualEditBeforeAdd = true,
    bool skipPlacementDialog = false,
  }) async {
    if (wineIndex < 0 || wineIndex >= _currentWineDataList.length) return null;

    if (askManualEditBeforeAdd) {
      final preAddChoice = await _askManualEditBeforeAdd();
      if (!context.mounted || preAddChoice == null) return null;
      if (preAddChoice == _PreAddChoice.edit) {
        await _editWineDataDialog(wineIndex);
        return null;
      }
    }

    final data = _currentWineDataList[wineIndex];
    final manuallyEdited = _manuallyEditedWineIndices.contains(wineIndex);
    if (!data.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informations incomplètes. Continuez la conversation pour compléter.',
          ),
        ),
      );
      return null;
    }

    final addWineUseCase = ref.read(addWineUseCaseProvider);
    final foodCategoryRepo = ref.read(foodCategoryRepositoryProvider);

    // Match food pairing names to category IDs
    final allCategories = await foodCategoryRepo.getAllCategories();
    final matchedCategoryIds = <int>[];
    for (final pairingName in data.suggestedFoodPairings) {
      final match = allCategories.where(
        (c) =>
            c.name.toLowerCase().contains(pairingName.toLowerCase()) ||
            pairingName.toLowerCase().contains(c.name.toLowerCase()),
      );
      if (match.isNotEmpty) {
        matchedCategoryIds.add(match.first.id);
      }
    }

    final wine = WineEntity(
      name: data.name!,
      appellation: data.appellation,
      producer: data.producer,
      region: data.region,
      country: data.country ?? 'France',
      color: WineColor.values.firstWhere(
        (c) => c.name == data.color,
        orElse: () => WineColor.red,
      ),
      vintage: data.vintage,
      grapeVarieties: data.grapeVarieties,
      quantity: data.quantity ?? 1,
      purchasePrice: data.purchasePrice,
      drinkFromYear: data.drinkFromYear,
      aiSuggestedDrinkFromYear: !manuallyEdited && data.drinkFromYear != null,
      drinkUntilYear: data.drinkUntilYear,
      aiSuggestedDrinkUntilYear: !manuallyEdited && data.drinkUntilYear != null,
      tastingNotes: data.tastingNotes,
      aiDescription: data.description,
      aiSuggestedFoodPairings: !manuallyEdited && matchedCategoryIds.isNotEmpty,
      foodCategoryIds: matchedCategoryIds,
    );

    final duplicate = await _findPotentialDuplicate(wine);
    if (!mounted) return null;

    if (duplicate != null) {
      final choice = await _showDuplicateDialog(
        existingWine: duplicate,
        addedQuantity: wine.quantity,
      );
      if (!mounted || choice == null) return null;

      if (choice == _DuplicateChoice.incrementExisting) {
        if (duplicate.id == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible de mettre à jour ce vin existant.'),
              ),
            );
          }
          return null;
        }

        final updateResult = await ref
            .read(updateWineQuantityUseCaseProvider)
            .call(
              UpdateQuantityParams(
                wineId: duplicate.id!,
                newQuantity: duplicate.quantity + wine.quantity,
              ),
            );

        updateResult.fold(
          (failure) {
            _chatLogger.logError(
              'Erreur mise à jour quantité: ${failure.message}',
            );
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
          (_) {
            _chatLogger.logWineAdded(
              '${wine.displayName} (quantité incrémentée)',
            );
            setState(() {
              _addedWineIndices.add(wineIndex);
            });
            _cacheConversationState();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Quantité incrémentée pour ${duplicate.displayName}.',
                  ),
                  showCloseIcon: true,
                  action: SnackBarAction(
                    label: 'Voir la cave',
                    onPressed: () => context.go('/cellar'),
                  ),
                ),
              );
            }
          },
        );
        return null;
      }
    }

    int? addedId;
    final result = await addWineUseCase(wine);
    result.fold(
      (failure) {
        _chatLogger.logError('Erreur ajout vin: ${failure.message}');
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (newId) {
        addedId = newId;
        _chatLogger.logWineAdded(wine.displayName);
        setState(() {
          _addedWineIndices.add(wineIndex);
        });
        _cacheConversationState();
        if (mounted && !skipPlacementDialog) {
          _askPlaceInCellar(newId, wine.displayName);
        }
      },
    );
    return addedId;
  }

  Future<void> _askPlaceInCellar(int wineId, String wineName) async {
    if (!mounted) return;

    final choice = await showDialog<_PlacementChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$wineName ajouté à la cave !'),
        content: const Text(
          'Comment souhaitez-vous gérer le stockage de ce vin ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_PlacementChoice.none),
            child: const Text('Non merci'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_PlacementChoice.associateOnly),
            child: const Text('Mettre en cave'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_PlacementChoice.placeInSlot),
            child: const Text('Placer à un emplacement'),
          ),
        ],
      ),
    );

    if (!mounted ||
        choice == null ||
        choice == _PlacementChoice.none) {
      return;
    }

    final selectedCellar = await _selectOrCreateCellar();
    if (!mounted || selectedCellar == null || selectedCellar.id == null) {
      return;
    }

    await _updateWineLocation(wineId, selectedCellar.name);
    if (!mounted) return;

    if (choice == _PlacementChoice.associateOnly) {
      return;
    }

    context.go('/cellars/${selectedCellar.id}?wineId=$wineId');
  }

  /// Grouped placement dialog shown after adding multiple wines at once.
  Future<void> _askPlaceInCellarGrouped(
    List<({int id, String name})> wines,
  ) async {
    if (!mounted || wines.isEmpty) return;

    final wineNames = wines.map((w) => '• ${w.name}').join('\n');

    final choice = await showDialog<_PlacementChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${wines.length} vins ajoutés à la cave !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(wineNames),
            const SizedBox(height: 12),
            const Text('Souhaitez-vous les associer à une cave ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_PlacementChoice.none),
            child: const Text('Non merci'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_PlacementChoice.associateOnly),
            child: const Text('Associer à une cave'),
          ),
        ],
      ),
    );

    if (!mounted || choice == null || choice == _PlacementChoice.none) return;

    final selectedCellar = await _selectOrCreateCellar();
    if (!mounted || selectedCellar == null) return;

    for (final wine in wines) {
      await _updateWineLocation(wine.id, selectedCellar.name);
      if (!mounted) return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${wines.length} vins associés à « ${selectedCellar.name} ».',
          ),
          showCloseIcon: true,
          action: SnackBarAction(
            label: 'Voir la cave',
            onPressed: () => context.go('/cellars/${selectedCellar.id}'),
          ),
        ),
      );
    }
  }

  Future<void> _updateWineLocation(int wineId, String cellarName) async {
    final wineResult =
        await ref.read(getWineByIdUseCaseProvider).call(wineId);
    if (!mounted) return;

    final wine = wineResult.getOrElse((_) => null);
    if (wine == null) return;

    final updated = wine.copyWith(location: cellarName);
    await ref.read(updateWineUseCaseProvider).call(updated);
  }

  static const _createNewCellarChoice = _CreateNewCellarChoice();

  Future<VirtualCellarEntity?> _selectOrCreateCellar() async {
    final cellarsResult = await ref
        .read(virtualCellarRepositoryProvider)
        .getAll();
    if (!mounted) return null;

    final cellars = cellarsResult.getOrElse((_) => const []);
    if (cellars.isEmpty) {
      return _createDefaultCellar(existingCellars: cellars);
    }

    final pickerResult = await _showCellarPicker(cellars);
    if (!mounted || pickerResult == null) return null;

    if (pickerResult == _createNewCellarChoice) {
      return _createDefaultCellar(existingCellars: cellars);
    }

    if (pickerResult is VirtualCellarEntity) {
      return pickerResult;
    }

    return null;
  }

  Future<VirtualCellarEntity?> _createDefaultCellar({
    required List<VirtualCellarEntity> existingCellars,
  }) async {
    final cellarName = _buildDefaultCellarName(existingCellars);
    final newCellar = VirtualCellarEntity(
      name: cellarName,
      rows: 5,
      columns: 5,
    );

    final createResult = await ref
        .read(createVirtualCellarUseCaseProvider)
        .call(newCellar);
    if (!mounted) return null;

    return createResult.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
        return null;
      },
      (id) => newCellar.copyWith(id: id),
    );
  }

  String _buildDefaultCellarName(List<VirtualCellarEntity> existingCellars) {
    final lowerNames = existingCellars
        .map((cellar) => cellar.name.trim().toLowerCase())
        .toSet();

    if (!lowerNames.contains('ma cave')) {
      return 'Ma cave';
    }

    var suffix = 2;
    while (lowerNames.contains('ma cave $suffix')) {
      suffix++;
    }
    return 'Ma cave $suffix';
  }

  Future<Object?> _showCellarPicker(List<VirtualCellarEntity> cellars) {
    return showDialog<Object>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choisir une cave'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cellars.length,
            itemBuilder: (context, index) {
              final cellar = cellars[index];
              return ListTile(
                leading: const Icon(Icons.grid_view_outlined),
                title: Text(cellar.name),
                subtitle: Text(
                  '${cellar.rows} × ${cellar.columns} — ${cellar.totalSlots} emplacements',
                ),
                onTap: () => Navigator.of(ctx).pop(cellar),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(_createNewCellarChoice),
            icon: const Icon(Icons.add),
            label: const Text('Créer une nouvelle cave (5×5)'),
          ),
        ],
      ),
    );
  }

  Future<_PreAddChoice?> _askManualEditBeforeAdd() {
    return showDialog<_PreAddChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vérification avant ajout'),
        content: const Text(
          'Avant de finaliser la mise en cave, souhaitez-vous modifier '
          'manuellement des informations ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_PreAddChoice.edit),
            child: const Text('Modifier manuellement'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_PreAddChoice.continueAdd),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Future<void> _editWineDataDialog(int wineIndex) async {
    if (wineIndex < 0 || wineIndex >= _currentWineDataList.length) return;

    final original = _currentWineDataList[wineIndex];

    final nameCtrl = TextEditingController(text: original.name ?? '');
    final appellationCtrl = TextEditingController(
      text: original.appellation ?? '',
    );
    final producerCtrl = TextEditingController(text: original.producer ?? '');
    final regionCtrl = TextEditingController(text: original.region ?? '');
    final countryCtrl = TextEditingController(
      text: original.country ?? 'France',
    );
    final vintageCtrl = TextEditingController(
      text: original.vintage?.toString() ?? '',
    );
    final grapesCtrl = TextEditingController(
      text: original.grapeVarieties.join(', '),
    );
    final quantityCtrl = TextEditingController(
      text: (original.quantity ?? 1).toString(),
    );
    final priceCtrl = TextEditingController(
      text: original.purchasePrice?.toString() ?? '',
    );
    final drinkFromCtrl = TextEditingController(
      text: original.drinkFromYear?.toString() ?? '',
    );
    final drinkUntilCtrl = TextEditingController(
      text: original.drinkUntilYear?.toString() ?? '',
    );
    final tastingCtrl = TextEditingController(
      text: original.tastingNotes ?? '',
    );

    var selectedColorName = original.color ?? WineColor.red.name;

    final updated = await showDialog<WineAiResponse>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier la fiche du vin'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nom *'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedColorName,
                        decoration: const InputDecoration(
                          labelText: 'Couleur *',
                        ),
                        items: WineColor.values
                            .map(
                              (color) => DropdownMenuItem<String>(
                                value: color.name,
                                child: Text('${color.emoji} ${color.label}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedColorName = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: appellationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Appellation',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: producerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Producteur',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: regionCtrl,
                        decoration: const InputDecoration(labelText: 'Région'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: countryCtrl,
                        decoration: const InputDecoration(labelText: 'Pays'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: vintageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Millésime',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: grapesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cépages (séparés par virgules)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: quantityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantité',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Prix (€)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: drinkFromCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'À boire dès',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: drinkUntilCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'À boire jusqu\'à',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tastingCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes de dégustation',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsedQuantity =
                        int.tryParse(quantityCtrl.text.trim()) ??
                        (original.quantity ?? 1);
                    final safeQuantity = parsedQuantity <= 0
                        ? 1
                        : parsedQuantity;
                    final safeName = nameCtrl.text.trim();
                    if (safeName.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Le nom du vin est obligatoire.'),
                        ),
                      );
                      return;
                    }

                    final grapes = grapesCtrl.text
                        .split(',')
                        .map((value) => value.trim())
                        .where((value) => value.isNotEmpty)
                        .toList();

                    Navigator.of(dialogContext).pop(
                      WineAiResponse(
                        name: safeName,
                        appellation: _emptyToNull(appellationCtrl.text),
                        producer: _emptyToNull(producerCtrl.text),
                        region: _emptyToNull(regionCtrl.text),
                        country: _emptyToNull(countryCtrl.text) ?? 'France',
                        color: selectedColorName,
                        vintage: int.tryParse(vintageCtrl.text.trim()),
                        grapeVarieties: grapes,
                        quantity: safeQuantity,
                        purchasePrice: double.tryParse(priceCtrl.text.trim()),
                        drinkFromYear: int.tryParse(drinkFromCtrl.text.trim()),
                        drinkUntilYear: int.tryParse(
                          drinkUntilCtrl.text.trim(),
                        ),
                        tastingNotes: _emptyToNull(tastingCtrl.text),
                        suggestedFoodPairings: original.suggestedFoodPairings,
                        description: original.description,
                        needsMoreInfo: false,
                        followUpQuestion: null,
                      ),
                    );
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    appellationCtrl.dispose();
    producerCtrl.dispose();
    regionCtrl.dispose();
    countryCtrl.dispose();
    vintageCtrl.dispose();
    grapesCtrl.dispose();
    quantityCtrl.dispose();
    priceCtrl.dispose();
    drinkFromCtrl.dispose();
    drinkUntilCtrl.dispose();
    tastingCtrl.dispose();

    if (updated == null || !mounted) return;

    setState(() {
      _currentWineDataList[wineIndex] = updated;
      _manuallyEditedWineIndices.add(wineIndex);
    });
    _cacheConversationState();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fiche mise à jour.')));
  }

  Future<WineEntity?> _findPotentialDuplicate(WineEntity candidate) async {
    final allWines = await ref.read(wineRepositoryProvider).getAllWines();
    final normalizedName = _normalizeForDuplicate(candidate.name);
    final normalizedProducer = _normalizeForDuplicate(candidate.producer ?? '');
    final candidateVintage = candidate.vintage;

    for (final wine in allWines) {
      if (_normalizeForDuplicate(wine.name) != normalizedName) continue;
      if (wine.vintage != candidateVintage) continue;
      if (_normalizeForDuplicate(wine.producer ?? '') != normalizedProducer) {
        continue;
      }
      return wine;
    }
    return null;
  }

  Future<_DuplicateChoice?> _showDuplicateDialog({
    required WineEntity existingWine,
    required int addedQuantity,
  }) {
    return showDialog<_DuplicateChoice>(
      context: context,
      builder: (dialogContext) {
        final producer = (existingWine.producer ?? '').trim();
        final producerText = producer.isEmpty ? 'Non renseigné' : producer;

        return AlertDialog(
          title: const Text('Doublon probable détecté'),
          content: Text(
            'Une bouteille semblable existe probablement déjà dans votre cave :\n'
            '- Nom : ${existingWine.name}\n'
            '- Millésime : ${existingWine.vintage ?? '-'}\n'
            '- Domaine/Producteur : $producerText\n\n'
            'Souhaitez-vous incrémenter la quantité de cette fiche '
            '(+${addedQuantity <= 0 ? 1 : addedQuantity}) '
            'ou créer une nouvelle référence ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DuplicateChoice.createNew),
              child: const Text('Créer une nouvelle référence'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_DuplicateChoice.incrementExisting),
              child: const Text('Incrémenter la quantité'),
            ),
          ],
        );
      },
    );
  }

  String _normalizeForDuplicate(String value) {
    var normalized = value.trim().toLowerCase();

    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ÿ': 'y',
    };

    replacements.forEach((accented, plain) {
      normalized = normalized.replaceAll(accented, plain);
    });

    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _resetConversation() {
    _resetAiServiceChatSession();

    _chatLogger.endSession();
    _chatLogger.startSession();

    setState(() {
      _messages.clear();
      _currentWineDataList = [];
      _addedWineIndices.clear();
      _chatMode = _ChatMode.addWine;
      _messages.add(_buildWelcomeMessage());
    });
    _cacheConversationState();
  }

  Future<void> _confirmResetConversation() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer l\'historique ?'),
        content: const Text(
          'Cette action remet la conversation actuelle à zéro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );

    if (shouldReset == true && mounted) {
      _resetConversation();
    }
  }

  ChatMessage _buildWelcomeMessage() {
    return ChatMessage(
      id: _uuid.v4(),
      content:
          'Bonjour ! 🍷 Décrivez-moi le ou les vins que vous souhaitez ajouter à votre cave.\n\n'
          'Par exemple :\n'
          '• "J\'ai acheté un Château Margaux 2015, rouge, 3 bouteilles à 45€"\n'
          '• "Un Chablis Premier Cru 2020"\n'
          '• "Côtes du Rhône rouge 2019, Guigal"\n'
          '• "3 vins : Sancerre 2022, Pouilly-Fumé 2021 et Vouvray 2020"',
      role: ChatRole.assistant,
      timestamp: DateTime.now(),
    );
  }

  void _cacheConversationState() {
    _sessionMessages = List<ChatMessage>.from(_messages);
    _sessionWineDataList = List<WineAiResponse>.from(_currentWineDataList);
    _sessionChatMode = _chatMode;
  }

  // ---- Mode selector & cellar search helpers ----

  Widget _buildNoWebSearchBanner(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 20,
            ),
            title: Text(
              'Estimations uniquement — aucun accès internet',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            childrenPadding:
                const EdgeInsets.fromLTRB(12, 0, 12, 10),
            iconColor: Colors.orange,
            collapsedIconColor: Colors.orange,
            children: [
              Text(
                'Aucun modèle avec accès à internet n\'est disponible. '
                'Les informations sur les vins (fenêtre de dégustation, '
                'cépages, appellation…) seront basées uniquement sur les '
                'connaissances internes du modèle IA, sans vérification '
                'via des sources en ligne.\n\n'
                'Pour activer la recherche web, configurez une clé API '
                'Gemini dans les Paramètres (rubrique "Complètion web").',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<_ChatMode>(
        segments: const [
          ButtonSegment(
            value: _ChatMode.addWine,
            label: Text('Ajouter'),
            icon: Icon(Icons.wine_bar, size: 18),
          ),
          ButtonSegment(
            value: _ChatMode.foodPairing,
            label: Text('Accords'),
            icon: Icon(Icons.restaurant, size: 18),
          ),
          ButtonSegment(
            value: _ChatMode.wineReview,
            label: Text('Avis'),
            icon: Icon(Icons.rate_review, size: 18),
          ),
        ],
        selected: {_chatMode},
        onSelectionChanged: (selected) => _onModeChanged(selected.first),
      ),
    );
  }

  void _onModeChanged(_ChatMode newMode) async {
    if (_chatMode == newMode) return;

    // If we're in addWine mode and there are pending (non-added) wines, warn.
    if (_chatMode == _ChatMode.addWine) {
      var pendingCount = 0;
      for (var i = 0; i < _currentWineDataList.length; i++) {
        if (!_addedWineIndices.contains(i) &&
            _currentWineDataList[i].name != null) {
          pendingCount++;
        }
      }
      if (pendingCount > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Changer de mode ?'),
            content: Text(
              '$pendingCount fiche(s) en cours non ajoutée(s) seront effacées.\n'
              'Voulez-vous continuer ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Changer de mode'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
      }
    }

    // Reset AI session on mode switch for clean context.
    _resetAiServiceChatSession();

    setState(() {
      _chatMode = newMode;
      _currentWineDataList = [];
      _addedWineIndices.clear();
      _messages.add(
        ChatMessage(
          id: _uuid.v4(),
          content: switch (newMode) {
            _ChatMode.foodPairing =>
              '🔍 **Mode accord mets-vin activé**\n'
                  'Décrivez votre repas et je chercherai le meilleur vin '
                  'dans votre cave. Les vins à boire prochainement seront '
                  'privilégiés.\n\n'
                  'Exemples :\n'
                  '• "Je prépare un gigot d\'agneau"\n'
                  '• "Plateau de fromages ce soir"\n'
                  '• "Sushi et cuisine japonaise"',
            _ChatMode.wineReview => () {
                final hasWebSearch =
                    ref.read(aiServiceProvider)?.supportsWebSearch == true ||
                    ref.read(geminiWebSearchServiceProvider) != null;
                return hasWebSearch
                    ? '📋 **Mode avis sur un vin activé**\n'
                        'Demandez-moi des informations sur un vin et je '
                        'chercherai des avis et notes sur internet via '
                        'Google Search.\n\n'
                        '🌐 Les sources seront citées pour chaque information.\n\n'
                        'Exemples :\n'
                        '• "Que vaut le Château Margaux 2015 ?"\n'
                        '• "Parle-moi du Domaine de la Romanée-Conti"\n'
                        '• "Le millésime 2020 en Bourgogne est-il bon ?"'
                    : '📋 **Mode avis sur un vin activé**\n'
                        'Demandez-moi des informations sur un vin et je vous '
                        'donnerai ce que je sais avec honnêteté — en distinguant '
                        'les faits établis de mes estimations.\n\n'
                        '⚠️ La recherche web n\'est disponible qu\'avec Gemini. '
                        'Ajoutez une clé API Gemini dans les paramètres pour '
                        'activer la recherche internet.\n\n'
                        'Exemples :\n'
                        '• "Que vaut le Château Margaux 2015 ?"\n'
                        '• "Parle-moi du Domaine de la Romanée-Conti"\n'
                        '• "Le millésime 2020 en Bourgogne est-il bon ?"';
              }(),
            _ChatMode.addWine =>
              '🍷 **Mode ajout de vin activé**\n'
                  'Décrivez-moi les vins que vous souhaitez ajouter à '
                  'votre cave.',
          },
          role: ChatRole.assistant,
          timestamp: DateTime.now(),
        ),
      );
    });
    _cacheConversationState();
    _scrollToBottom();
  }

  String _buildCellarSummary(List<WineEntity> wines) {
    final available = wines.where((w) => w.quantity > 0).toList();
    if (available.isEmpty) return '(Cave vide — aucune bouteille disponible)';

    // Sort by drinkUntilYear ascending (urgent first)
    available.sort((a, b) {
      final aYear = a.drinkUntilYear ?? 9999;
      final bYear = b.drinkUntilYear ?? 9999;
      return aYear.compareTo(bYear);
    });

    final currentYear = DateTime.now().year;
    final buffer = StringBuffer();
    buffer.writeln(
      '${available.length} vin(s) disponible(s) (année actuelle : $currentYear) :',
    );
    buffer.writeln();

    for (final w in available) {
      buffer.write('• ${w.displayName}');
      buffer.write(' | ${w.color.emoji} ${w.color.label}');
      if (w.appellation != null) buffer.write(' | ${w.appellation}');
      if (w.region != null) buffer.write(', ${w.region}');
      buffer.writeln();
      if (w.grapeVarieties.isNotEmpty) {
        buffer.writeln('  Cépages : ${w.grapeVarieties.join(", ")}');
      }
      buffer.write('  Quantité : ${w.quantity}');
      if (w.drinkFromYear != null || w.drinkUntilYear != null) {
        buffer.write(
          ' | À boire : ${w.drinkFromYear ?? "?"} → ${w.drinkUntilYear ?? "?"}',
        );
      }
      buffer.writeln();
      if (w.tastingNotes != null && w.tastingNotes!.isNotEmpty) {
        buffer.writeln('  Notes : ${w.tastingNotes}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  void _resetAiServiceChatSession() {
    ref.read(aiServiceProvider)?.resetChat();
  }

  Future<AddWineMessageIntent?> _resolveAddWineIntent(String userMessage) async {
    final detected = AiRequestStrategy.detectAddWineMessageIntent(
      userMessage: userMessage,
      currentWineData: _currentWineDataList,
    );

    if (detected != AddWineMessageIntent.unclear) return detected;

    return showDialog<AddWineMessageIntent>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Précision ou nouveau vin ?'),
        content: const Text(
          'Je ne suis pas sûr de l intention de ce message.\n'
          'Souhaitez-vous corriger le vin en cours ou démarrer un nouveau vin ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              AddWineMessageIntent.refineCurrentWine,
            ),
            child: const Text('Précision sur vin actuel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              AddWineMessageIntent.newWine,
            ),
            child: const Text('Nouveau vin'),
          ),
        ],
      ),
    );
  }

  String _buildCurrentWineSummaryForRefinement() {
    if (_currentWineDataList.isEmpty) {
      return 'Aucune fiche active.';
    }

    final first = _currentWineDataList.first;
    final parts = <String>[];
    if ((first.name ?? '').trim().isNotEmpty) {
      parts.add('Nom: ${first.name}');
    }
    if (first.vintage != null) {
      parts.add('Millésime: ${first.vintage}');
    }
    if ((first.appellation ?? '').trim().isNotEmpty) {
      parts.add('Appellation: ${first.appellation}');
    }
    if ((first.producer ?? '').trim().isNotEmpty) {
      parts.add('Producteur: ${first.producer}');
    }

    if (parts.isEmpty) {
      return 'Une fiche vin est en cours mais encore incomplète.';
    }

    return parts.join(' | ');
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showLogsInfo() async {
    final logsPath = await _chatLogger.getLogsPath();
    final logFiles = await _chatLogger.listLogFiles();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logs des conversations'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dossier :', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                logsPath,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Text(
                '${logFiles.length} fichier(s) de log :',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (logFiles.isEmpty)
                const Text('Aucun log pour le moment.')
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: logFiles.length,
                    itemBuilder: (context, index) {
                      final file = logFiles[index];
                      final name = file.path.split('/').last;
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.description, size: 20),
                        title: SelectableText(name),
                        subtitle: SelectableText(
                          file.path,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
