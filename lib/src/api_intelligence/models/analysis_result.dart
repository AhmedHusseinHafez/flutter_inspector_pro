import 'caching_observation.dart';
import 'compression_observation.dart';
import 'duplicate_group.dart';
import 'endpoint_metrics.dart';
import 'finding.dart';
import 'header_observation.dart';
import 'pagination_observation.dart';
import 'payload_analysis.dart';
import 'retry_group.dart';
import 'session_metrics.dart';
import 'waterfall_segment.dart';

/// The full output of one on-demand deterministic analysis pass over the
/// captured network session (spec §4-§19). The AI layer (if configured) is
/// given a sanitized, aggregated view of this - it is never the source of
/// these numbers.
class ApiIntelligenceAnalysisResult {
  const ApiIntelligenceAnalysisResult({
    required this.analyzedAt,
    required this.session,
    required this.endpointMetrics,
    required this.duplicateGroups,
    required this.cachingObservations,
    required this.payloadAnalyses,
    required this.paginationObservations,
    required this.sequentialChains,
    required this.retryGroups,
    required this.compressionObservations,
    required this.headerObservations,
    required this.findings,
    this.hasTimingPhaseData = false,
  });

  final DateTime analyzedAt;
  final SessionMetrics session;
  final List<EndpointMetrics> endpointMetrics;
  final List<DuplicateGroup> duplicateGroups;
  final List<CachingObservation> cachingObservations;
  final List<PayloadAnalysis> payloadAnalyses;
  final List<PaginationObservation> paginationObservations;
  final List<SequentialChain> sequentialChains;
  final List<RetryGroup> retryGroups;
  final List<CompressionObservation> compressionObservations;
  final List<HeaderObservation> headerObservations;
  final List<ApiIntelligenceFinding> findings;

  /// Always false today: only total request duration is captured, never
  /// DNS/connect/TLS/TTFB phases. Kept explicit so the UI and AI prompt can
  /// say so plainly (spec §5).
  final bool hasTimingPhaseData;

  List<ApiIntelligenceFinding> findingsOf(ApiIntelligenceCategory category) =>
      findings.where((f) => f.category == category).toList(growable: false);

  List<ApiIntelligenceFinding> get highPriorityFindings => findings
      .where((f) => f.severity == FindingSeverity.highPriorityInvestigation)
      .toList(growable: false);

  List<ApiIntelligenceFinding> get optimizationCandidates => findings
      .where((f) => f.severity == FindingSeverity.optimizationCandidate)
      .toList(growable: false);

  List<ApiIntelligenceFinding> get healthyFindings => findings
      .where((f) => f.severity == FindingSeverity.healthy)
      .toList(growable: false);

  List<ApiIntelligenceFinding> get watchFindings => findings
      .where((f) => f.severity == FindingSeverity.watch)
      .toList(growable: false);
}
