import 'dart:convert';

import '../../request_details.dart';

/// Small, shared helpers for pulling deterministic facts out of a
/// [RequestDetails] instance. Kept free of Flutter imports so the whole
/// analyzer tree stays pure-Dart and unit-testable.
class TelemetryHelpers {
  const TelemetryHelpers._();

  static int? durationMs(RequestDetails request) {
    if (request.receivedTime == null) return null;
    return request.receivedTime!.difference(request.sentTime).inMilliseconds;
  }

  /// Best-effort byte size of the response body: encodes decoded
  /// Map/List/num/bool values back to a JSON string, uses UTF-8 byte length
  /// for a String, and returns 0 when there is no body at all.
  static int responseBytes(RequestDetails request) =>
      _encodedBytes(request.responseBody);

  static int requestBytes(RequestDetails request) =>
      _encodedBytes(request.requestBody);

  static int _encodedBytes(dynamic value) {
    if (value == null) return 0;
    if (value is String) return utf8.encode(value).length;
    try {
      return utf8.encode(json.encode(value)).length;
    } catch (_) {
      return utf8.encode(value.toString()).length;
    }
  }

  /// Whether this request completed with a "successful" HTTP status.
  static bool isSuccess(RequestDetails request) {
    final code = request.statusCode;
    return code != null && code >= 200 && code < 400;
  }

  /// A request with no status code (or `0`, which is how this package's
  /// capture paths represent a request that never got an HTTP response at
  /// all - a network failure) is treated as failed, not merely "unknown".
  static bool isFailure(RequestDetails request) => !isSuccess(request);

  /// Heuristic timeout detection: there is no dedicated error-type field on
  /// [RequestDetails], so this only flags a failed request whose captured
  /// error text mentions a timeout. Under-detects rather than guesses.
  static bool looksLikeTimeout(RequestDetails request) {
    if (!isFailure(request)) return false;
    final body = request.responseBody;
    if (body is! String) return false;
    return body.toLowerCase().contains('timeout');
  }

  /// Case-insensitive header lookup across the shapes this package stores
  /// headers in (`Map<String, String>`, `Map<String, List<String>>`, or a
  /// generic `Map`).
  static String? headerValue(dynamic headers, String name) {
    if (headers is! Map) return null;
    final lowerName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toString().toLowerCase() != lowerName) continue;
      final value = entry.value;
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is List) return null;
      return value?.toString();
    }
    return null;
  }

  static bool hasHeader(dynamic headers, String name) =>
      headerValue(headers, name) != null;

  static int headerCount(dynamic headers) => headers is Map ? headers.length : 0;

  /// A stable signature identifying "the same request" for duplicate/retry
  /// detection: method + URL (no query) + sorted query params + encoded
  /// body.
  static String requestSignature(RequestDetails request) {
    final query = request.queryParameters;
    String queryPart = '';
    if (query is Map) {
      final sortedKeys = query.keys.map((k) => k.toString()).toList()..sort();
      queryPart =
          sortedKeys.map((k) => '$k=${query[k]}').join('&');
    }
    final bodyPart = _encodedBytes(request.requestBody) == 0
        ? ''
        : (request.requestBody is String
            ? request.requestBody as String
            : json.encode(request.requestBody));
    return '${request.requestMethod.name}|${request.url}|$queryPart|$bodyPart';
  }

  /// Whether the decoded response body of [a] is byte-identical to [b]'s.
  static bool haveIdenticalResponses(RequestDetails a, RequestDetails b) {
    if (a.responseBody == null || b.responseBody == null) {
      return a.responseBody == b.responseBody;
    }
    if (a.responseBody is String && b.responseBody is String) {
      return a.responseBody == b.responseBody;
    }
    try {
      return json.encode(a.responseBody) == json.encode(b.responseBody);
    } catch (_) {
      return a.responseBody.toString() == b.responseBody.toString();
    }
  }
}
