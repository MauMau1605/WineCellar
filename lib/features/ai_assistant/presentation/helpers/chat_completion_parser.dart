import 'dart:convert';

class ChatCompletionParser {
  ChatCompletionParser._();

  static Map<String, dynamic>? extractCompletionJson(String text) {
    final jsonBlockRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonBlockRegex.firstMatch(text);
    if (match != null) {
      try {
        final decoded = jsonDecode(match.group(1)!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    final braceStart = text.indexOf('{');
    final braceEnd = text.lastIndexOf('}');
    if (braceStart >= 0 && braceEnd > braceStart) {
      try {
        final decoded = jsonDecode(text.substring(braceStart, braceEnd + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }
}