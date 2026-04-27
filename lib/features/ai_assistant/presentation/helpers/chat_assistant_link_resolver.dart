class ChatAssistantLinkAction {
  final ChatAssistantLinkActionType type;
  final String? route;
  final Uri? externalUri;

  const ChatAssistantLinkAction._({
    required this.type,
    this.route,
    this.externalUri,
  });

  const ChatAssistantLinkAction.ignore()
    : this._(type: ChatAssistantLinkActionType.ignore);

  const ChatAssistantLinkAction.pushRoute({required String route})
    : this._(type: ChatAssistantLinkActionType.pushRoute, route: route);

  const ChatAssistantLinkAction.openExternal({required Uri externalUri})
    : this._(
         type: ChatAssistantLinkActionType.openExternal,
         externalUri: externalUri,
       );
}

enum ChatAssistantLinkActionType { ignore, pushRoute, openExternal }

class ChatAssistantLinkResolver {
  ChatAssistantLinkResolver._();

  static ChatAssistantLinkAction resolve(String href) {
    if (href.startsWith('/')) {
      return ChatAssistantLinkAction.pushRoute(route: href);
    }

    final uri = Uri.tryParse(href);
    if (uri == null) {
      return const ChatAssistantLinkAction.ignore();
    }

    if (uri.path.startsWith('/cellar/wine/')) {
      return ChatAssistantLinkAction.pushRoute(route: uri.path);
    }

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return ChatAssistantLinkAction.openExternal(externalUri: uri);
    }

    return const ChatAssistantLinkAction.ignore();
  }
}