import 'endpoint_metrics.dart';

/// Top-level session summary numbers (spec §18). Every field is derived
/// directly from the captured requests - nothing here is invented.
class SessionMetrics {
  const SessionMetrics({
    required this.requestCount,
    required this.uniqueEndpointCount,
    required this.totalResponseBytes,
    required this.capturedSpanMs,
    required this.slowestEndpoints,
    required this.mostFrequentEndpoints,
    required this.largestEndpointsByTotalBytes,
    required this.failedRequestCount,
  });

  final int requestCount;
  final int uniqueEndpointCount;
  final int totalResponseBytes;

  /// Time between the first request's sent time and the last request's
  /// received (or sent, if missing) time, in milliseconds. Null if there
  /// isn't enough timing data to compute it.
  final int? capturedSpanMs;

  final List<EndpointKey> slowestEndpoints;
  final List<EndpointKey> mostFrequentEndpoints;
  final List<EndpointKey> largestEndpointsByTotalBytes;
  final int failedRequestCount;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'requestCount': requestCount,
        'uniqueEndpoints': uniqueEndpointCount,
        'totalResponseBytes': totalResponseBytes,
        if (capturedSpanMs != null) 'capturedSpanMs': capturedSpanMs,
        'slowestEndpoints': slowestEndpoints.map((e) => e.label).toList(),
        'mostFrequentEndpoints':
            mostFrequentEndpoints.map((e) => e.label).toList(),
        'largestEndpointsByTotalBytes':
            largestEndpointsByTotalBytes.map((e) => e.label).toList(),
        'failedRequestCount': failedRequestCount,
      };
}
