import '../../request_details.dart';
import '../models/finding.dart';
import '../models/retry_group.dart';
import 'analyzer_output.dart';
import 'telemetry_helpers.dart';

/// Detects a failed request immediately followed by the same request again
/// (spec §13): request -> failure -> same request -> ... Does not flag
/// auth-refresh-shaped single retries as problematic by default.
class RetryAnalyzer {
  const RetryAnalyzer._();

  static const _retryWindowSeconds = 30;
  static const _minAttemptsToFlag = 3;

  static AnalyzerOutput<RetryGroup> analyze(List<RequestDetails> all) {
    final bySignature = <String, List<RequestDetails>>{};
    for (final r in all) {
      bySignature.putIfAbsent(TelemetryHelpers.requestSignature(r), () => []).add(r);
    }

    final groups = <RetryGroup>[];
    final findings = <ApiIntelligenceFinding>[];
    final window = const Duration(seconds: _retryWindowSeconds);

    for (final requests in bySignature.values) {
      if (requests.length < 2) continue;
      final sorted = [...requests]
        ..sort((a, b) => a.sentTime.compareTo(b.sentTime));

      // Walk the sorted list building chains of: failure followed by the
      // same request within the retry window.
      var chain = <RequestDetails>[sorted.first];
      void flush() {
        if (chain.length >= 2 &&
            chain.sublist(0, chain.length - 1).every(TelemetryHelpers.isFailure)) {
          final endpointLabel =
              '${chain.first.requestMethod.name} ${chain.first.url}';
          final group = RetryGroup(
            endpointLabel: endpointLabel,
            attemptCount: chain.length,
            finalStatusCode: chain.last.statusCode,
            succeededEventually: TelemetryHelpers.isSuccess(chain.last),
            firstAttempt: chain.first.sentTime,
            lastAttempt: chain.last.sentTime,
          );
          groups.add(group);

          if (chain.length >= _minAttemptsToFlag) {
            findings.add(
              ApiIntelligenceFinding(
                category: ApiIntelligenceCategory.reliability,
                severity: group.succeededEventually
                    ? FindingSeverity.watch
                    : FindingSeverity.optimizationCandidate,
                endpoint: endpointLabel,
                observation: 'This request was retried multiple times after '
                    'failing.',
                evidence: [
                  '${group.attemptCount} attempts observed',
                  'final attempt ${group.succeededEventually ? "succeeded" : "also failed"} '
                      '(status ${group.finalStatusCode ?? "none"})',
                  'span of ${chain.last.sentTime.difference(chain.first.sentTime).inMilliseconds}ms',
                ],
                potentialImpact: group.succeededEventually
                    ? 'Repeated retries before success add latency and load, '
                        'even though the user eventually got a result.'
                    : 'Repeated failed retries with no eventual success '
                        'directly affect reliability.',
                suggestedInvestigation: 'Review retry/backoff configuration '
                    'for this endpoint and whether the root failure cause is '
                    'addressable.',
              ),
            );
          }
        }
        chain = [];
      }

      for (var i = 1; i < sorted.length; i++) {
        final prev = sorted[i - 1];
        final curr = sorted[i];
        final withinWindow = curr.sentTime.difference(prev.sentTime) <= window;
        if (TelemetryHelpers.isFailure(prev) && withinWindow) {
          chain.add(curr);
        } else {
          flush();
          chain = [curr];
        }
      }
      flush();
    }

    return AnalyzerOutput(groups, findings);
  }
}
