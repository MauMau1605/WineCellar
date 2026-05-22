/// Snapshot of the application state captured during a backup export.
///
/// [config] contains non-sensitive settings (theme, layout, AI provider choice…).
/// [secrets] is non-null only when developer mode was active at export time and
///   contains all sensitive credentials (API keys, CellarTracker account…).
/// [winesJson] is the raw JSON string produced by [WineRepository.exportToJson].
class BackupData {
  final Map<String, String?> config;
  final Map<String, String?>? secrets;
  final String winesJson;
  final DateTime createdAt;
  final int version;

  const BackupData({
    required this.config,
    required this.secrets,
    required this.winesJson,
    required this.createdAt,
    required this.version,
  });

  BackupData copyWith({
    Map<String, String?>? config,
    Map<String, String?>? secrets,
    bool clearSecrets = false,
    String? winesJson,
    DateTime? createdAt,
    int? version,
  }) {
    return BackupData(
      config: config ?? this.config,
      secrets: clearSecrets ? null : (secrets ?? this.secrets),
      winesJson: winesJson ?? this.winesJson,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
    );
  }
}
