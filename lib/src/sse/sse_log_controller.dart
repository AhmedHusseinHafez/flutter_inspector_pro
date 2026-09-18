import 'package:flutter/foundation.dart';

/// A single grouped SSE connection, derived from the flat [SseLogController.logs]
/// by grouping every line since the last `CONNECTING -> <url>` marker.
class SseConnectionLog {
  const SseConnectionLog({
    required this.id,
    required this.url,
    required this.startedAt,
    required this.lines,
  });

  final String id;
  final String url;
  final DateTime startedAt;
  final List<String> lines;

  bool get hasError => lines.any((l) => l.contains('ERROR'));

  bool get isClosed =>
      hasError ||
      lines.any((l) => l.contains('CLOSED') || l.contains('DISCONNECTED'));
}

/// A lightweight global controller for on-screen SSE log display (dev only).
/// Stores timestamped log entries in a [ValueNotifier] so any listener
/// (e.g. [SseLogOverlay]) rebuilds automatically.
class SseLogController {
  SseLogController._();

  static final ValueNotifier<List<String>> _logs = ValueNotifier<List<String>>(
    [],
  );

  static const int _maxEntries = 200;

  static final _connectionRegex = RegExp(r'CONNECTING\s*->\s*(.+)$');
  static final _timestampRegex =
      RegExp(r'^\[(\d{2}):(\d{2}):(\d{2})\.(\d{3})\]');

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

  /// Groups the flat log lines into per-connection entries, newest first.
  /// A new connection starts whenever a line contains `CONNECTING -> <url>`;
  /// any lines logged before the first such marker are grouped as one
  /// connection with an unknown ('SSE') url.
  static List<SseConnectionLog> get connections {
    final rawLogs = _logs.value;
    final result = <SseConnectionLog>[];

    String currentUrl = 'SSE';
    DateTime currentStart = DateTime.now();
    List<String> currentLines = [];

    void flush() {
      if (currentLines.isEmpty) return;
      result.add(
        SseConnectionLog(
          id: '$currentUrl@${currentStart.microsecondsSinceEpoch}',
          url: currentUrl,
          startedAt: currentStart,
          lines: currentLines,
        ),
      );
    }

    for (final line in rawLogs) {
      final connectionMatch = _connectionRegex.firstMatch(line);
      if (connectionMatch != null) {
        flush();
        currentUrl = connectionMatch.group(1)!.trim();
        currentStart = _extractTimestamp(line) ?? DateTime.now();
        currentLines = [line];
      } else {
        if (currentLines.isEmpty) {
          currentStart = _extractTimestamp(line) ?? DateTime.now();
        }
        currentLines.add(line);
      }
    }
    flush();

    return result.reversed.toList(growable: false);
  }

  static DateTime? _extractTimestamp(String line) {
    final match = _timestampRegex.firstMatch(line);
    if (match == null) return null;
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
    );
  }
}
