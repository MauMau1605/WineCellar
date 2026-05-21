import 'package:wine_cellar/features/ai_assistant/domain/entities/cellar_tracker_result.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/vivino_result.dart';

/// Represents a message in the AI chat conversation
class ChatMessage {
  final String id;
  final String content;
  final ChatRole role;
  final DateTime timestamp;
  final WinePreviewData? winePreview; // attached wine data preview
  final List<ChatSource> webSources;
  final bool collapseSourcesByDefault;

  /// Statut de la tentative Vivino associée à ce message (null si non applicable).
  final VivinoSourceStatus? vivinoSourceStatus;

  /// Statut de la tentative CellarTracker associée à ce message (null si non applicable).
  final CellarTrackerSourceStatus? cellarTrackerStatus;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.winePreview,
    this.webSources = const [],
    this.collapseSourcesByDefault = true,
    this.vivinoSourceStatus,
    this.cellarTrackerStatus,
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
