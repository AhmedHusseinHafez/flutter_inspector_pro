import '../models/caching_observation.dart';
import '../models/endpoint_metrics.dart';
import '../models/finding.dart';
import '../models/payload_analysis.dart';

/// Combines size, complexity-adjacent size class, frequency, latency,
/// caching, and (implicitly, via payload class) compression signals into an
/// overall suitability read for mobile consumption (spec §9). Deliberately
/// not automatic - a large response with low frequency and fast latency is
/// not flagged the same as a large, frequent, slow one.
class MobileSuitabilityAnalyzer {
  const MobileSuitabilityAnalyzer._();

  static List<ApiIntelligenceFinding> analyze({
    required List<EndpointMetrics> metrics,
    required List<PayloadAnalysis> payloads,
    required List<CachingObservation> cachingObservations,
  }) {
    final payloadByEndpoint = {for (final p in payloads) p.endpointLabel: p};
    final cachingByEndpoint = {
      for (final c in cachingObservations) c.endpointLabel: c,
    };

    final findings = <ApiIntelligenceFinding>[];

    for (final m in metrics) {
      final payload = payloadByEndpoint[m.key.label];
      if (payload == null) continue;

      final isFrequent = m.requestCount >= 5;
      final isHeavy = payload.sizeClass == PayloadClass.heavy ||
          payload.sizeClass == PayloadClass.veryHeavy;
      final isSlow =
          m.latencyStats != null && m.latencyStats!.p75Ms >= 1000;
      final caching = cachingByEndpoint[m.key.label];
      final lacksCaching = caching != null && !caching.hasAnyCachingHeader;

      String suitability;
      FindingSeverity severity;
      if (isHeavy && isFrequent && (isSlow || lacksCaching)) {
        suitability = 'Strong optimization candidate';
        severity = FindingSeverity.highPriorityInvestigation;
      } else if (isHeavy && (isFrequent || isSlow)) {
        suitability = 'Worth investigating';
        severity = FindingSeverity.optimizationCandidate;
      } else if (isHeavy) {
        suitability = 'Potentially heavy for mobile';
        severity = FindingSeverity.watch;
      } else {
        suitability = 'Reasonable for mobile';
        severity = FindingSeverity.healthy;
      }

      final evidence = [
        'response size class: ${payload.sizeClass.label}',
        'called ${m.requestCount} time(s) in this session',
        if (m.latencyStats != null)
          'p75 latency ${m.latencyStats!.p75Ms.round()}ms',
        if (caching != null)
          caching.hasAnyCachingHeader
              ? 'caching headers present'
              : 'no caching headers observed',
      ];

      findings.add(
        ApiIntelligenceFinding(
          category: ApiIntelligenceCategory.mobileSuitability,
          severity: severity,
          endpoint: m.key.label,
          observation: '$suitability based on observed size, frequency, '
              'latency, and caching signals.',
          evidence: evidence,
          potentialImpact: severity == FindingSeverity.healthy
              ? null
              : 'Combined size/frequency/latency characteristics may add up '
                  'to a meaningful amount of data and time on mobile '
                  'networks.',
          suggestedInvestigation: severity == FindingSeverity.healthy
              ? null
              : 'Review this endpoint holistically: response shape, call '
                  'frequency, and caching together, not just one metric in '
                  'isolation.',
        ),
      );
    }

    return findings;
  }
}
