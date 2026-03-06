import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:wine_cellar/core/chat_logger.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/gemini_service.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/mistral_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/widgets/chat_bubble.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/widgets/wine_preview_card.dart';
import 'package:wine_cellar/features/ai_assistant/data/ai_prompts.dart';

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
  static bool _sessionSearchMode = false;

  final List<ChatMessage> _messages = [];
  List<WineAiResponse> _currentWineDataList = [];
  final Set<int> _addedWineIndices = {};
  bool _isLoading = false;
  bool _searchMode = false;
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
      _searchMode = _sessionSearchMode;
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
                        Text(_searchMode
                            ? 'L\'IA cherche dans votre cave...'
                            : 'L\'IA analyse votre vin...'),
                      ],
                    ),
                  );
                }

                final message = _messages[index];
                return Column(
                  children: [
                    ChatBubble(message: message),
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
                  // Photo button (disabled for MVP)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    onPressed: null, // Will be enabled in V2
                    tooltip: 'Photo (bientôt disponible)',
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: _searchMode
                            ? 'Décrivez votre repas...'
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
                    onPressed:
                        isConfigured && !_isLoading ? _sendMessage : null,
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

    setState(() {
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        content: trimmed,
        role: ChatRole.user,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    final history = _messages
        .where((m) => m.role != ChatRole.system)
        .map((m) => {
              'role': m.role == ChatRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    if (history.isNotEmpty) history.removeLast();

    String messageToSend = aiMessage?.trim() ?? trimmed;
    if (aiMessage == null && _searchMode) {
      final wines = await ref.read(wineRepositoryProvider).getAllWines();
      final cellarSummary = _buildCellarSummary(wines);
      messageToSend = AiPrompts.buildCellarSearchMessage(
        userQuestion: trimmed,
        cellarSummary: cellarSummary,
      );
    }

    _chatLogger.logUserMessage(trimmed);

    final either = await analyzeUseCase(AnalyzeWineParams(
      userMessage: messageToSend,
      conversationHistory: history,
    ));

    either.fold(
      (failure) {
        _chatLogger.logError(failure.message);
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(
            id: _uuid.v4(),
            content: failure.message,
            role: ChatRole.assistant,
            timestamp: DateTime.now(),
          ));
        });
      },
      (result) {
        _chatLogger.logAiResponse(result.textResponse);
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(
            id: _uuid.v4(),
            content: result.textResponse,
            role: ChatRole.assistant,
            timestamp: DateTime.now(),
          ));

          if (result.wineDataList.isNotEmpty) {
            _currentWineDataList = result.wineDataList;
            _addedWineIndices.clear();
          }
        });
      },
    );
    _cacheConversationState();
    _scrollToBottom();
  }

  void _handlePrefillMessage() {
    final data = _prefillData;
    _prefillData = null;
    if (data == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Ensure we are in add-wine mode, not search mode.
      if (_searchMode) {
        _onModeChanged(false);
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
    if (_currentWineDataList.length > 1 && completeWines.isNotEmpty && !allAdded) {
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
      cards.add(
        WinePreviewCard(
          wineData: _currentWineDataList[i],
          onConfirm: alreadyAdded ? null : () => _addWineToCellar(context, i),
          onEdit: null,
        ),
      );
    }
    return cards;
  }

  Future<void> _addAllWinesToCellar(BuildContext context) async {
    for (var i = 0; i < _currentWineDataList.length; i++) {
      if (!_addedWineIndices.contains(i) && _currentWineDataList[i].isComplete) {
        await _addWineToCellar(context, i);
      }
    }
  }

  Future<void> _addWineToCellar(BuildContext context, int wineIndex) async {
    final data = _currentWineDataList[wineIndex];
    if (!data.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Informations incomplètes. Continuez la conversation pour compléter.'),
        ),
      );
      return;
    }

    final addWineUseCase = ref.read(addWineUseCaseProvider);
    final foodCategoryRepo = ref.read(foodCategoryRepositoryProvider);

    // Match food pairing names to category IDs
    final allCategories = await foodCategoryRepo.getAllCategories();
    final matchedCategoryIds = <int>[];
    for (final pairingName in data.suggestedFoodPairings) {
      final match = allCategories.where(
        (c) => c.name.toLowerCase().contains(pairingName.toLowerCase()) ||
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
      drinkUntilYear: data.drinkUntilYear,
      tastingNotes: data.tastingNotes,
      aiDescription: data.description,
      foodCategoryIds: matchedCategoryIds,
    );

    final result = await addWineUseCase(wine);
    result.fold(
      (failure) {
        _chatLogger.logError('Erreur ajout vin: ${failure.message}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
      (_) {
        _chatLogger.logWineAdded(wine.displayName);
        setState(() {
          _addedWineIndices.add(wineIndex);
        });
        _cacheConversationState();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${wine.displayName} ajouté à la cave ! 🍷'),
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
  }

  void _resetConversation() {
    // Reset the AI service chat session if applicable
    final aiService = ref.read(aiServiceProvider);
    if (aiService is GeminiService) {
      aiService.resetChat();
    } else if (aiService is MistralService) {
      aiService.resetChat();
    }

    _chatLogger.endSession();
    _chatLogger.startSession();

    setState(() {
      _messages.clear();
      _currentWineDataList = [];
      _addedWineIndices.clear();
      _searchMode = false;
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
    _sessionSearchMode = _searchMode;
  }

  // ---- Mode selector & cellar search helpers ----

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Ajouter un vin'),
            icon: Icon(Icons.wine_bar, size: 18),
          ),
          ButtonSegment(
            value: true,
            label: Text('Accord mets-vin'),
            icon: Icon(Icons.restaurant, size: 18),
          ),
        ],
        selected: {_searchMode},
        onSelectionChanged: (selected) => _onModeChanged(selected.first),
      ),
    );
  }

  void _onModeChanged(bool searchMode) {
    if (_searchMode == searchMode) return;

    // Reset AI session on mode switch for clean context
    final aiService = ref.read(aiServiceProvider);
    if (aiService is GeminiService) {
      aiService.resetChat();
    } else if (aiService is MistralService) {
      aiService.resetChat();
    }

    setState(() {
      _searchMode = searchMode;
      _currentWineDataList = [];
      _addedWineIndices.clear();
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        content: searchMode
            ? '🔍 **Mode accord mets-vin activé**\n'
              'Décrivez votre repas et je chercherai le meilleur vin '
              'dans votre cave. Les vins à boire prochainement seront '
              'privilégiés.\n\n'
              'Exemples :\n'
              '• "Je prépare un gigot d\'agneau"\n'
              '• "Plateau de fromages ce soir"\n'
              '• "Sushi et cuisine japonaise"'
            : '🍷 **Mode ajout de vin activé**\n'
              'Décrivez-moi les vins que vous souhaitez ajouter à '
              'votre cave.',
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
      ));
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
        '${available.length} vin(s) disponible(s) (année actuelle : $currentYear) :');
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
            ' | À boire : ${w.drinkFromYear ?? "?"} → ${w.drinkUntilYear ?? "?"}');
      }
      buffer.writeln();
      if (w.tastingNotes != null && w.tastingNotes!.isNotEmpty) {
        buffer.writeln('  Notes : ${w.tastingNotes}');
      }
      buffer.writeln();
    }

    return buffer.toString();
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
              Text(
                'Dossier :',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              SelectableText(
                logsPath,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
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
