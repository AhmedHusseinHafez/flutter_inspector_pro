import '../enums/developer_log_level_enum.dart';
import '../json_pretty_converter.dart';

/// A single custom log line written by the app's own code through
/// [InspectorLogger] - anything the developer wants to see next to the
/// network traffic (a user action, a state change, a caught exception, ...).
///
/// Kept separate from [RequestDetails] (like SSE and Firebase Messaging
/// events) since it isn't an HTTP request/response pair.
class DeveloperLogEntry {
  DeveloperLogEntry({
    required this.message,
    this.level = DeveloperLogLevel.debug,
    this.tag,
    this.data,
    this.error,
    this.stackTrace,
    DateTime? time,
  }) : time = time ?? DateTime.now() {
    _id = 'log-${this.time.microsecondsSinceEpoch}-${_counter++}';
  }

  // Disambiguates entries logged within the same microsecond.
  static int _counter = 0;

  late final String _id;
  String get id => _id;

  final String message;
  final DeveloperLogLevel level;

  /// Optional short category (e.g. `Auth`, `Cart`), shown next to the level
  /// badge and matched by the timeline search.
  final String? tag;

  /// Optional structured payload (a `Map`, `List`, or anything JSON-like),
  /// rendered as pretty-printed JSON on the details page.
  final Object? data;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime time;

  bool get hasError => error != null || stackTrace != null;

  String? _dataPretty;
  String get dataPretty =>
      _dataPretty ??= data != null ? JsonPrettyConverter().convert(data) : '';

  /// Whether [query] (case-insensitive) appears in the message or the tag.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return message.toLowerCase().contains(q) ||
        (tag?.toLowerCase().contains(q) ?? false);
  }
}
