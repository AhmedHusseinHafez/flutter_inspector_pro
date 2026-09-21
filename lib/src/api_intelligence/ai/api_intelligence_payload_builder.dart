import '../models/analysis_result.dart';
import '../sanitizer/telemetry_sanitizer.dart';

/// Turns an [ApiIntelligenceAnalysisResult] into the sanitized, aggregated
/// JSON-ish payload handed to an [ApiIntelligenceAiProvider] (spec §23). The
/// AI layer never receives raw request/response bodies - only the
/// deterministic, already-redacted evidence.
class ApiIntelligencePayloadBuilder {
  const ApiIntelligencePayloadBuilder([
    this._sanitizer = const TelemetrySanitizer(),
  ]);

  final TelemetrySanitizer _sanitizer;

  Map<String, dynamic> build(ApiIntelligenceAnalysisResult result) {
    final payload = <String, dynamic>{
      'session': result.session.toMap(),
      'hasTimingPhaseData': result.hasTimingPhaseData,
      'endpoints': result.endpointMetrics.map((e) => e.toMap()).toList(),
      'duplicates': result.duplicateGroups.map((d) => d.toMap()).toList(),
      'caching': result.cachingObservations.map((c) => c.toMap()).toList(),
      'payloads': result.payloadAnalyses.map((p) => p.toMap()).toList(),
      'pagination':
          result.paginationObservations.map((p) => p.toMap()).toList(),
      'waterfall': result.sequentialChains.map((w) => w.toMap()).toList(),
      'retries': result.retryGroups.map((r) => r.toMap()).toList(),
      'compression':
          result.compressionObservations.map((c) => c.toMap()).toList(),
      'headers': result.headerObservations.map((h) => h.toMap()).toList(),
      'findings': result.findings.map((f) => f.toMap()).toList(),
    };

    return _sanitizer.sanitizeValue(payload) as Map<String, dynamic>;
  }
}
