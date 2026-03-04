import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/widgets/chat_bubble.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/widgets/wine_preview_card.dart';

/// AI Chat screen for adding wines via natural language
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  final List<ChatMessage> _messages = [];
  WineAiResponse? _currentWineData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      id: _uuid.v4(),
      content:
          'Bonjour ! 🍷 Décrivez-moi le vin que vous souhaitez ajouter à votre cave.\n\n'
          'Par exemple :\n'
          '• "J\'ai acheté un Château Margaux 2015, rouge, 3 bouteilles à 45€"\n'
          '• "Un Chablis Premier Cru 2020"\n'
          '• "Côtes du Rhône rouge 2019, Guigal"',
      role: ChatRole.assistant,
      timestamp: DateTime.now(),
    ));
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant IA'),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Nouvelle conversation',
              onPressed: _resetConversation,
            ),
        ],
      ),
      body: Column(
        children: [
          // API key warning
          if (aiService == null)
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

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('L\'IA analyse votre vin...'),
                      ],
                    ),
                  );
                }

                final message = _messages[index];
                return Column(
                  children: [
                    ChatBubble(message: message),
                    // Show wine preview after the AI message that contains wine data
                    if (message.role == ChatRole.assistant &&
                        _currentWineData != null &&
                        index == _messages.length - 1)
                      WinePreviewCard(
                        wineData: _currentWineData!,
                        onConfirm: () => _addWineToCellar(context),
                        onEdit: null, // TODO: implement edit
                      ),
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
                        hintText: 'Décrivez votre vin...',
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
                      enabled: aiService != null && !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed:
                        aiService != null && !_isLoading ? _sendMessage : null,
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
    if (text.isEmpty) return;

    final aiService = ref.read(aiServiceProvider);
    if (aiService == null) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        content: text,
        role: ChatRole.user,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Build conversation history for context
    final history = _messages
        .where((m) => m.role != ChatRole.system)
        .map((m) => {
              'role': m.role == ChatRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    // Remove the last message (current one) from history since it's the userMessage
    if (history.isNotEmpty) history.removeLast();

    // Call AI service
    final result = await aiService.analyzeWine(
      userMessage: text,
      conversationHistory: history,
    );

    setState(() {
      _isLoading = false;
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        content: result.textResponse,
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
      ));

      if (result.wineData != null) {
        _currentWineData = result.wineData;
      }
    });
    _scrollToBottom();
  }

  Future<void> _addWineToCellar(BuildContext context) async {
    if (_currentWineData == null || !_currentWineData!.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Informations incomplètes. Continuez la conversation pour compléter.'),
        ),
      );
      return;
    }

    final data = _currentWineData!;
    final repo = ref.read(wineRepositoryProvider);
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

    try {
      await repo.addWine(wine);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${wine.displayName} ajouté à la cave ! 🍷'),
            action: SnackBarAction(
              label: 'Voir la cave',
              onPressed: () => context.go('/cellar'),
            ),
          ),
        );
        _resetConversation();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _resetConversation() {
    setState(() {
      _messages.clear();
      _currentWineData = null;
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        content:
            'Bonjour ! 🍷 Décrivez-moi le vin que vous souhaitez ajouter à votre cave.',
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
      ));
    });
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
}
