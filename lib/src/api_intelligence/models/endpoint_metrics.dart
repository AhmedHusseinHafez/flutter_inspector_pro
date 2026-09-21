/// Identifies "the same endpoint" across multiple captured requests: method
/// + path, with query parameters stripped (query strings vary per call and
/// would otherwise fragment one endpoint into many groups).
class EndpointKey {
  const EndpointKey(this.method, this.path);

  final String method;
  final String path;

  /// Removes the query string (if the URL wasn't already split) and any
  /// trailing slash, so "/users/" and "/users" group together.
  factory EndpointKey.from(String method, String url) {
    final withoutQuery = url.split('?').first;
    final normalized = withoutQuery.length > 1 && withoutQuery.endsWith('/')
        ? withoutQuery.substring(0, withoutQuery.length - 1)
        : withoutQuery;
    return EndpointKey(method.toUpperCase(), normalized);
  }

  String get label => '$method $path';

  @override
  bool operator ==(Object other) =>
      other is EndpointKey && other.method == method && other.path == path;

  @override
  int get hashCode => method.hashCode ^ path.hashCode;

  @override
  String toString() => label;
}

/// Latency distribution for a set of durations (ms). All fields are null
/// when there is no timing data available at all.
class LatencyStats {
  const LatencyStats({
    required this.sampleCount,
    required this.averageMs,
    required this.medianMs,
    required this.p75Ms,
    required this.p95Ms,
    required this.minMs,
    required this.maxMs,
  });

  final int sampleCount;
  final double averageMs;
  final double medianMs;
  final double p75Ms;
  final double p95Ms;
  final double minMs;
  final double maxMs;

  /// Builds stats from a list of durations in milliseconds. Returns null if
  /// [durationsMs] is empty - a metric that cannot be calculated is not
  /// invented.
  static LatencyStats? fromDurations(List<int> durationsMs) {
    if (durationsMs.isEmpty) return null;
    final sorted = [...durationsMs]..sort();
    final n = sorted.length;

    double percentile(double p) {
      if (n == 1) return sorted.first.toDouble();
      final rank = p * (n - 1);
      final lower = rank.floor();
      final upper = rank.ceil();
      if (lower == upper) return sorted[lower].toDouble();
      final weight = rank - lower;
      return sorted[lower] + (sorted[upper] - sorted[lower]) * weight;
    }

    return LatencyStats(
      sampleCount: n,
      averageMs: sorted.reduce((a, b) => a + b) / n,
      medianMs: percentile(0.5),
      p75Ms: percentile(0.75),
      p95Ms: percentile(0.95),
      minMs: sorted.first.toDouble(),
      maxMs: sorted.last.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'sampleCount': sampleCount,
        'averageMs': averageMs.round(),
        'medianMs': medianMs.round(),
        'p75Ms': p75Ms.round(),
        'p95Ms': p95Ms.round(),
        'minMs': minMs.round(),
        'maxMs': maxMs.round(),
      };
}

/// Aggregated, deterministic metrics for one endpoint across the captured
/// session.
class EndpointMetrics {
  const EndpointMetrics({
    required this.key,
    required this.requestCount,
    required this.latencyStats,
    required this.statusCodeCounts,
    required this.successCount,
    required this.errorCount,
    required this.timeoutCount,
    required this.responseSizesBytes,
    required this.averageResponseBytes,
    required this.maxResponseBytes,
  });

  final EndpointKey key;
  final int requestCount;
  final LatencyStats? latencyStats;

  /// HTTP status code -> occurrence count.
  final Map<int, int> statusCodeCounts;

  final int successCount;
  final int errorCount;
  final int timeoutCount;

  final List<int> responseSizesBytes;
  final double? averageResponseBytes;
  final int? maxResponseBytes;

  double get successRate => requestCount == 0 ? 0 : successCount / requestCount;
  double get errorRate => requestCount == 0 ? 0 : errorCount / requestCount;
  double get timeoutRate =>
      requestCount == 0 ? 0 : timeoutCount / requestCount;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'endpoint': key.label,
        'requestCount': requestCount,
        if (latencyStats != null) 'latency': latencyStats!.toMap(),
        'statusCodes': statusCodeCounts.map((k, v) => MapEntry('$k', v)),
        'successRate': successRate,
        'errorRate': errorRate,
        'timeoutRate': timeoutRate,
        if (averageResponseBytes != null)
          'averageResponseBytes': averageResponseBytes!.round(),
        if (maxResponseBytes != null) 'maxResponseBytes': maxResponseBytes,
      };
}
