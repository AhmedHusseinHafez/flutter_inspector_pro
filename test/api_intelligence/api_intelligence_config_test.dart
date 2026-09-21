import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  group('ApiIntelligenceConfig', () {
    test('with no arguments has no AI provider', () {
      final config = ApiIntelligenceConfig();
      expect(config.aiProvider, isNull);
    });

    test('geminiApiKey builds a GeminiApiIntelligenceAiProvider', () {
      final config = ApiIntelligenceConfig(geminiApiKey: 'my-key');
      expect(config.aiProvider, isA<GeminiApiIntelligenceAiProvider>());
      expect(
        (config.aiProvider as GeminiApiIntelligenceAiProvider).apiKey,
        'my-key',
      );
    });

    test('aiProvider is used as-is when passed', () {
      final provider = _NoopProvider();
      final config = ApiIntelligenceConfig(aiProvider: provider);
      expect(config.aiProvider, same(provider));
    });

    test('passing both aiProvider and geminiApiKey asserts', () {
      expect(
        () => ApiIntelligenceConfig(
          aiProvider: _NoopProvider(),
          geminiApiKey: 'my-key',
        ),
        throwsAssertionError,
      );
    });
  });
}

class _NoopProvider implements ApiIntelligenceAiProvider {
  @override
  Future<String> generateReport(Map<String, dynamic> sanitizedPayload) async =>
      '';
}
