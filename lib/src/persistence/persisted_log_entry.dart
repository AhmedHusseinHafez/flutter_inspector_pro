import 'dart:convert';

import 'persisted_log_type.dart';

/// One saved log line, in a single shape shared by every [PersistedLogType] so
/// that reading the files back (and flattening them into one CSV) stays simple
/// no matter which categories are enabled.
///
/// Stored as one compact JSON object per line (JSON Lines), which makes
/// appending a new entry a single write with no need to re-encode the whole
/// file.
class PersistedLogEntry {
  const PersistedLogEntry({
    required this.type,
    required this.time,
    required this.name,
    this.method,
    this.url,
    this.statusCode,
    this.durationMs,
    this.sizeBytes,
    this.error,
    this.details,
  });

  final PersistedLogType type;
  final DateTime time;

  /// Short label for the entry: the request name, the file name, the FCM
  /// notification title, or the SSE event kind.
  final String name;
  final String? method;
  final String? url;
  final int? statusCode;
  final int? durationMs;
  final int? sizeBytes;
  final String? error;

  /// Free-form payload for this entry (compact JSON for HTTP/FCM, the raw line
  /// for SSE), already truncated by the writer when needed.
  final String? details;

  Map<String, dynamic> toMap() => <String, dynamic>{
        't': type.fileName,
        'ts': time.toIso8601String(),
        'name': name,
        if (method != null) 'method': method,
        if (url != null) 'url': url,
        if (statusCode != null) 'status': statusCode,
        if (durationMs != null) 'ms': durationMs,
        if (sizeBytes != null) 'size': sizeBytes,
        if (error != null) 'error': error,
        if (details != null) 'details': details,
      };

  String toJsonLine() => json.encode(toMap());

  static PersistedLogEntry? tryParse(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final map = json.decode(line);
      if (map is! Map<String, dynamic>) return null;
      final type = PersistedLogType.fromFileName(map['t'] as String? ?? '');
      final time = DateTime.tryParse(map['ts'] as String? ?? '');
      if (type == null || time == null) return null;
      return PersistedLogEntry(
        type: type,
        time: time,
        name: map['name'] as String? ?? '',
        method: map['method'] as String?,
        url: map['url'] as String?,
        statusCode: map['status'] as int?,
        durationMs: map['ms'] as int?,
        sizeBytes: map['size'] as int?,
        error: map['error'] as String?,
        details: map['details'] as String?,
      );
    } catch (_) {
      // A half-written last line (app killed mid-append) shouldn't make the
      // whole file unreadable; skip it.
      return null;
    }
  }
}
