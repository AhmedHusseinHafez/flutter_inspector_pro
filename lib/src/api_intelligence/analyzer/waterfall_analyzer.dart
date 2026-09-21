import '../../request_details.dart';
import '../models/finding.dart';
import '../models/waterfall_segment.dart';
import 'analyzer_output.dart';

/// Detects sequential (non-overlapping) runs of requests that look
/// independent, and reports them as a potential parallelization opportunity
/// (spec §11). Never asserts they *can* be parallelized - that requires
/// application-level dependency knowledge this analyzer doesn't have.
class WaterfallAnalyzer {
  const WaterfallAnalyzer._();

  static const _minChainLength = 2;
  static const _maxGapBetweenSegmentsMs = 250;

  static AnalyzerOutput<SequentialChain> analyze(List<RequestDetails> all) {
    final segments = all
        .where((r) => r.receivedTime != null)
        .map((r) => WaterfallSegment(
              endpointLabel: '${r.requestMethod.name} ${r.url}',
              start: r.sentTime,
              end: r.receivedTime!,
            ))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final chains = <SequentialChain>[];
    final findings = <ApiIntelligenceFinding>[];

    var current = <WaterfallSegment>[];
    void flush() {
      if (current.length >= _minChainLength) {
        final totalMs =
            current.last.end.difference(current.first.start).inMilliseconds;
        final sumMs = current
            .map((s) => s.duration.inMilliseconds)
            .reduce((a, b) => a + b);
        final chain = SequentialChain(
          segments: List.of(current),
          totalDurationMs: totalMs,
          sumOfDurationsMs: sumMs,
        );
        chains.add(chain);

        // Only worth flagging when the requests don't overlap (so they
        // aren't already running concurrently) and the endpoints differ
        // (repeated calls to the same endpoint are covered by duplicate/
        // retry analysis instead).
        final distinctEndpoints =
            current.map((s) => s.endpointLabel).toSet();
        if (distinctEndpoints.length == current.length && totalMs > 0) {
          findings.add(
            ApiIntelligenceFinding(
              category: ApiIntelligenceCategory.waterfall,
              severity: FindingSeverity.watch,
              observation: 'Potential parallelization opportunity: '
                  '${current.length} distinct requests executed one after '
                  'another with no overlap.',
              evidence: [
                for (final s in current)
                  '${s.endpointLabel}: ${s.duration.inMilliseconds}ms',
                'observed span: ${totalMs}ms (sum of individual durations: '
                    '${sumMs}ms)',
              ],
              potentialImpact: 'If these requests are independent, running '
                  'them concurrently instead of sequentially could reduce '
                  'total wait time.',
              suggestedInvestigation: 'Confirm whether these requests have '
                  'a genuine data dependency on each other, or whether they '
                  'could be issued in parallel.',
            ),
          );
        }
      }
      current = [];
    }

    for (final segment in segments) {
      if (current.isEmpty) {
        current.add(segment);
        continue;
      }
      final previous = current.last;
      final gap = segment.start.difference(previous.end).inMilliseconds;
      final overlaps = previous.overlaps(segment);
      if (!overlaps && gap >= 0 && gap <= _maxGapBetweenSegmentsMs) {
        current.add(segment);
      } else {
        flush();
        current.add(segment);
      }
    }
    flush();

    return AnalyzerOutput(chains, findings);
  }
}
