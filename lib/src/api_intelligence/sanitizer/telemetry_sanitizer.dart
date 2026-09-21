/// Single choke point for stripping sensitive values out of anything derived
/// from captured telemetry before it's shown in a report or sent to an AI
/// provider (spec §14/§23: "Sensitive values must NEVER be included in AI
/// prompts or displayed in reports").
class TelemetrySanitizer {
  const TelemetrySanitizer();

  static const _sensitiveHeaderNames = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
    'x-access-token',
    'x-csrf-token',
  };

  static const _sensitiveHeaderSuffixes = ['-token', '-secret', '-key'];

  static const _sensitiveBodyKeys = {
    'password',
    'passwd',
    'token',
    'accesstoken',
    'refreshtoken',
    'secret',
    'apikey',
    'api_key',
    'authorization',
    'clientsecret',
    'client_secret',
    'ssn',
    'creditcard',
    'credit_card',
    'cvv',
  };

  static const redacted = '[REDACTED]';

  bool isSensitiveHeaderName(String name) {
    final lower = name.toLowerCase();
    if (_sensitiveHeaderNames.contains(lower)) return true;
    return _sensitiveHeaderSuffixes.any((suffix) => lower.endsWith(suffix));
  }

  bool isSensitiveBodyKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
    return _sensitiveBodyKeys.contains(normalized);
  }

  /// Returns a copy of [headers] with sensitive values redacted. Accepts
  /// `Map`, `Map<String, List<String>>` (Dio's header shape), or null.
  Map<String, dynamic>? sanitizeHeaders(dynamic headers) {
    if (headers is! Map) return null;
    final result = <String, dynamic>{};
    headers.forEach((key, value) {
      final name = key.toString();
      result[name] = isSensitiveHeaderName(name) ? redacted : value;
    });
    return result;
  }

  /// Recursively redacts sensitive keys in a decoded JSON-like value
  /// (Map/List/primitive), used before handing bodies/samples to an AI
  /// provider.
  dynamic sanitizeValue(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, v) {
        final name = key.toString();
        result[name] = isSensitiveBodyKey(name) ? redacted : sanitizeValue(v);
      });
      return result;
    }
    if (value is List) {
      return value.map(sanitizeValue).toList();
    }
    return value;
  }
}
