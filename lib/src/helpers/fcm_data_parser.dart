import 'dart:convert';

/// FCM `data` payloads are always flat `Map<String, String>` on the wire, so
/// backends often stuff structured values into that map as encoded strings:
/// JSON-encoded objects (`'{"a":1}'`), or — when the value started life as a
/// Go `map[string]interface{}` and was formatted with `fmt`/`%v` before
/// sending — its default string form (`'map[a:1 b:true]'`).
///
/// This recursively decodes both shapes so the inspector can render them as
/// real nested JSON instead of an opaque string.
class FcmDataParser {
  static final RegExp _goMapKey = RegExp(r'(\w+):');

  /// Returns a copy of [data] with any JSON- or Go-map-encoded string values
  /// decoded (recursively, since a decoded value can itself contain more
  /// encoded strings).
  static Map<String, dynamic> normalize(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _normalizeValue(value)));
  }

  static dynamic _normalizeValue(dynamic value, [int depth = 0]) {
    if (depth > 5) return value;

    if (value is String) {
      final decoded = _tryDecode(value);
      return decoded == null ? value : _normalizeValue(decoded, depth + 1);
    }
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k, _normalizeValue(v, depth + 1)),
      );
    }
    if (value is List) {
      return value.map((e) => _normalizeValue(e, depth + 1)).toList();
    }
    return value;
  }

  static dynamic _tryDecode(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return jsonDecode(trimmed);
      } on FormatException {
        return null;
      }
    }

    if (trimmed.startsWith('map[') && trimmed.endsWith(']')) {
      return _parseGoMap(trimmed);
    }

    return null;
  }

  /// Parses Go's default `fmt` string form of a map, e.g.
  /// `map[companyId:240 userId:159]` -> `{"companyId": 240, "userId": 159}`.
  ///
  /// This is a best-effort heuristic (Go's `%v` format has no escaping), so
  /// it only handles the common case of scalar values with no embedded
  /// spaces or colons.
  static Map<String, dynamic>? _parseGoMap(String text) {
    final inner = text.substring(4, text.length - 1);
    if (inner.isEmpty) return {};

    final matches = _goMapKey.allMatches(inner).toList();
    if (matches.isEmpty) return null;

    final result = <String, dynamic>{};
    for (var i = 0; i < matches.length; i++) {
      final key = matches[i].group(1)!;
      final valueStart = matches[i].end;
      final valueEnd =
          i + 1 < matches.length ? matches[i + 1].start : inner.length;
      final rawValue = inner.substring(valueStart, valueEnd).trim();
      result[key] = _parseGoScalar(rawValue);
    }
    return result;
  }

  static dynamic _parseGoScalar(String value) {
    if (value == 'true') return true;
    if (value == 'false') return false;
    final asInt = int.tryParse(value);
    if (asInt != null) return asInt;
    return value;
  }
}
