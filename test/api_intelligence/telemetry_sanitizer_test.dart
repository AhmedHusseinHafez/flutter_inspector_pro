import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/src/api_intelligence/sanitizer/telemetry_sanitizer.dart';

void main() {
  const sanitizer = TelemetrySanitizer();

  group('TelemetrySanitizer - headers', () {
    test('redacts Authorization and cookie-like headers', () {
      final result = sanitizer.sanitizeHeaders({
        'Authorization': 'Bearer secret-token',
        'Cookie': 'session=abc123',
        'X-Api-Key': 'super-secret',
        'Content-Type': 'application/json',
      });
      expect(result!['Authorization'], TelemetrySanitizer.redacted);
      expect(result['Cookie'], TelemetrySanitizer.redacted);
      expect(result['X-Api-Key'], TelemetrySanitizer.redacted);
      expect(result['Content-Type'], 'application/json');
    });

    test('returns null for non-map input', () {
      expect(sanitizer.sanitizeHeaders(null), isNull);
      expect(sanitizer.sanitizeHeaders('not a map'), isNull);
    });

    test('redacts headers ending in -token/-secret/-key regardless of case',
        () {
      final result = sanitizer.sanitizeHeaders({
        'X-Refresh-Token': 'abc',
        'x-client-secret': 'def',
      });
      expect(result!['X-Refresh-Token'], TelemetrySanitizer.redacted);
      expect(result['x-client-secret'], TelemetrySanitizer.redacted);
    });
  });

  group('TelemetrySanitizer - body values', () {
    test('redacts sensitive keys recursively', () {
      final result = sanitizer.sanitizeValue({
        'user': {
          'name': 'Ahmed',
          'password': 'hunter2',
          'tokens': ['keep-list-but-redact-key-not-values'],
        },
        'apiKey': 'xyz',
      });
      expect(result['user']['name'], 'Ahmed');
      expect(result['user']['password'], TelemetrySanitizer.redacted);
      expect(result['apiKey'], TelemetrySanitizer.redacted);
    });

    test('leaves non-sensitive nested lists and primitives untouched', () {
      final result = sanitizer.sanitizeValue({
        'items': [1, 2, 3],
        'label': 'ok',
      });
      expect(result['items'], [1, 2, 3]);
      expect(result['label'], 'ok');
    });
  });
}
