import 'package:flutter/foundation.dart';

/// A lightweight global controller for on-screen SSE log display (dev only).
/// Stores timestamped log entries in a [ValueNotifier] so any listener
/// (e.g. [SseLogOverlay]) rebuilds automatically.
class SseLogController {
  SseLogController._();

  static final ValueNotifier<List<String>> _logs = ValueNotifier<List<String>>(
    [],
  );

  static const int _maxEntries = 200;

  /// The listenable list of log entries.
  static ValueListenable<List<String>> get logs => _logs;

  /// Append a new log line.
  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final updated = [..._logs.value, '[$timestamp] $message'];
    if (updated.length > _maxEntries) {
      updated.removeRange(0, updated.length - _maxEntries);
    }
    _logs.value = updated;
  }

  /// Clear all log entries.
  static void clear() {
    _logs.value = [];
  }
}
