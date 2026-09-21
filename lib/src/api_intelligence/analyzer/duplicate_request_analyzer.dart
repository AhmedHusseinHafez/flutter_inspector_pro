import '../../request_details.dart';
import '../models/duplicate_group.dart';
import '../models/finding.dart';
import 'analyzer_output.dart';
import 'telemetry_helpers.dart';

/// Groups requests that share the same method/URL/query/body signature and
/// reports them as *potential* redundant requests (spec §6) - never as
/// definitely redundant, since a legitimate refresh/retry/poll looks
/// identical in telemetry.
class DuplicateRequestAnalyzer {
  const DuplicateRequestAnalyzer._();

  static const shortWindowSeconds = 5;
  static const _minOccurrencesToFlag = 3;

  static AnalyzerOutput<DuplicateGroup> analyze(List<RequestDetails> all) {
    final bySignature = <String, List<RequestDetails>>{};
    for (final request in all) {
      bySignature
          .putIfAbsent(TelemetryHelpers.requestSignature(request), () => [])
          .add(request);
    }

    final groups = <DuplicateGroup>[];
    final findings = <ApiIntelligenceFinding>[];
    final window = const Duration(seconds: shortWindowSeconds);

    for (final requests in bySignature.values) {
      if (requests.length < 2) continue;

      final sorted = [...requests]..sort((a, b) => a.sentTime.compareTo(b.sentTime));

      var identicalCount = 0;
      var withinWindowCount = 0;
      for (var i = 1; i < sorted.length; i++) {
        final prev = sorted[i - 1];
        final curr = sorted[i];
        if (TelemetryHelpers.haveIdenticalResponses(prev, curr)) {
          identicalCount++;
        }
        if (curr.sentTime.difference(prev.sentTime) <= window) {
          withinWindowCount++;
        }
      }
      // The first response also counts toward "identical" bookkeeping when
      // comparing pairs above; add 1 so identicalCount reflects requests
      // sharing a value, not just transitions.
      if (identicalCount > 0) identicalCount++;

      final endpointLabel =
          '${sorted.first.requestMethod.name} ${sorted.first.url}';

      final group = DuplicateGroup(
        endpointLabel: endpointLabel,
        occurrenceCount: sorted.length,
        identicalResponseCount: identicalCount,
        withinShortWindowCount: withinWindowCount,
        shortWindowSeconds: shortWindowSeconds,
      );
      groups.add(group);

      if (sorted.length >= _minOccurrencesToFlag) {
        final severity = withinWindowCount >= sorted.length - 1
            ? FindingSeverity.optimizationCandidate
            : FindingSeverity.watch;
        findings.add(
          ApiIntelligenceFinding(
            category: ApiIntelligenceCategory.redundancy,
            severity: severity,
            endpoint: endpointLabel,
            observation: 'Potential redundant request: the same request was '
                'observed multiple times with an identical signature.',
            evidence: [
              '${group.occurrenceCount} calls with the same method, URL, '
                  'query, and body',
              '${group.identicalResponseCount} calls returned an identical '
                  'response',
              '${group.withinShortWindowCount} calls occurred within '
                  '$shortWindowSeconds seconds of another call to the same '
                  'signature',
            ],
            potentialImpact: 'Repeated identical calls may waste network '
                'and battery if they are not intentional (e.g. polling, '
                'retries, or navigation-triggered refreshes).',
            suggestedInvestigation:
                'Confirm whether these calls are expected (polling, retry, '
                'refresh) or could be deduplicated/cached.',
          ),
        );
      }
    }

    return AnalyzerOutput(groups, findings);
  }
}
