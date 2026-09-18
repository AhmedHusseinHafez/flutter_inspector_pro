import 'package:flutter/foundation.dart';

import 'firebase_messaging_event.dart';

/// A lightweight global log of Firebase Messaging events, kept separate from
/// [InspectorController]'s HTTP request list on purpose (same pattern as
/// [SseLogController]/[FileLogController]) and merged back into the
/// Inspector's "All" timeline for display.
///
/// Populated automatically by [FirebaseMessagingInspector] when
/// [FirebaseMessagingInspectorConfig.enabled] is true - no listener code
/// required from the app.
class FirebaseMessagingLogController {
  FirebaseMessagingLogController._();

  static final ValueNotifier<List<FirebaseMessagingEvent>> _events =
      ValueNotifier<List<FirebaseMessagingEvent>>([]);

  static const int _maxEntries = 200;

  static ValueListenable<List<FirebaseMessagingEvent>> get events => _events;

  static void log(FirebaseMessagingEvent event) {
    final updated = [event, ..._events.value];
    if (updated.length > _maxEntries) {
      updated.removeRange(_maxEntries, updated.length);
    }
    _events.value = updated;
  }

  static void remove(FirebaseMessagingEvent event) {
    final updated = [..._events.value]..removeWhere((e) => e.id == event.id);
    _events.value = updated;
  }

  static void clear() => _events.value = [];
}
