import '../../request_details.dart';
import '../models/endpoint_metrics.dart';
import '../models/finding.dart';

/// Per-endpoint status code patterns (spec §12). Deliberately does not treat
/// any single status code as inherently bad - 404/409/422/401 can all be
/// expected business behavior.
class StatusCodeAnalyzer {
  const StatusCodeAnalyzer._();

  static const _minOccurrencesToFlag = 3;

  static List<ApiIntelligenceFinding> analyze(
    Map<EndpointKey, List<RequestDetails>> byEndpoint,
  ) {
    final findings = <ApiIntelligenceFinding>[];

    for (final entry in byEndpoint.entries) {
      final key = entry.key;
      final requests = entry.value;
      final counts = <int, int>{};
      for (final r in requests) {
        final code = r.statusCode ?? 0;
        counts[code] = (counts[code] ?? 0) + 1;
      }

      void flagRepeated(int code, String label, String impact) {
        final count = counts[code] ?? 0;
        if (count < _minOccurrencesToFlag) return;
        findings.add(
          ApiIntelligenceFinding(
            category: ApiIntelligenceCategory.http,
            severity: FindingSeverity.watch,
            endpoint: key.label,
            observation: 'Repeated $label responses observed on this '
                'endpoint.',
            evidence: [
              '$count of ${requests.length} calls returned $code',
            ],
            potentialImpact: impact,
            suggestedInvestigation:
                'Confirm whether this pattern is expected business behavior '
                'or indicates an underlying issue.',
          ),
        );
      }

      flagRepeated(401, '401 Unauthorized',
          'May indicate a token refresh loop or an auth flow worth reviewing.');
      flagRepeated(403, '403 Forbidden',
          'May indicate a permissions mismatch between client and server.');
      flagRepeated(404, '404 Not Found',
          'Could be expected (e.g. existence checks) or could indicate a '
              'stale/incorrect URL being called repeatedly.');
      flagRepeated(409, '409 Conflict',
          'Often represents a normal business conflict, but worth '
              'confirming the client handles it gracefully.');
      flagRepeated(422, '422 Unprocessable Entity',
          'Often represents validation failures - worth checking whether '
              'the client is sending data the server consistently rejects.');
      flagRepeated(429, '429 Too Many Requests',
          'Indicates the client is being rate-limited by the server.');

      final serverErrorCount = counts.entries
          .where((e) => e.key >= 500)
          .fold<int>(0, (a, e) => a + e.value);
      if (serverErrorCount >= _minOccurrencesToFlag) {
        findings.add(
          ApiIntelligenceFinding(
            category: ApiIntelligenceCategory.reliability,
            severity: FindingSeverity.highPriorityInvestigation,
            endpoint: key.label,
            observation:
                'Repeated server error (5xx) responses observed on this '
                'endpoint.',
            evidence: [
              '$serverErrorCount of ${requests.length} calls returned a 5xx '
                  'status',
            ],
            potentialImpact:
                'Repeated server errors directly affect reliability and '
                'user-visible failures.',
            suggestedInvestigation:
                'Investigate server-side logs for this endpoint around the '
                'observed failure times.',
          ),
        );
      }
    }

    return findings;
  }
}
