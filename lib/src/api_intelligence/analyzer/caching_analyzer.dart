import '../../request_details.dart';
import '../models/caching_observation.dart';
import '../models/endpoint_metrics.dart';
import '../models/finding.dart';
import 'analyzer_output.dart';
import 'telemetry_helpers.dart';

/// Reads caching-related response headers to spot potential caching
/// opportunities (spec §7) - GET endpoints that are called repeatedly, with
/// stable responses, but weak/missing caching headers.
class CachingAnalyzer {
  const CachingAnalyzer._();

  static const _minCallsToConsider = 3;

  static AnalyzerOutput<CachingObservation> analyze(
    Map<EndpointKey, List<RequestDetails>> byEndpoint,
  ) {
    final observations = <CachingObservation>[];
    final findings = <ApiIntelligenceFinding>[];

    for (final entry in byEndpoint.entries) {
      final key = entry.key;
      if (key.method != 'GET') continue;
      final requests = entry.value;
      if (requests.length < 2) continue;

      final hasCacheControl =
          requests.any((r) => TelemetryHelpers.hasHeader(r.responseHeaders, 'cache-control'));
      final hasETag =
          requests.any((r) => TelemetryHelpers.hasHeader(r.responseHeaders, 'etag'));
      final hasLastModified = requests
          .any((r) => TelemetryHelpers.hasHeader(r.responseHeaders, 'last-modified'));
      final hasExpires =
          requests.any((r) => TelemetryHelpers.hasHeader(r.responseHeaders, 'expires'));

      var stablePairs = 0;
      var totalPairs = 0;
      for (var i = 1; i < requests.length; i++) {
        totalPairs++;
        if (TelemetryHelpers.haveIdenticalResponses(
            requests[i - 1], requests[i])) {
          stablePairs++;
        }
      }
      final responsesLookStable = totalPairs > 0 && stablePairs == totalPairs;

      final observation = CachingObservation(
        endpointLabel: key.label,
        callCount: requests.length,
        hasCacheControl: hasCacheControl,
        hasETag: hasETag,
        hasLastModified: hasLastModified,
        hasExpires: hasExpires,
        responsesLookStable: responsesLookStable,
      );
      observations.add(observation);

      if (requests.length >= _minCallsToConsider &&
          responsesLookStable &&
          !observation.hasAnyCachingHeader) {
        findings.add(
          ApiIntelligenceFinding(
            category: ApiIntelligenceCategory.caching,
            severity: FindingSeverity.optimizationCandidate,
            endpoint: key.label,
            observation: 'Potential caching opportunity: this endpoint was '
                'called repeatedly and returned a stable response, but no '
                'caching headers were observed.',
            evidence: [
              '${requests.length} calls observed',
              'response body was identical across all observed calls',
              'no Cache-Control, ETag, Last-Modified, or Expires header seen',
            ],
            potentialImpact: 'Without caching hints, the client (or an '
                'intermediary) has no signal that it is safe to reuse the '
                'previous response, so every call pays full network cost.',
            suggestedInvestigation: 'Check whether the server can add '
                'Cache-Control/ETag headers, or whether the client can cache '
                'this response locally.',
          ),
        );
      }
    }

    return AnalyzerOutput(observations, findings);
  }
}
