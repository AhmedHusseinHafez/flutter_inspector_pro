import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_intelligence_ai_provider.dart';

/// Built-in [ApiIntelligenceAiProvider] backed by Google's Gemini API. This
/// is the easiest way to turn on AI interpretation: pass a Gemini API key
/// (e.g. via `ApiIntelligenceConfig(geminiApiKey: '...')`) and this provider
/// calls Gemini directly with the already-sanitized analysis payload.
///
/// Note the same caveat that applies to any client-side API key: it can be
/// extracted from the app binary. Fine for local development, internal
/// builds, or a key scoped/rotated for that purpose; for a production app
/// handling untrusted users, prefer routing through your own backend
/// instead (implement [ApiIntelligenceAiProvider] directly for that).
class GeminiApiIntelligenceAiProvider implements ApiIntelligenceAiProvider {
  GeminiApiIntelligenceAiProvider({
    required this.apiKey,
    this.model = 'gemini-2.0-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _client;

  static const _reportInstructions = '''
You are an API/network performance analyst. You are given a JSON payload of
DETERMINISTIC, already-computed network telemetry metrics and findings from a
mobile app's captured network session (from flutter_inspector_pro's API
Intelligence analyzer). You did not calculate any of these numbers - they are
already correct. Your job is pattern interpretation, correlation,
prioritization, and plain-language explanation on top of them.

Rules:
- Never invent metrics, endpoints, or causes that aren't in the given data.
- Never claim a repeated request is *definitely* redundant, a large response
  is *definitely* overfetching, or a slow request is *definitely* a backend
  problem - use "potential"/"worth investigating" language, backed by the
  evidence already in the payload.
- Do not produce a single overall score - use the finding severities already
  provided (Healthy / Watch / Optimization Candidate / High Priority
  Investigation).
- Be concise. Prioritize the most actionable findings first.

Structure your response with these sections (omit a section if there's
nothing to say under it):
Session Overview
Performance
Potential Redundant Requests
Caching Opportunities
Payload Analysis
Pagination
Waterfall / Timing
Status Code Analysis
Retry Analysis
Headers & Compression
Reliability
Mobile Suitability
High Priority Investigations
Optimization Candidates
Healthy Patterns
''';

  @override
  Future<String> generateReport(Map<String, dynamic> sanitizedPayload) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final prompt = '$_reportInstructions\n\n'
        'Analysis data (JSON):\n${json.encode(sanitizedPayload)}';

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: json.encode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gemini API request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Gemini API returned an unexpected response shape.');
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('Gemini API returned no candidates.');
    }

    final content = (candidates.first as Map<String, dynamic>)['content'];
    final parts = content is Map<String, dynamic> ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw Exception('Gemini API returned an empty response.');
    }

    final text = parts
        .map((p) => p is Map<String, dynamic> ? (p['text'] ?? '') : '')
        .join();

    if (text.toString().trim().isEmpty) {
      throw Exception('Gemini API returned an empty response.');
    }

    return text.toString();
  }
}
