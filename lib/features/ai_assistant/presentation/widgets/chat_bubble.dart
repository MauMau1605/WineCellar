import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/cellar_tracker_result.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/vivino_result.dart';

/// Chat bubble widget for displaying messages
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<String>? onLinkTap;

  const ChatBubble({
    super.key,
    required this.message,
    this.onLinkTap,
  });

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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: message.content,
                          selectable: true,
                          onTapLink: (text, href, title) {
                            if (href == null || onLinkTap == null) return;
                            onLinkTap!(href);
                          },
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
                        if (message.vivinoSourceStatus != null) ...[
                          const SizedBox(height: 8),
                          _VivInoBadge(status: message.vivinoSourceStatus!),
                        ],
                        if (message.cellarTrackerStatus != null) ...[
                          const SizedBox(height: 4),
                          _CellarTrackerBadge(
                            status: message.cellarTrackerStatus!,
                          ),
                        ],
                        if (message.webSources.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Theme(
                              data: theme.copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                tilePadding:
                                    const EdgeInsets.only(left: 8, right: 4),
                                childrenPadding:
                                    const EdgeInsets.only(left: 8),
                                maintainState: true,
                                initiallyExpanded:
                                    !message.collapseSourcesByDefault,
                                leading: Icon(
                                  Icons.link,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                title: Text(
                                  'Sources (${message.webSources.length})',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                iconColor: theme.colorScheme.primary,
                                collapsedIconColor: theme.colorScheme.primary,
                                children: message.webSources
                                    .map(
                                      (source) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: InkWell(
                                          onTap: onLinkTap == null
                                              ? null
                                              : () => onLinkTap!(source.uri),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.open_in_new,
                                                size: 12,
                                                color: theme
                                                    .colorScheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  source.title,
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: theme
                                                        .colorScheme.primary,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Petit badge indiquant l'origine des données Vivino dans la bulle de chat.
class _VivInoBadge extends StatelessWidget {
  final VivinoSourceStatus status;

  const _VivInoBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, label, color) = switch (status) {
      VivinoSourceStatus.found => (
          Icons.check_circle_outline,
          'Vivino · données trouvées',
          Colors.green.shade700,
        ),
      VivinoSourceStatus.foundNoReviews => (
          Icons.info_outline,
          'Vivino · vin trouvé, pas d\'avis',
          Colors.orange.shade700,
        ),
      VivinoSourceStatus.notFound => (
          Icons.search_off,
          'Vivino · vin non trouvé · données via recherche web',
          Colors.grey.shade600,
        ),
      VivinoSourceStatus.unavailable => (
          Icons.cloud_off,
          'Vivino indisponible · données via recherche web',
          Colors.grey.shade600,
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// Petit badge indiquant l'origine des données CellarTracker dans la bulle de chat.
class _CellarTrackerBadge extends StatelessWidget {
  final CellarTrackerSourceStatus status;

  const _CellarTrackerBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, label, color) = switch (status) {
      CellarTrackerSourceStatus.found => (
          Icons.check_circle_outline,
          'CellarTracker · données trouvées',
          Colors.teal.shade700,
        ),
      CellarTrackerSourceStatus.notFound => (
          Icons.search_off,
          'CellarTracker · vin non trouvé',
          Colors.grey.shade600,
        ),
      CellarTrackerSourceStatus.unconfigured => (
          Icons.person_off_outlined,
          'CellarTracker · non configuré',
          Colors.grey.shade500,
        ),
      CellarTrackerSourceStatus.unavailable => (
          Icons.cloud_off,
          'CellarTracker indisponible',
          Colors.grey.shade600,
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
