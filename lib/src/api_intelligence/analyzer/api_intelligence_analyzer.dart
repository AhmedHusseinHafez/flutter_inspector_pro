import '../../request_details.dart';
import '../models/analysis_result.dart';
import '../models/endpoint_metrics.dart';
import '../models/finding.dart';
import 'caching_analyzer.dart';
import 'cross_endpoint_analyzer.dart';
import 'duplicate_request_analyzer.dart';
import 'endpoint_performance_analyzer.dart';
import 'header_and_compression_analyzer.dart';
import 'mobile_suitability_analyzer.dart';
import 'pagination_analyzer.dart';
import 'payload_analyzer.dart';
import 'reliability_analyzer.dart';
import 'retry_analyzer.dart';
import 'session_analyzer.dart';
import 'status_code_analyzer.dart';
import 'waterfall_analyzer.dart';

/// Deterministic entry point for API Intelligence (spec §4). Runs entirely
/// over already-captured [RequestDetails] - no network calls, no AI, no
/// Dart source inspection. Always available even when no AI provider is
/// configured.
class ApiIntelligenceAnalyzer {
  const ApiIntelligenceAnalyzer._();

  static ApiIntelligenceAnalysisResult analyze(List<RequestDetails> requests) {
    final byEndpoint = <EndpointKey, List<RequestDetails>>{};
    for (final r in requests) {
      byEndpoint
          .putIfAbsent(EndpointKey.from(r.requestMethod.name, r.url), () => [])
          .add(r);
    }

    final performance = EndpointPerformanceAnalyzer.analyze(byEndpoint);
    final duplicates = DuplicateRequestAnalyzer.analyze(requests);
    final caching = CachingAnalyzer.analyze(byEndpoint);
    final payloads = PayloadAnalyzer.analyze(byEndpoint);
    final pagination = PaginationAnalyzer.analyze(byEndpoint);
    final waterfall = WaterfallAnalyzer.analyze(requests);
    final statusCodeFindings = StatusCodeAnalyzer.analyze(byEndpoint);
    final retries = RetryAnalyzer.analyze(requests);
    final headersAndCompression = HeaderAndCompressionAnalyzer.analyze(byEndpoint);
    final reliabilityFindings = ReliabilityAnalyzer.analyze(performance.items);
    final crossEndpointFindings = CrossEndpointAnalyzer.analyze(byEndpoint);
    final mobileSuitabilityFindings = MobileSuitabilityAnalyzer.analyze(
      metrics: performance.items,
      payloads: payloads.items,
      cachingObservations: caching.items,
    );

    final session = SessionAnalyzer.analyze(requests, byEndpoint, performance.items);

    final findings = <ApiIntelligenceFinding>[
      ...performance.findings,
      ...duplicates.findings,
      ...caching.findings,
      ...payloads.findings,
      ...pagination.findings,
      ...waterfall.findings,
      ...statusCodeFindings,
      ...retries.findings,
      ...headersAndCompression.findings,
      ...reliabilityFindings,
      ...crossEndpointFindings,
      ...mobileSuitabilityFindings,
    ];

    return ApiIntelligenceAnalysisResult(
      analyzedAt: DateTime.now(),
      session: session,
      endpointMetrics: performance.items,
      duplicateGroups: duplicates.items,
      cachingObservations: caching.items,
      payloadAnalyses: payloads.items,
      paginationObservations: pagination.items,
      sequentialChains: waterfall.items,
      retryGroups: retries.items,
      compressionObservations: headersAndCompression.compressionObservations,
      headerObservations: headersAndCompression.headerObservations,
      findings: findings,
    );
  }
}
