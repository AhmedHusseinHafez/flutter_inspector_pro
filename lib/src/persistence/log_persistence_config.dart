import 'persisted_log_type.dart';

/// Configuration for writing logs to disk, passed to `RequestsInspector`.
///
/// Nothing is ever written until a category is actually turned on - either by
/// the developer through [defaultTypes], or by whoever is using the app
/// through the inspector's "Save to disk" switches (or the first-open prompt).
///
/// ```dart
/// RequestsInspector(
///   navigatorKey: navigatorKey,
///   // Offer the prompt on first open, nothing persisted before that:
///   logPersistence: const LogPersistenceConfig(),
///
///   // ...or start saving HTTP + Firebase from app startup, no prompt:
///   logPersistence: const LogPersistenceConfig(
///     defaultTypes: {PersistedLogType.http, PersistedLogType.firebaseMessaging},
///   ),
///   child: child,
/// )
/// ```
class LogPersistenceConfig {
  const LogPersistenceConfig({
    this.enabled = true,
    this.askOnFirstOpen = true,
    this.defaultTypes = const <PersistedLogType>{},
    this.maxEntriesPerType = 2000,
    this.includeBodies = true,
    this.maxDetailsLength = 2000,
  });

  /// Whether disk logging is offered at all. When `false` nothing is written,
  /// no prompt is shown, and the inspector hides its storage button entirely -
  /// useful for locking the feature off in release builds.
  final bool enabled;

  /// Whether to ask, the first time the inspector screen is opened, which
  /// categories should be saved to disk. The answer is remembered on disk, so
  /// the prompt appears only once per install (until storage is cleared).
  ///
  /// Skipped automatically when [defaultTypes] is non-empty - passing defaults
  /// is already an explicit choice, so there's nothing to ask.
  final bool askOnFirstOpen;

  /// Categories saved from app startup when no choice has been stored yet.
  ///
  /// Empty by default, which means nothing is persisted until it's switched on
  /// in the UI. Note that whatever is chosen in the UI later wins: these are
  /// only the initial values.
  final Set<PersistedLogType> defaultTypes;

  /// Hard cap on the number of saved entries per category. Once exceeded, the
  /// oldest entries are dropped so the files can't grow without bound.
  final int maxEntriesPerType;

  /// Whether headers, query parameters and request/response bodies are saved
  /// alongside each entry's metadata. Turn this off to keep saved logs (and
  /// exports) to URLs, status codes and timings only - lighter, and avoids
  /// persisting payloads to disk at all.
  final bool includeBodies;

  /// Maximum number of characters kept per entry's `details` column. Bodies
  /// longer than this are truncated (with a `…(truncated)` marker) so a single
  /// large response can't bloat the log file or the exported CSV.
  final int maxDetailsLength;
}
