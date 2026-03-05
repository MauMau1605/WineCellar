import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';

/// Chat bubble widget for displaying messages
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);

    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.wine_bar, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                      ),
                    )
                  : MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                        h1: theme.textTheme.titleLarge?.copyWith(color: textColor),
                        h2: theme.textTheme.titleMedium?.copyWith(color: textColor),
                        h3: theme.textTheme.titleSmall?.copyWith(color: textColor),
                        listBullet: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                        strong: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        em: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontStyle: FontStyle.italic,
                        ),
                        code: theme.textTheme.bodySmall?.copyWith(
                          color: textColor,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: textColor.withValues(alpha: 0.5),
                              width: 3,
                            ),
                          ),
                        ),
                        tableBorder: TableBorder.all(
                          color: textColor.withValues(alpha: 0.3),
                        ),
                        tableHead: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        tableBody: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
