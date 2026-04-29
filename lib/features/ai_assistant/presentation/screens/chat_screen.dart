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
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine_from_image.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/extract_text_from_wine_image.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_auto_web_completion_planner.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_add_flow_planner.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_add_intent_helper.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_assistant_link_resolver.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_cellar_naming_helper.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_context_summary_builder.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_duplicate_matcher.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_image_analysis_helper.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_media_helper.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_missing_json_recovery.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_missing_fields_helper.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_mode_transition_planner.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_prefill_helper.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_request_planner.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_response_enricher.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_web_search_result_builder.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_wine_draft_builder.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_web_completion_result.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/widgets/chat_bubble.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/widgets/wine_preview_card.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';

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
    final useOcr = ref.read(useOcrForImagesProvider);

    final capturePlan = ChatImageAnalysisHelper.planCapture(
      isLoading: _isLoading,
      useOcr: useOcr,
      hasVisionUseCase: ref.read(analyzeWineFromImageUseCaseProvider) != null,
    );

    switch (capturePlan.type) {
      case ChatImageCapturePlanType.noop:
        return;
      case ChatImageCapturePlanType.requireVisionConfiguration:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Configurez votre clé API avant d\'utiliser la caméra.',
            ),
          ),
        );
        return;
      case ChatImageCapturePlanType.proceedWithOcr:
      case ChatImageCapturePlanType.proceedWithVision:
        break;
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

    if (capturePlan.type == ChatImageCapturePlanType.proceedWithOcr) {
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
        final displayText = _buildPhotoSentMessage();
        final aiPrompt = _buildImagePromptForCurrentMode(
          extractedText: extractedText,
        );
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
    final params = ChatImageAnalysisHelper.buildVisionParams(
      imageBytes: imageBytes,
      mimeType: _guessMimeTypeFromPath(imagePath),
      userMessage: _buildImagePromptForCurrentMode(),
      messages: _messages,
    );

    final either = await analyzeImageUseCase(
      params,
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
          _currentWineDataList = _chatMode == _ChatMode.addWine
              ? result.wineDataList
              : const [];
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
    return ChatMediaHelper.guessMimeTypeFromPath(path);
  }

  String _buildImagePromptForCurrentMode({String? extractedText}) {
    return ChatMediaHelper.buildImagePromptForMode(
      mode: _toChatMediaMode(_chatMode),
      extractedText: extractedText,
    );
  }

  String _buildPhotoSentMessage() {
    return ChatMediaHelper.buildPhotoSentMessage(
      mode: _toChatMediaMode(_chatMode),
    );
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

    final mainServiceSupportsWebSearch =
        ref.read(aiServiceProvider)?.supportsWebSearch == true;
    final geminiWebSearch = ref.read(geminiWebSearchServiceProvider);

    List<WineEntity> cellarWinesForSearch = const [];
    var cellarSummary = '';
    if (aiMessage == null && _chatMode == _ChatMode.foodPairing) {
      final wines = await ref.read(wineRepositoryProvider).getAllWines();
      cellarWinesForSearch = wines;
      cellarSummary = ChatContextSummaryBuilder.buildCellarSummary(wines);
    }

    final plan = ChatRequestPlanner.build(
      mode: _toChatRequestMode(_chatMode),
      userMessage: trimmed,
      aiMessageOverride: aiMessage,
      addWineIntent: addWineIntent,
      currentWineSummary:
          ChatContextSummaryBuilder.buildCurrentWineSummaryForRefinement(
            _currentWineDataList,
          ),
      cellarSummary: cellarSummary,
      mainServiceSupportsWebSearch: mainServiceSupportsWebSearch,
      hasFallbackWebSearch: geminiWebSearch != null,
    );
    final messageToSend = plan.messageToSend;

    _chatLogger.logUserMessage(trimmed);

    // If review mode with fallback Gemini (main service doesn't support web search),
    // call the Gemini service directly instead of going through the main use case.
    if (plan.useFallbackWebSearchDirectCall && geminiWebSearch != null) {
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
        useWebSearch: plan.useWebSearchForReview,
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
            ? ChatResponseEnricher.appendWineDetailLinksToResponse(
                result.textResponse,
                cellarWinesForSearch,
              )
            : result.textResponse;

        var recoveredWineDataList = result.wineDataList;
        if (_chatMode == _ChatMode.addWine && recoveredWineDataList.isEmpty) {
          recoveredWineDataList = await ChatMissingJsonRecovery(
            analyzeUseCase: analyzeUseCase,
            logError: _chatLogger.logError,
            logAiResponse: _chatLogger.logAiResponse,
          ).recoverWineDataIfMissing(
            baseHistory: history,
            originalUserMessage: messageToSend,
            assistantResponse: result.textResponse,
          );
        }

        final chatSources = ChatResponseEnricher.chatSourcesFromWebSources(
          result.webSources,
        );
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

          if (_chatMode == _ChatMode.addWine &&
              recoveredWineDataList.isNotEmpty) {
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
    setState(() {
      _isLoading = false;
      _messages.add(
        ChatWebSearchResultBuilder.buildAssistantMessage(
          messageId: _uuid.v4(),
          timestamp: DateTime.now(),
          result: result,
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

    final plan = ChatAutoWebCompletionPlanner.build(
      wines: _currentWineDataList,
      attemptedIndices: _autoWebCompletionAttemptedIndices,
      addedIndices: _addedWineIndices,
      batchSize: _webCompletionBatchSize,
    );

    _autoWebCompletionAttemptedIndices.addAll(plan.indicesToMarkAttempted);

    if (!plan.hasWork) return;

    for (var batchIndex = 0; batchIndex < plan.totalBatches; batchIndex++) {
      final batchIndices = plan.completionBatches[batchIndex];

      // Show a progress message only when multiple batches are needed.
      if (plan.totalBatches > 1) {
        setState(() {
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content: ChatAutoWebCompletionPlanner.buildBatchProgressMessage(
                batchNumber: batchIndex + 1,
                totalBatches: plan.totalBatches,
                batchSize: batchIndices.length,
              ),
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

  void _handleAssistantLinkTap(String href) {
    if (!mounted) return;
    final action = ChatAssistantLinkResolver.resolve(href);
    switch (action.type) {
      case ChatAssistantLinkActionType.ignore:
        return;
      case ChatAssistantLinkActionType.pushRoute:
        final route = action.route;
        if (route != null) {
          context.push(route);
        }
      case ChatAssistantLinkActionType.openExternal:
        final externalUri = action.externalUri;
        if (externalUri != null) {
          launchUrl(externalUri, mode: LaunchMode.externalApplication);
        }
    }
  }

  void _handlePrefillMessage() {
    final data = _prefillData;
    _prefillData = null;
    if (data == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final prefillPlan = ChatPrefillHelper.buildPlan(
        currentMode: _toConversationMode(_chatMode),
        hasAnalyzeUseCase: ref.read(analyzeWineUseCaseProvider) != null,
        displayText: data.displayText,
        aiPrompt: data.aiPrompt,
      );

      // Ensure we are in add-wine mode, not search or review mode.
      if (prefillPlan.shouldSwitchToAddWineMode) {
        _onModeChanged(_ChatMode.addWine);
      }

      switch (prefillPlan.actionType) {
        case ChatPrefillActionType.fillTextOnly:
          // AI not configured – just fill the text field so the user can
          // configure AI and send manually.
          _textController.text = prefillPlan.displayText;
          return;
        case ChatPrefillActionType.sendPrompt:
          // Show the field list in the chat bubble but send the full
          // AI instruction prompt.
          await _sendText(
            prefillPlan.displayText,
            aiMessage: prefillPlan.aiPrompt,
          );
      }
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

      final completionResult = ChatWebCompletionResolver.resolve(
        wine: wine,
        responseText: result.textResponse,
        triggeredAutomatically: triggeredAutomatically,
      );

      if (!completionResult.isSuccess) {
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessage(
              id: _uuid.v4(),
              content: completionResult.assistantMessage,
              role: ChatRole.assistant,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      // Merge and update
      final chatSources = ChatResponseEnricher.chatSourcesFromWebSources(
        result.webSources,
      );
      setState(() {
        _currentWineDataList[wineIndex] = completionResult.mergedWine!;
        _isLoading = false;

        _messages.add(
          ChatMessage(
            id: _uuid.v4(),
            content: completionResult.assistantMessage,
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

  Future<void> _addAllWinesToCellar(BuildContext context) async {
    final preAddChoice = await _askManualEditBeforeAdd();
    if (!context.mounted) return;

    final bulkAddPlan = ChatAddFlowPlanner.prepareBulkAdd(
      wines: _currentWineDataList,
      addedIndices: _addedWineIndices,
      resolution: _toChatPreAddResolution(preAddChoice),
    );

    if (bulkAddPlan.type == ChatBulkAddPreparationType.cancel) {
      return;
    }

    if (bulkAddPlan.type == ChatBulkAddPreparationType.editFirstComplete) {
      final editWineIndex = bulkAddPlan.editWineIndex;
      if (editWineIndex != null) {
        await _editWineDataDialog(editWineIndex);
      }
      return;
    }

    // Collect all added wine IDs for a single grouped placement dialog.
    final addedWines = <({int id, String name})>[];
    for (final i in bulkAddPlan.indicesToAdd) {
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

    if (!mounted) return;

    final placementPlan = ChatAddFlowPlanner.buildPlacementPlan(addedWines);
    switch (placementPlan.type) {
      case ChatPlacementPlanType.none:
        return;
      case ChatPlacementPlanType.single:
        final singleWine = placementPlan.singleWine;
        if (singleWine != null) {
          _askPlaceInCellar(singleWine.id, singleWine.name);
        }
      case ChatPlacementPlanType.grouped:
        _askPlaceInCellarGrouped(placementPlan.addedWines);
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
    WineColor? selectedColor = ChatMissingFieldsHelper.resolveInitialSelectedColor(
      wineData.color,
    );

    final result = await showDialog<WineAiResponse>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canConfirm = ChatMissingFieldsHelper.canConfirm(
            wineData: wineData,
            enteredName: nameController.text,
            selectedColor: selectedColor,
          );

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
                          ChatMissingFieldsHelper.completeWineData(
                            wineData: wineData,
                            enteredName: nameController.text,
                            selectedColor: selectedColor,
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
    ChatPreAddResolution preAddResolution = ChatPreAddResolution.continueAdd;
    if (askManualEditBeforeAdd) {
      final preAddChoice = await _askManualEditBeforeAdd();
      if (!context.mounted) return null;
      preAddResolution = _toChatPreAddResolution(preAddChoice);
    }

    final guard = ChatAddFlowPlanner.guardSingleAdd(
      wineIndex: wineIndex,
      wines: _currentWineDataList,
      askManualEditBeforeAdd: askManualEditBeforeAdd,
      resolution: preAddResolution,
    );

    switch (guard.type) {
      case ChatSingleAddGuardType.invalidIndex:
      case ChatSingleAddGuardType.cancelled:
        return null;
      case ChatSingleAddGuardType.editRequested:
        await _editWineDataDialog(wineIndex);
        return null;
      case ChatSingleAddGuardType.incompleteWine:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Informations incomplètes. Continuez la conversation pour compléter.',
            ),
          ),
        );
        return null;
      case ChatSingleAddGuardType.proceed:
        break;
    }

    final data = guard.wineData!;
    final manuallyEdited = _manuallyEditedWineIndices.contains(wineIndex);

    final addWineUseCase = ref.read(addWineUseCaseProvider);
    final foodCategoryRepo = ref.read(foodCategoryRepositoryProvider);

    final allCategories = await foodCategoryRepo.getAllCategories();
    final wine = ChatWineDraftBuilder.buildPersistableWine(
      data: data,
      allCategories: allCategories,
      manuallyEdited: manuallyEdited,
    );

    final duplicate = await _findPotentialDuplicate(wine);
    if (!mounted) return null;

    if (duplicate != null) {
      final choice = await _showDuplicateDialog(
        existingWine: duplicate,
        addedQuantity: wine.quantity,
      );
      if (!mounted) return null;

      final duplicateAction = ChatAddFlowPlanner.resolveDuplicate(
        candidate: wine,
        duplicate: duplicate,
        resolution: _toChatDuplicateResolution(choice),
      );

      switch (duplicateAction.type) {
        case ChatDuplicateActionType.cancelled:
          return null;
        case ChatDuplicateActionType.rejectMissingExistingId:
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible de mettre à jour ce vin existant.'),
              ),
            );
          }
          return null;
        case ChatDuplicateActionType.incrementExistingQuantity:
          final updateResult = await ref
              .read(updateWineQuantityUseCaseProvider)
              .call(
                UpdateQuantityParams(
                  wineId: duplicateAction.wineId!,
                  newQuantity: duplicateAction.newQuantity!,
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
        case ChatDuplicateActionType.addNewReference:
          break;
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
    final cellarName = ChatCellarNamingHelper.buildDefaultCellarName(
      existingCellars,
    );
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        }
        return null;
      },
      (id) => newCellar.copyWith(id: id),
    );
  }

  ChatPreAddResolution _toChatPreAddResolution(_PreAddChoice? choice) {
    return switch (choice) {
      _PreAddChoice.edit => ChatPreAddResolution.edit,
      _PreAddChoice.continueAdd => ChatPreAddResolution.continueAdd,
      null => ChatPreAddResolution.cancel,
    };
  }

  ChatDuplicateResolution _toChatDuplicateResolution(_DuplicateChoice? choice) {
    return switch (choice) {
      _DuplicateChoice.incrementExisting =>
        ChatDuplicateResolution.incrementExisting,
      _DuplicateChoice.createNew => ChatDuplicateResolution.createNew,
      null => ChatDuplicateResolution.cancel,
    };
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
    return ChatDuplicateMatcher.findPotentialDuplicate(
      candidate: candidate,
      existingWines: allWines,
    );
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

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _resetConversation() {
    _resetAiServiceChatSession();

    _chatLogger.endSession();
    _chatLogger.startSession();

    final resetState = ChatModeTransitionPlanner.buildResetState(
      welcomeMessageId: _uuid.v4(),
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages
        ..clear()
        ..addAll(resetState.messages);
      _currentWineDataList = resetState.wineDataList;
      _addedWineIndices
        ..clear()
        ..addAll(resetState.addedWineIndices);
      _manuallyEditedWineIndices.clear();
      _autoWebCompletionAttemptedIndices.clear();
      _chatMode = _fromConversationMode(resetState.mode);
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
    return ChatModeTransitionPlanner.buildWelcomeMessage(
      messageId: _uuid.v4(),
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

    final hasWebSearch =
        ref.read(aiServiceProvider)?.supportsWebSearch == true ||
        ref.read(geminiWebSearchServiceProvider) != null;

    final transitionPlan = ChatModeTransitionPlanner.buildModeTransitionPlan(
      currentMode: _toConversationMode(_chatMode),
      newMode: _toConversationMode(newMode),
      wines: _currentWineDataList,
      addedIndices: _addedWineIndices,
      hasWebSearch: hasWebSearch,
    );

    // If we're in addWine mode and there are pending (non-added) wines, warn.
    if (transitionPlan.requiresPendingConfirmation) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Changer de mode ?'),
            content: Text(
              '${transitionPlan.pendingAddWineCount} fiche(s) en cours non ajoutée(s) seront effacées.\n'
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

    // Reset AI session on mode switch for clean context.
    _resetAiServiceChatSession();

    setState(() {
      _chatMode = newMode;
      _currentWineDataList = [];
      _addedWineIndices.clear();
      _manuallyEditedWineIndices.clear();
      _autoWebCompletionAttemptedIndices.clear();
      _messages.add(
        ChatMessage(
          id: _uuid.v4(),
          content: transitionPlan.activationMessage,
          role: ChatRole.assistant,
          timestamp: DateTime.now(),
        ),
      );
    });
    _cacheConversationState();
    _scrollToBottom();
  }

  void _resetAiServiceChatSession() {
    ref.read(aiServiceProvider)?.resetChat();
  }

  ChatConversationMode _toConversationMode(_ChatMode mode) {
    return switch (mode) {
      _ChatMode.addWine => ChatConversationMode.addWine,
      _ChatMode.foodPairing => ChatConversationMode.foodPairing,
      _ChatMode.wineReview => ChatConversationMode.wineReview,
    };
  }

  _ChatMode _fromConversationMode(ChatConversationMode mode) {
    return switch (mode) {
      ChatConversationMode.addWine => _ChatMode.addWine,
      ChatConversationMode.foodPairing => _ChatMode.foodPairing,
      ChatConversationMode.wineReview => _ChatMode.wineReview,
    };
  }

  ChatMediaMode _toChatMediaMode(_ChatMode mode) {
    return switch (mode) {
      _ChatMode.addWine => ChatMediaMode.addWine,
      _ChatMode.foodPairing => ChatMediaMode.foodPairing,
      _ChatMode.wineReview => ChatMediaMode.wineReview,
    };
  }

  ChatRequestMode _toChatRequestMode(_ChatMode mode) {
    switch (mode) {
      case _ChatMode.addWine:
        return ChatRequestMode.addWine;
      case _ChatMode.foodPairing:
        return ChatRequestMode.foodPairing;
      case _ChatMode.wineReview:
        return ChatRequestMode.wineReview;
    }
  }

  Future<AddWineMessageIntent?> _resolveAddWineIntent(String userMessage) async {
    final resolution = ChatAddIntentHelper.resolve(
      userMessage: userMessage,
      currentWineData: _currentWineDataList,
    );

    if (resolution.type == ChatAddIntentResolutionType.resolved) {
      return resolution.intent;
    }

    return showDialog<AddWineMessageIntent>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ChatAddIntentHelper.clarificationDialogTitle),
        content: const Text(ChatAddIntentHelper.clarificationDialogMessage),
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
