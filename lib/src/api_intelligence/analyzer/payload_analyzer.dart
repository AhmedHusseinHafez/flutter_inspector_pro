import '../../request_details.dart';
import '../models/endpoint_metrics.dart';
import '../models/finding.dart';
import '../models/payload_analysis.dart';
import '../models/response_complexity.dart';
import 'analyzer_output.dart';
import 'telemetry_helpers.dart';

/// Payload size classification (§8) and structural complexity (§19) per
/// endpoint.
class PayloadAnalyzer {
  const PayloadAnalyzer._();

  static AnalyzerOutput<PayloadAnalysis> analyze(
    Map<EndpointKey, List<RequestDetails>> byEndpoint,
  ) {
    final analyses = <PayloadAnalysis>[];
    final findings = <ApiIntelligenceFinding>[];

    for (final entry in byEndpoint.entries) {
      final key = entry.key;
      final requests = entry.value;
      final sizes = requests.map(TelemetryHelpers.responseBytes).toList();
      if (sizes.every((s) => s == 0)) continue;

      final avg = sizes.reduce((a, b) => a + b) / sizes.length;
      final max = sizes.reduce((a, b) => a > b ? a : b);
      final sizeClass = PayloadAnalysis.classify(max);

      final analysis = PayloadAnalysis(
        endpointLabel: key.label,
        averageBytes: avg,
        maxBytes: max,
        sizeClass: sizeClass,
      );
      analyses.add(analysis);

      // Complexity from the largest observed response for this endpoint.
      final largest = requests.reduce(
        (a, b) => TelemetryHelpers.responseBytes(a) >=
                TelemetryHelpers.responseBytes(b)
            ? a
            : b,
      );
      final complexity = ResponseComplexity.analyze(largest.responseBody);

      if (sizeClass == PayloadClass.veryHeavy ||
          sizeClass == PayloadClass.heavy) {
        final evidence = [
          '${requests.length} requests observed',
          'average response ${_formatBytes(avg.round())}',
          'largest response ${_formatBytes(max)}',
          if (complexity != null)
            'largest response: ${complexity.objectCount} objects, '
                '${complexity.arrayCount} arrays, max array length '
                '${complexity.maxArrayLength}, nesting depth '
                '${complexity.maxNestingDepth}',
        ];

        findings.add(
          ApiIntelligenceFinding(
            category: ApiIntelligenceCategory.payload,
            severity: sizeClass == PayloadClass.veryHeavy
                ? FindingSeverity.highPriorityInvestigation
                : FindingSeverity.optimizationCandidate,
            endpoint: key.label,
            observation:
                'This endpoint returned a ${sizeClass.label.toLowerCase()} '
                'response payload.',
            evidence: evidence,
            potentialImpact: 'Large payloads may increase transfer time, '
                'memory usage, and JSON processing cost on mobile devices.',
            suggestedInvestigation: 'Review whether pagination, field '
                'filtering, or a leaner response shape is appropriate for '
                'this endpoint.',
          ),
        );
      }
    }

    return AnalyzerOutput(analyses, findings);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
