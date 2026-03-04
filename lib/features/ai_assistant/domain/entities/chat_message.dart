/// Represents a message in the AI chat conversation
class ChatMessage {
  final String id;
  final String content;
  final ChatRole role;
  final DateTime timestamp;
  final WinePreviewData? winePreview; // attached wine data preview

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.winePreview,
  });
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
