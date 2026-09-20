import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../enums/firebase_messaging_event_type_enum.dart';
import '../persistence/inspector_preferences.dart';
import 'firebase_messaging_event.dart';
import 'firebase_messaging_inspector_config.dart';
import 'firebase_messaging_log_controller.dart';

/// Auto-attaches to `FirebaseMessaging.onMessage` so the Inspector can log
/// foreground messages without the app writing any listener code. No other
/// Firebase Messaging entry point is hooked automatically.
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
/// does for `onMessage` - doing so would require either
/// replacing the app's own handler (which this package will never do, since
/// apps may already have `FirebaseMessaging.onBackgroundMessage(...)`
/// registered) or silently producing log entries nobody can see. Instead,
/// call [logBackgroundMessage] as the first line of your own handler; see
/// its doc comment for why entries logged there won't appear in the running
/// UI session.
class FirebaseMessagingInspector {
  FirebaseMessagingInspector._();

  static StreamSubscription<RemoteMessage>? _onMessageSubscription;

  /// The config the host app opted in with, captured by [attach].
  static FirebaseMessagingInspectorConfig _config =
      const FirebaseMessagingInspectorConfig();

  /// Set once [setEnabled] has run, so the startup read of the stored choice
  /// can't overwrite a decision the user made while it was still in flight
  /// (they can reach the switch before the preferences file has been read).
  static bool _userChoiceApplied = false;

  /// Whether the host app opted into this feature at all. When `false` the
  /// inspector hides its Firebase capture switch - the UI toggle is a kill
  /// switch for an opted-in app, not a way to enable something the app
  /// deliberately left off.
  static bool get isAvailable => _config.enabled;

  /// Whether messages are being captured right now. Listenable so the
  /// inspector UI can drive a switch off it.
  ///
  /// This is the runtime state, which can differ from
  /// [FirebaseMessagingInspectorConfig.enabled]: a user who switched capture
  /// off in the inspector UI keeps it off across restarts (see
  /// [InspectorPreferences]).
  static final ValueNotifier<bool> isCapturing = ValueNotifier<bool>(false);

  /// Attaches a `FirebaseMessaging.onMessage` listener - foreground
  /// messages are the only events logged automatically. Safe to call more
  /// than once (e.g. across hot reloads or multiple `RequestsInspector`
  /// rebuilds) - only one listener is ever registered.
  ///
  /// Honours the kill switch the user can flip in the inspector UI: if they
  /// switched capture off, this attaches nothing, on this launch and every
  /// later one, until they switch it back on. See [setEnabled].
  ///
  /// Deliberately does NOT listen to `onMessageOpenedApp` or call
  /// `getInitialMessage()`. The latter consumes the cold-start message (it
  /// resolves the pending intent / launch notification exactly once), so
  /// inspecting it here would make the app's own `getInitialMessage()`
  /// return null. Log either one yourself via [FirebaseMessagingEvent] if
  /// you need it in the timeline.
  ///
  /// If Firebase hasn't been initialized yet, this fails silently (aside
  /// from a debug-mode warning) rather than throwing, so a misordered
  /// `Firebase.initializeApp()` call can't crash the host app.
  static void attach(FirebaseMessagingInspectorConfig config) {
    _config = config;
    if (!config.enabled) {
      _detach();
      return;
    }
    // The stored kill switch has to be read before anything Firebase-related
    // is touched, so a user who switched capture off stays off on the next
    // cold start - which is the whole point of the switch.
    unawaited(_applyStoredChoice());
  }

  static Future<void> _applyStoredChoice() async {
    await InspectorPreferences.instance.load();
    if (!_config.enabled || _userChoiceApplied) return;
    final stored = InspectorPreferences.instance.firebaseMessagingEnabled;
    if (stored == false) {
      if (kDebugMode) {
        debugPrint(
          'requests_inspector: Firebase Messaging capture is switched OFF '
          'from the inspector UI - nothing on FirebaseMessaging is touched. '
          'Turn it back on from the inspector\'s capture settings.',
        );
      }
      return;
    }
    _listen();
  }

  /// Switches capture on or off at runtime and remembers the choice, so it
  /// still applies after a restart. This is what the inspector UI's Firebase
  /// switch calls.
  static Future<void> setEnabled(bool enabled) async {
    _userChoiceApplied = true;
    if (enabled) {
      _listen();
    } else {
      _detach();
    }
    await InspectorPreferences.instance.setFirebaseMessagingEnabled(enabled);
  }

  static void _listen() {
    if (_onMessageSubscription != null) return;

    try {
      _onMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
        FirebaseMessagingLogController.log(
          FirebaseMessagingEvent.fromRemoteMessage(
            message,
            FirebaseMessagingEventType.onMessage,
            maskedDataKeys: _config.maskedDataKeys,
          ),
        );
      });
      isCapturing.value = true;

      if (kDebugMode) {
        debugPrint(
          'requests_inspector: Firebase Messaging inspector attached to '
          'FirebaseMessaging.onMessage only - getInitialMessage() and '
          'onMessageOpenedApp are never touched. If you do NOT see this '
          'line while the inspector is enabled, you are running an older '
          'build of this package.',
        );
      }
    } catch (e) {
      _detach();
      if (kDebugMode) {
        debugPrint(
          'requests_inspector: Firebase Messaging inspector could not '
          'attach (is Firebase.initializeApp() called before '
          'RequestsInspector builds?). Error: $e',
        );
      }
    }
  }

  static void _detach() {
    _onMessageSubscription?.cancel();
    _onMessageSubscription = null;
    isCapturing.value = false;
  }

  /// Logs a [RemoteMessage] your app obtained itself, under [type].
  ///
  /// Use this for the entry points the inspector refuses to hook, because
  /// hooking them would change your app's behaviour - above all
  /// `getInitialMessage()`, which consumes the cold-start message on the
  /// first call, so whoever calls it first wins and everyone else gets
  /// null. Your app calls it once, uses the result, and hands the same
  /// instance here:
  ///
  /// ```dart
  /// final initial = await FirebaseMessaging.instance.getInitialMessage();
  /// if (initial != null) {
  ///   FirebaseMessagingInspector.logMessage(
  ///     initial,
  ///     FirebaseMessagingEventType.initialMessage,
  ///   );
  ///   // ...the app's own cold-start routing, untouched.
  /// }
  /// ```
  static void logMessage(
    RemoteMessage message,
    FirebaseMessagingEventType type, {
    FirebaseMessagingInspectorConfig config =
        const FirebaseMessagingInspectorConfig(enabled: true),
  }) {
    if (!config.enabled) return;
    FirebaseMessagingLogController.log(
      FirebaseMessagingEvent.fromRemoteMessage(
        message,
        type,
        maskedDataKeys: config.maskedDataKeys,
      ),
    );
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
  /// foreground `onMessage` events are guaranteed visible in the running UI.
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

  /// Detaches the listener and resets attachment state. Exposed for tests.
  @visibleForTesting
  static void reset() {
    _detach();
    _config = const FirebaseMessagingInspectorConfig();
    _userChoiceApplied = false;
  }
}
