import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

/// Service that logs all chat interactions (user input, AI responses, errors)
/// to timestamped text files for debugging and recovery.
///
/// Logs are stored in: <app_documents>/wine_cellar_logs/
/// One file per conversation session.
class ChatLogger {
  final Logger _logger = Logger();

  File? _currentLogFile;
  String? _currentSessionId;

  static final ChatLogger _instance = ChatLogger._internal();
  factory ChatLogger() => _instance;
  ChatLogger._internal();

  /// Get the logs directory path
  Future<Directory> get _logsDir async {
    final docsDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${docsDir.path}/wine_cellar_logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  /// Start a new conversation session log file
  Future<void> startSession() async {
    final dir = await _logsDir;
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    _currentSessionId = timestamp;
    _currentLogFile = File('${dir.path}/chat_$timestamp.log');

    await _write('=== Nouvelle session de chat ===');
    await _write('Date: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}');
    await _write('=' * 50);
  }

  /// Log a user message
  Future<void> logUserMessage(String message) async {
    await _ensureSession();
    await _write('\n[${_now()}] 👤 UTILISATEUR:');
    await _write(message);
  }

  /// Log the AI response (full text, including JSON block)
  Future<void> logAiResponse(String response) async {
    await _ensureSession();
    await _write('\n[${_now()}] 🤖 IA:');
    await _write(response);
  }

  /// Log an error from the AI service
  Future<void> logError(String error, [Object? exception]) async {
    await _ensureSession();
    await _write('\n[${_now()}] ❌ ERREUR:');
    await _write(error);
    if (exception != null) {
      await _write('Exception: $exception');
    }
  }

  /// Log a wine successfully added
  Future<void> logWineAdded(String wineName) async {
    await _ensureSession();
    await _write('\n[${_now()}] ✅ VIN AJOUTÉ: $wineName');
  }

  /// Log raw API request/response for debugging
  Future<void> logApiCall({
    required String provider,
    required String model,
    String? requestSummary,
    String? responseSummary,
    String? error,
  }) async {
    await _ensureSession();
    await _write('\n[${_now()}] 🔧 API CALL [$provider - $model]:');
    if (requestSummary != null) {
      await _write('  Request: $requestSummary');
    }
    if (responseSummary != null) {
      await _write('  Response length: ${responseSummary.length} chars');
    }
    if (error != null) {
      await _write('  Error: $error');
    }
  }

  /// End the current session
  Future<void> endSession() async {
    if (_currentLogFile != null) {
      await _write('\n${'=' * 50}');
      await _write('[${_now()}] === Fin de session ===');
    }
    _currentLogFile = null;
    _currentSessionId = null;
  }

  /// Get the path to the current log file (for display to user)
  String? get currentLogPath => _currentLogFile?.path;

  /// List all log files, most recent first
  Future<List<File>> listLogFiles() async {
    final dir = await _logsDir;
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.log'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Get the logs directory path as a string
  Future<String> getLogsPath() async {
    final dir = await _logsDir;
    return dir.path;
  }

  /// Ensure we have an active session
  Future<void> _ensureSession() async {
    if (_currentLogFile == null) {
      await startSession();
    }
  }

  String _now() => DateFormat('HH:mm:ss').format(DateTime.now());

  Future<void> _write(String line) async {
    try {
      await _currentLogFile?.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      _logger.e('Failed to write chat log', error: e);
    }
  }
}
