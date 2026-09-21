import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:requests_inspector/requests_inspector.dart';

void main() {
  group('GeminiApiIntelligenceAiProvider', () {
    test('sends the API key as a header and the payload as JSON, and '
        'returns the model\'s text', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;

      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = json.decode(request.body) as Map<String, dynamic>;
        return http.Response(
          json.encode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'API INTELLIGENCE REPORT\n\nlooks fine'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final provider = GeminiApiIntelligenceAiProvider(
        apiKey: 'test-key',
        client: client,
      );

      final report = await provider.generateReport({
        'session': {'requestCount': 3},
      });

      expect(report, contains('looks fine'));
      expect(capturedUri!.host, 'generativelanguage.googleapis.com');
      expect(capturedHeaders!['x-goog-api-key'], 'test-key');
      expect(
        (capturedBody!['contents'] as List).first['parts'][0]['text'],
        contains('"requestCount":3'),
      );
    });

    test('throws with the status code and body on a non-2xx response', () async {
      final client = MockClient((request) async {
        return http.Response('{"error": "bad key"}', 403);
      });
      final provider =
          GeminiApiIntelligenceAiProvider(apiKey: 'bad-key', client: client);

      expect(
        () => provider.generateReport(const {}),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('403'), contains('bad key')),
        )),
      );
    });

    test('throws when the response has no candidates', () async {
      final client = MockClient((request) async {
        return http.Response(json.encode({'candidates': []}), 200);
      });
      final provider =
          GeminiApiIntelligenceAiProvider(apiKey: 'k', client: client);

      expect(() => provider.generateReport(const {}), throwsException);
    });

    test('throws when the response text is empty', () async {
      final client = MockClient((request) async {
        return http.Response(
          json.encode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '   '},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final provider =
          GeminiApiIntelligenceAiProvider(apiKey: 'k', client: client);

      expect(() => provider.generateReport(const {}), throwsException);
    });
  });
}
