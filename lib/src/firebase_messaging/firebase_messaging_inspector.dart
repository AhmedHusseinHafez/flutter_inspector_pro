import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../enums/firebase_messaging_event_type_enum.dart';
import 'firebase_messaging_event.dart';
import 'firebase_messaging_inspector_config.dart';
import 'firebase_messaging_log_controller.dart';

/// Auto-attaches to `FirebaseMessaging.instance`'s streams so the Inspector
/// can log messages without the app writing any listener code.
///
/// [RequestsInspector] calls [attach] for you when
/// [FirebaseMessagingInspectorConfig.enabled] is true; you shouldn't need to
/// call it directly unless you're driving the inspector without that widget.
///
/// IMPORTANT LIMITATION: `FirebaseMessaging.onBackgroundMessage` runs its
/// handler in a separate background isolate spawned by the OS, which does
/// not share memory with the running app (that's why Firebase requires the
/// handler to be a top-level/static function in the first place). Because of
/// that, this class cannot auto-attach to background messages the way it
/// does for `onMessage`/`onMessageOpenedApp` - doing so would require either
/// replacing the app's own handler (which this package will never do, since
/// apps may already have `FirebaseMessaging.onBackgroundMessage(...)`
/// registered) or silently producing log entries nobody can see. Instead,
/// call [logBackgroundMessage] as the first line of your own handler; see
/// its doc comment for why entries logged there won't appear in the running
/// UI session.
class FirebaseMessagingInspector {
  FirebaseMessagingInspector._();

  static bool _attached = false;
  static StreamSubscription<RemoteMessage>? _onMessageSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  /// Attaches `onMessage`/`onMessageOpenedApp` listeners and logs the
  /// current `getInitialMessage()`, if any. Safe to call more than once
  /// (e.g. across hot reloads or multiple `RequestsInspector` rebuilds) -
  /// only the first call with `enabled: true` actually registers listeners.
  ///
  /// If Firebase hasn't been initialized yet, this fails silently (aside
  /// from a debug-mode warning) rather than throwing, so a misordered
  /// `Firebase.initializeApp()` call can't crash the host app.
  static void attach(FirebaseMessagingInspectorConfig config) {
    if (!config.enabled || _attached) return;

    try {
      final messaging = FirebaseMessaging.instance;
      _attached = true;

      _onMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
        FirebaseMessagingLogController.log(
          FirebaseMessagingEvent.fromRemoteMessage(
            message,
            FirebaseMessagingEventType.onMessage,
            maskedDataKeys: config.maskedDataKeys,
          ),
        );
      });

      _onMessageOpenedAppSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen((message) {
        FirebaseMessagingLogController.log(
          FirebaseMessagingEvent.fromRemoteMessage(
            message,
            FirebaseMessagingEventType.onMessageOpenedApp,
            maskedDataKeys: config.maskedDataKeys,
          ),
        );
      });

      messaging.getInitialMessage().then((message) {
        if (message == null) return;
        FirebaseMessagingLogController.log(
          FirebaseMessagingEvent.fromRemoteMessage(
            message,
            FirebaseMessagingEventType.initialMessage,
            maskedDataKeys: config.maskedDataKeys,
          ),
        );
      }).catchError((_) {
        // Firebase not ready / getInitialMessage unsupported on this
        // platform - nothing to log, and nothing the app needs to know.
      });
    } catch (e) {
      _attached = false;
      if (kDebugMode) {
        debugPrint(
          'requests_inspector: Firebase Messaging inspector could not '
          'attach (is Firebase.initializeApp() called before '
          'RequestsInspector builds?). Error: $e',
        );
      }
    }
  }

  /// Logs a message received in your app's own top-level/static
  /// `FirebaseMessaging.onBackgroundMessage` handler:
  ///
  /// ```dart
  /// @pragma('vm:entry-point')
  /// Future<void> _myBackgroundHandler(RemoteMessage message) async {
  ///   await FirebaseMessagingInspector.logBackgroundMessage(message);
  ///   // ...the app's existing handler logic, untouched.
  /// }
  /// ```
  ///
  /// LIMITATION: that handler runs in a separate background isolate with
  /// its own memory, so the entry logged here lives in that isolate's copy
  /// of [FirebaseMessagingLogController] - it will NOT appear in the
  /// Inspector UI of the already-running app session. This call is still
  /// useful (it's a real, structured log entry, and cheap to leave in
  /// place), but don't expect a background push to show up live; only
  /// foreground events (`onMessage`, `onMessageOpenedApp`, the initial
  /// message on cold start) are guaranteed visible in the running UI.
  static Future<void> logBackgroundMessage(
    RemoteMessage message, {
    FirebaseMessagingInspectorConfig config =
        const FirebaseMessagingInspectorConfig(enabled: true),
  }) async {
    if (!config.enabled) return;
    FirebaseMessagingLogController.log(
      FirebaseMessagingEvent.fromRemoteMessage(
        message,
        FirebaseMessagingEventType.onBackgroundMessage,
        maskedDataKeys: config.maskedDataKeys,
      ),
    );
  }

  /// Detaches listeners and resets attachment state. Exposed for tests.
  @visibleForTesting
  static void reset() {
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageOpenedAppSubscription = null;
    _attached = false;
  }
}
