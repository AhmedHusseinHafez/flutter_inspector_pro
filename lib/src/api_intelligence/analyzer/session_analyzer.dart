import '../../request_details.dart';
import '../models/endpoint_metrics.dart';
import '../models/session_metrics.dart';
import 'telemetry_helpers.dart';

/// Top-level session summary numbers (spec §18).
class SessionAnalyzer {
  const SessionAnalyzer._();

  static const _topN = 5;

  static SessionMetrics analyze(
    List<RequestDetails> all,
    Map<EndpointKey, List<RequestDetails>> byEndpoint,
    List<EndpointMetrics> metrics,
  ) {
    final totalBytes =
        all.map(TelemetryHelpers.responseBytes).fold<int>(0, (a, b) => a + b);

    int? spanMs;
    if (all.isNotEmpty) {
      final sentTimes = all.map((r) => r.sentTime);
      final endTimes =
          all.map((r) => r.receivedTime ?? r.sentTime);
      final earliest = sentTimes.reduce((a, b) => a.isBefore(b) ? a : b);
      final latest = endTimes.reduce((a, b) => a.isAfter(b) ? a : b);
      spanMs = latest.difference(earliest).inMilliseconds;
    }

    final byLatency = [...metrics]
      ..removeWhere((m) => m.latencyStats == null)
      ..sort((a, b) =>
          b.latencyStats!.p95Ms.compareTo(a.latencyStats!.p95Ms));

    final byFrequency = [...metrics]
      ..sort((a, b) => b.requestCount.compareTo(a.requestCount));

    final byTotalBytes = [...metrics]
      ..sort((a, b) {
        final aTotal = a.responseSizesBytes.fold<int>(0, (x, y) => x + y);
        final bTotal = b.responseSizesBytes.fold<int>(0, (x, y) => x + y);
        return bTotal.compareTo(aTotal);
      });

    final failedCount = all.where(TelemetryHelpers.isFailure).length;

    return SessionMetrics(
      requestCount: all.length,
      uniqueEndpointCount: byEndpoint.length,
      totalResponseBytes: totalBytes,
      capturedSpanMs: spanMs,
      slowestEndpoints:
          byLatency.take(_topN).map((m) => m.key).toList(growable: false),
      mostFrequentEndpoints:
          byFrequency.take(_topN).map((m) => m.key).toList(growable: false),
      largestEndpointsByTotalBytes:
          byTotalBytes.take(_topN).map((m) => m.key).toList(growable: false),
      failedRequestCount: failedCount,
    );
  }
}
