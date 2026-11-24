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

  /// In-app routes the assistant is allowed to navigate to. Anything else
  /// (settings, developer tools, ...) is ignored, so that text coming from
  /// the AI or from web sources cannot steer the app.
  static final RegExp _allowedInternalPath = RegExp(
    r'^/(cellar/wine/\d+|cellars/\d+)$',
  );

  static ChatAssistantLinkAction resolve(String href) {
    if (href.startsWith('/')) {
      final relative = Uri.tryParse(href);
      if (relative == null || !_allowedInternalPath.hasMatch(relative.path)) {
        return const ChatAssistantLinkAction.ignore();
      }
      // Keep the query string (e.g. /cellars/3?wineId=7).
      return ChatAssistantLinkAction.pushRoute(route: relative.toString());
    }

    final uri = Uri.tryParse(href);
    if (uri == null) {
      return const ChatAssistantLinkAction.ignore();
    }

    if (_allowedInternalPath.hasMatch(uri.path) &&
        uri.path.startsWith('/cellar/wine/')) {
      return ChatAssistantLinkAction.pushRoute(route: uri.path);
    }

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return ChatAssistantLinkAction.openExternal(externalUri: uri);
    }

    return const ChatAssistantLinkAction.ignore();
  }
}