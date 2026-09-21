import '../models/endpoint_metrics.dart';
import '../models/finding.dart';

/// Success/error/timeout rate findings per endpoint (spec §16). Always
/// separates "observed" (the rate itself) from "potential cause" language -
/// never invents why an endpoint is failing.
class ReliabilityAnalyzer {
  const ReliabilityAnalyzer._();

  static const _minRequestsToJudgeReliability = 4;

  static List<ApiIntelligenceFinding> analyze(List<EndpointMetrics> metrics) {
    final findings = <ApiIntelligenceFinding>[];

    for (final m in metrics) {
      if (m.requestCount < _minRequestsToJudgeReliability) continue;

      final evidence = [
        '${m.requestCount} requests observed',
        'success rate ${(m.successRate * 100).toStringAsFixed(0)}%',
        'error rate ${(m.errorRate * 100).toStringAsFixed(0)}%',
        if (m.timeoutCount > 0)
          '${m.timeoutCount} of ${m.requestCount} calls appear to have timed out',
      ];

      if (m.errorRate >= 0.5) {
        findings.add(
          ApiIntelligenceFinding(
            category: ApiIntelligenceCategory.reliability,
            severity: FindingSeverity.highPriorityInvestigation,
            endpoint: m.key.label,
            observation:
                'This endpoint failed on a majority of observed calls.',
            evidence: evidence,
            potentialImpact:
                'A high failure rate directly affects reliability and may '
                'be user-visible.',
            suggestedInvestigation:
                'Investigate server-side errors or client request '
                'construction for this endpoint; the root cause cannot be '
                'determined from network telemetry alone.',
          ),
        );
      } else if (m.errorRate >= 0.2 || m.timeoutRate >= 0.1) {
        findings.add(
          ApiIntelligenceFinding(
            category: ApiIntelligenceCategory.reliability,
            severity: FindingSeverity.optimizationCandidate,
            endpoint: m.key.label,
            observation: 'This endpoint shows a non-trivial failure rate '
                'across observed calls.',
            evidence: evidence,
            potentialImpact:
                'Intermittent failures can degrade the experience for a '
                'subset of users or sessions.',
            suggestedInvestigation:
                'Look for patterns in when the failures occur (specific '
                'inputs, network conditions, or backend deploys).',
          ),
        );
      }
    }

    return findings;
  }
}
