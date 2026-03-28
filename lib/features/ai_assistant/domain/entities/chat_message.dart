/// Represents a message in the AI chat conversation
class ChatMessage {
  final String id;
  final String content;
  final ChatRole role;
  final DateTime timestamp;
  final WinePreviewData? winePreview; // attached wine data preview
  final List<ChatSource> webSources;
  final bool collapseSourcesByDefault;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.winePreview,
    this.webSources = const [],
    this.collapseSourcesByDefault = true,
  });
}

class ChatSource {
  final String title;
  final String uri;

  const ChatSource({required this.title, required this.uri});
}

enum ChatRole {
  user,
  assistant,
  system,
}

/// Preview data shown in the chat for wine confirmation
class WinePreviewData {
  final Map<String, dynamic> fields;
  final bool isComplete;

  const WinePreviewData({required this.fields, this.isComplete = false});
}
