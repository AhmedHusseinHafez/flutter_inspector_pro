import '../../request_details.dart';
import '../models/endpoint_metrics.dart';
import '../models/finding.dart';
import '../models/pagination_observation.dart';
import 'analyzer_output.dart';
import 'telemetry_helpers.dart';

/// Flags endpoints that appear to return a large, unpaginated collection in
/// a single response (spec §10).
class PaginationAnalyzer {
  const PaginationAnalyzer._();

  static const _paginationKeys = {
    'page',
    'pagenumber',
    'pageindex',
    'limit',
    'pagesize',
    'cursor',
    'nextcursor',
    'nextpagetoken',
    'total',
    'totalcount',
    'totalitems',
    'hasmore',
    'hasnext',
    'haspreviouspage',
    'hasnextpage',
  };

  static const _largeArrayThreshold = 100;

  static AnalyzerOutput<PaginationObservation> analyze(
    Map<EndpointKey, List<RequestDetails>> byEndpoint,
  ) {
    final observations = <PaginationObservation>[];
    final findings = <ApiIntelligenceFinding>[];

    for (final entry in byEndpoint.entries) {
      final key = entry.key;
      for (final request in entry.value) {
        final body = request.responseBody;
        final largestArray = _findLargestArray(body);
        if (largestArray == null || largestArray.length < _largeArrayThreshold) {
          continue;
        }

        final paginationKeysFound = _findPaginationKeys(body);
        final bytes = TelemetryHelpers.responseBytes(request);

        final observation = PaginationObservation(
          endpointLabel: key.label,
          itemCount: largestArray.length,
          responseBytes: bytes,
          hasPaginationMetadata: paginationKeysFound.isNotEmpty,
          paginationKeysFound: paginationKeysFound,
        );
        observations.add(observation);

        findings.add(
          ApiIntelligenceFinding(
            category: ApiIntelligenceCategory.pagination,
            severity: FindingSeverity.optimizationCandidate,
            endpoint: key.label,
            observation: 'This endpoint returned a large collection in a '
                'single response.',
            evidence: [
              '${observation.itemCount} items returned',
              '${_formatBytes(bytes)} response',
              observation.hasPaginationMetadata
                  ? 'pagination-related fields observed: '
                      '${observation.paginationKeysFound.join(', ')}'
                  : 'no pagination-related fields observed in this response',
            ],
            potentialImpact: 'Returning a full collection in one call can '
                'increase latency, memory usage, and parsing cost, '
                'especially as the underlying dataset grows.',
            suggestedInvestigation: observation.hasPaginationMetadata
                ? 'This call may simply not have requested a page - confirm '
                    'the client is using the available pagination '
                    'parameters.'
                : 'Review whether pagination or server-side filtering is '
                    'appropriate for this endpoint.',
          ),
        );
        // Only report the largest offending call per endpoint to avoid
        // flooding the report with repeats of the same observation.
        break;
      }
    }

    return AnalyzerOutput(observations, findings);
  }

  static List<dynamic>? _findLargestArray(dynamic value, [int depth = 0]) {
    if (depth > 4) return null;
    if (value is List) return value;
    if (value is Map) {
      List<dynamic>? largest;
      for (final v in value.values) {
        final candidate = _findLargestArray(v, depth + 1);
        if (candidate != null &&
            (largest == null || candidate.length > largest.length)) {
          largest = candidate;
        }
      }
      return largest;
    }
    return null;
  }

  static List<String> _findPaginationKeys(dynamic value, [int depth = 0]) {
    if (depth > 3 || value is! Map) return const [];
    final found = <String>{};
    value.forEach((key, v) {
      final normalized = key.toString().toLowerCase().replaceAll('_', '');
      if (_paginationKeys.contains(normalized)) found.add(key.toString());
    });
    for (final v in value.values) {
      if (v is Map) found.addAll(_findPaginationKeys(v, depth + 1));
    }
    return found.toList();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
