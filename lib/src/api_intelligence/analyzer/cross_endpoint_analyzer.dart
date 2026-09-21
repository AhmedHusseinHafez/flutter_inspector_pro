import '../../request_details.dart';
import '../models/endpoint_metrics.dart';
import '../models/finding.dart';

/// Looks for overlap between distinct endpoints' response shapes (spec
/// §17) - e.g. two endpoints that both return a large overlapping set of
/// top-level keys, suggesting the same resource may be fetched more than
/// one way. Always phrased as a potential overlap with evidence, never as a
/// confirmed duplicate.
class CrossEndpointAnalyzer {
  const CrossEndpointAnalyzer._();

  static const _minOverlapKeys = 3;
  static const _minOverlapRatio = 0.6;

  static List<ApiIntelligenceFinding> analyze(
    Map<EndpointKey, List<RequestDetails>> byEndpoint,
  ) {
    final findings = <ApiIntelligenceFinding>[];

    final keySets = <EndpointKey, Set<String>>{};
    for (final entry in byEndpoint.entries) {
      final sample = entry.value.firstWhere(
        (r) => r.responseBody is Map,
        orElse: () => entry.value.first,
      );
      if (sample.responseBody is Map) {
        keySets[entry.key] =
            (sample.responseBody as Map).keys.map((k) => k.toString()).toSet();
      }
    }

    final keys = keySets.keys.toList();
    for (var i = 0; i < keys.length; i++) {
      for (var j = i + 1; j < keys.length; j++) {
        final a = keySets[keys[i]]!;
        final b = keySets[keys[j]]!;
        if (a.length < _minOverlapKeys || b.length < _minOverlapKeys) continue;

        final overlap = a.intersection(b);
        final smaller = a.length < b.length ? a.length : b.length;
        final ratio = smaller == 0 ? 0 : overlap.length / smaller;

        if (overlap.length >= _minOverlapKeys && ratio >= _minOverlapRatio) {
          findings.add(
            ApiIntelligenceFinding(
              category: ApiIntelligenceCategory.redundancy,
              severity: FindingSeverity.watch,
              endpoint: '${keys[i].label} / ${keys[j].label}',
              observation: 'These two endpoints return responses with '
                  'substantially overlapping fields.',
              evidence: [
                '${overlap.length} shared top-level fields: '
                    '${overlap.take(8).join(', ')}${overlap.length > 8 ? ', ...' : ''}',
              ],
              potentialImpact: 'If both endpoints are fetching the same '
                  'underlying resource, calling both may be unnecessary.',
              suggestedInvestigation:
                  'Confirm whether these endpoints serve the same resource '
                  'and whether one call could be avoided.',
            ),
          );
        }
      }
    }

    return findings;
  }
}
