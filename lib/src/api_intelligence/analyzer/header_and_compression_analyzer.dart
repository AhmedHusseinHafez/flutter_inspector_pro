import '../../request_details.dart';
import '../models/compression_observation.dart';
import '../models/endpoint_metrics.dart';
import '../models/finding.dart';
import '../models/header_observation.dart';
import 'telemetry_helpers.dart';

class HeaderAndCompressionResult {
  const HeaderAndCompressionResult(
    this.headerObservations,
    this.compressionObservations,
    this.findings,
  );

  final List<HeaderObservation> headerObservations;
  final List<CompressionObservation> compressionObservations;
  final List<ApiIntelligenceFinding> findings;
}

/// Header hygiene (spec §14) and compression evidence (spec §15) per
/// endpoint, derived from captured request/response headers.
class HeaderAndCompressionAnalyzer {
  const HeaderAndCompressionAnalyzer._();

  static const _uncompressedLargeResponseBytes = 50 * 1024;

  static HeaderAndCompressionResult analyze(
    Map<EndpointKey, List<RequestDetails>> byEndpoint,
  ) {
    final headerObservations = <HeaderObservation>[];
    final compressionObservations = <CompressionObservation>[];
    final findings = <ApiIntelligenceFinding>[];

    for (final entry in byEndpoint.entries) {
      final key = entry.key;
      final requests = entry.value;

      var redirectCount = 0;
      var reqHeaderTotal = 0;
      var resHeaderTotal = 0;
      var hasContentEncoding = false;
      var hasVary = false;
      var hasRetryAfter = false;

      for (final r in requests) {
        if ((r.statusCode ?? 0) >= 300 && (r.statusCode ?? 0) < 400) {
          redirectCount++;
        }
        reqHeaderTotal += TelemetryHelpers.headerCount(r.headers);
        resHeaderTotal += TelemetryHelpers.headerCount(r.responseHeaders);
        if (TelemetryHelpers.hasHeader(r.responseHeaders, 'content-encoding')) {
          hasContentEncoding = true;
        }
        if (TelemetryHelpers.hasHeader(r.responseHeaders, 'vary')) {
          hasVary = true;
        }
        if (TelemetryHelpers.hasHeader(r.responseHeaders, 'retry-after')) {
          hasRetryAfter = true;
        }
      }

      headerObservations.add(
        HeaderObservation(
          endpointLabel: key.label,
          requestHeaderCount: requests.isEmpty
              ? 0
              : (reqHeaderTotal / requests.length).round(),
          responseHeaderCount: requests.isEmpty
              ? 0
              : (resHeaderTotal / requests.length).round(),
          hasContentEncoding: hasContentEncoding,
          hasVary: hasVary,
          hasRetryAfter: hasRetryAfter,
          redirectCount: redirectCount,
        ),
      );

      // Compression: only report where both a decoded size and a declared
      // Content-Length are available, so a ratio can actually be computed.
      for (final r in requests) {
        final decodedBytes = TelemetryHelpers.responseBytes(r);
        if (decodedBytes == 0) continue;
        final contentLengthHeader =
            TelemetryHelpers.headerValue(r.responseHeaders, 'content-length');
        final declaredLength = contentLengthHeader == null
            ? null
            : int.tryParse(contentLengthHeader);
        final contentEncoding =
            TelemetryHelpers.headerValue(r.responseHeaders, 'content-encoding');

        if (contentEncoding != null || declaredLength != null) {
          compressionObservations.add(
            CompressionObservation(
              endpointLabel: key.label,
              contentEncoding: contentEncoding,
              decodedBytes: decodedBytes,
              declaredContentLength: declaredLength,
            ),
          );
        }

        if (contentEncoding == null &&
            decodedBytes >= _uncompressedLargeResponseBytes) {
          findings.add(
            ApiIntelligenceFinding(
              category: ApiIntelligenceCategory.http,
              severity: FindingSeverity.optimizationCandidate,
              endpoint: key.label,
              observation: 'A large response was observed without a '
                  'Content-Encoding header.',
              evidence: [
                'decoded response size ~${(decodedBytes / 1024).toStringAsFixed(1)} KB',
                'no Content-Encoding header present',
              ],
              potentialImpact: 'Uncompressed large responses increase '
                  'transfer time and mobile data usage.',
              suggestedInvestigation:
                  'Check whether gzip/br compression can be enabled for '
                  'this endpoint.',
            ),
          );
        }
        break; // one representative sample per endpoint is enough evidence
      }
    }

    return HeaderAndCompressionResult(
      headerObservations,
      compressionObservations,
      findings,
    );
  }
}
