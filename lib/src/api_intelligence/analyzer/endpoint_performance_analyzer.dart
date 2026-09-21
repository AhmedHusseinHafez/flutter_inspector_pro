import '../../request_details.dart';
import '../models/endpoint_metrics.dart';
import '../models/finding.dart';
import 'analyzer_output.dart';
import 'telemetry_helpers.dart';

/// Computes per-endpoint metrics (§4) and flags endpoints with repeated
/// evidence of slowness (§5). Never flags a single slow request.
class EndpointPerformanceAnalyzer {
  const EndpointPerformanceAnalyzer._();

  /// A single slow request never counts as evidence; this many samples
  /// are required before p75/p95 are used to raise a finding.
  static const _minSamplesForPerformanceFinding = 3;

  static AnalyzerOutput<EndpointMetrics> analyze(
    Map<EndpointKey, List<RequestDetails>> byEndpoint,
  ) {
    final metrics = <EndpointMetrics>[];
    final findings = <ApiIntelligenceFinding>[];

    for (final entry in byEndpoint.entries) {
      final key = entry.key;
      final requests = entry.value;

      final durations = requests
          .map(TelemetryHelpers.durationMs)
          .whereType<int>()
          .toList();
      final latencyStats = LatencyStats.fromDurations(durations);

      final statusCounts = <int, int>{};
      var successCount = 0;
      var errorCount = 0;
      var timeoutCount = 0;
      for (final r in requests) {
        final code = r.statusCode ?? 0;
        statusCounts[code] = (statusCounts[code] ?? 0) + 1;
        if (TelemetryHelpers.isSuccess(r)) {
          successCount++;
        } else {
          errorCount++;
          if (TelemetryHelpers.looksLikeTimeout(r)) timeoutCount++;
        }
      }

      final responseSizes =
          requests.map(TelemetryHelpers.responseBytes).toList();
      final avgBytes = responseSizes.isEmpty
          ? null
          : responseSizes.reduce((a, b) => a + b) / responseSizes.length;
      final maxBytes = responseSizes.isEmpty
          ? null
          : responseSizes.reduce((a, b) => a > b ? a : b);

      final endpointMetrics = EndpointMetrics(
        key: key,
        requestCount: requests.length,
        latencyStats: latencyStats,
        statusCodeCounts: statusCounts,
        successCount: successCount,
        errorCount: errorCount,
        timeoutCount: timeoutCount,
        responseSizesBytes: responseSizes,
        averageResponseBytes: avgBytes,
        maxResponseBytes: maxBytes,
      );
      metrics.add(endpointMetrics);

      if (latencyStats != null &&
          latencyStats.sampleCount >= _minSamplesForPerformanceFinding) {
        findings.addAll(_findingsFor(key, latencyStats));
      }
    }

    return AnalyzerOutput(metrics, findings);
  }

  static List<ApiIntelligenceFinding> _findingsFor(
    EndpointKey key,
    LatencyStats stats,
  ) {
    // Variance signal: how far p95 is from the median, relative to the
    // median itself - a large spread means "usually fine, sometimes slow".
    final spreadRatio =
        stats.medianMs == 0 ? 0 : (stats.p95Ms - stats.medianMs) / stats.medianMs;

    final evidence = [
      '${stats.sampleCount} requests observed',
      'median ${stats.medianMs.round()}ms, p75 ${stats.p75Ms.round()}ms, '
          'p95 ${stats.p95Ms.round()}ms',
      'min ${stats.minMs.round()}ms, max ${stats.maxMs.round()}ms',
    ];

    if (stats.p95Ms >= 3000) {
      return [
        ApiIntelligenceFinding(
          category: ApiIntelligenceCategory.performance,
          severity: FindingSeverity.highPriorityInvestigation,
          endpoint: key.label,
          observation:
              'This endpoint shows consistently high latency across repeated calls.',
          evidence: evidence,
          potentialImpact:
              'Slow responses on a repeated endpoint can add up to noticeable '
              'wait time and increase the chance of user-perceived jank or '
              'timeouts.',
          suggestedInvestigation:
              'Review server-side processing time for this endpoint and '
              'check whether the response can be reduced or the work '
              'deferred/cached.',
        ),
      ];
    }

    if (stats.p95Ms >= 1200 || spreadRatio >= 1.5) {
      return [
        ApiIntelligenceFinding(
          category: ApiIntelligenceCategory.performance,
          severity: FindingSeverity.optimizationCandidate,
          endpoint: key.label,
          observation: spreadRatio >= 1.5
              ? 'This endpoint has high latency variance - most calls are fast '
                  'but some are much slower.'
              : 'This endpoint has elevated p95 latency across repeated calls.',
          evidence: evidence,
          potentialImpact:
              'Inconsistent or elevated latency can degrade perceived '
              'performance intermittently.',
          suggestedInvestigation:
              'Investigate whether specific inputs, payload sizes, or backend '
              'conditions correlate with the slower calls.',
        ),
      ];
    }

    return [
      ApiIntelligenceFinding(
        category: ApiIntelligenceCategory.performance,
        severity: FindingSeverity.healthy,
        endpoint: key.label,
        observation: 'Latency for this endpoint looks stable and low.',
        evidence: evidence,
      ),
    ];
  }
}
