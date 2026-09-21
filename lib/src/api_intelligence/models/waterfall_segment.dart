/// One request's position on the session timeline, used to detect
/// sequential vs. overlapping request behavior (spec §11).
class WaterfallSegment {
  const WaterfallSegment({
    required this.endpointLabel,
    required this.start,
    required this.end,
  });

  final String endpointLabel;
  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  bool overlaps(WaterfallSegment other) =>
      start.isBefore(other.end) && other.start.isBefore(end);
}

/// A detected run of requests that appear sequential (no overlap) and
/// independent enough to flag as a possible parallelization opportunity.
class SequentialChain {
  const SequentialChain({
    required this.segments,
    required this.totalDurationMs,
    required this.sumOfDurationsMs,
  });

  final List<WaterfallSegment> segments;

  /// Wall-clock time from the first segment's start to the last segment's
  /// end.
  final int totalDurationMs;

  /// Sum of each segment's own duration - what the wall-clock time would be
  /// if none of it were saved by overlap (it never is, by definition of a
  /// sequential chain, but kept for the evidence text).
  final int sumOfDurationsMs;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'endpoints': segments.map((s) => s.endpointLabel).toList(),
        'totalDurationMs': totalDurationMs,
        'sumOfDurationsMs': sumOfDurationsMs,
      };
}
