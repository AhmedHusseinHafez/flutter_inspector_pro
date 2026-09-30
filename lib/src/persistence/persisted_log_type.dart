/// The categories of traffic that can be persisted to disk, each stored in its
/// own file so a category can be enabled, disabled, or cleared on its own.
///
/// These intentionally mirror the in-memory log sinks: [InspectorController]'s
/// request list (`http`), [SseLogController] (`sse`),
/// [FirebaseMessagingLogController] (`firebaseMessaging`),
/// [FileLogController] (`files`) and [DeveloperLogController]
/// (`developerLog`).
enum PersistedLogType {
  http('HTTP', 'http'),
  sse('SSE', 'sse'),
  firebaseMessaging('Firebase', 'firebase_messaging'),
  files('Files', 'files'),
  developerLog('Logs', 'developer_logs');

  const PersistedLogType(this.label, this.fileName);

  /// Short human-readable name, used in the settings UI and the CSV's
  /// `type` column.
  final String label;

  /// Base name of this type's log file on disk (`<fileName>.jsonl`).
  final String fileName;

  static PersistedLogType? fromFileName(String name) {
    for (final type in values) {
      if (type.fileName == name) return type;
    }
    return null;
  }
}
