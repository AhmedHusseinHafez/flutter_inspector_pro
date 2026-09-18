/// Opt-in configuration for the Firebase Messaging inspector.
///
/// Pass this to [RequestsInspector] to automatically capture
/// `FirebaseMessaging.onMessage`, `onMessageOpenedApp` and
/// `getInitialMessage()` without writing any listener code yourself:
///
/// ```dart
/// RequestsInspector(
///   navigatorKey: navigatorKey,
///   firebaseMessaging: const FirebaseMessagingInspectorConfig(enabled: true),
///   child: child,
/// )
/// ```
///
/// Firebase must already be initialized (`Firebase.initializeApp()`) by the
/// time `RequestsInspector` builds; if it isn't, the inspector simply skips
/// attaching instead of throwing.
class FirebaseMessagingInspectorConfig {
  const FirebaseMessagingInspectorConfig({
    this.enabled = false,
    this.maskedDataKeys = defaultMaskedDataKeys,
  });

  /// Whether to auto-attach to Firebase Messaging. Defaults to `false` -
  /// this feature never runs unless explicitly enabled.
  final bool enabled;

  /// Case-insensitive substrings matched against `data` payload keys; any
  /// key that contains one of these has its value redacted (`***`) before
  /// being logged, since FCM data payloads commonly carry app-defined
  /// secrets (auth tokens, etc.) that shouldn't land in on-screen logs.
  ///
  /// Pass an empty set to disable masking, or your own set to replace the
  /// defaults entirely.
  final Set<String> maskedDataKeys;

  static const Set<String> defaultMaskedDataKeys = {
    'token',
    'password',
    'secret',
    'authorization',
    'api_key',
    'apikey',
    'access_token',
    'refresh_token',
  };
}
