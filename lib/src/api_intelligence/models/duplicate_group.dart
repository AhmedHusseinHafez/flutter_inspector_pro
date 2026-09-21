/// Evidence for a set of requests that look like potential duplicates of one
/// another (spec §6). Never asserts the repetition is definitely redundant.
class DuplicateGroup {
  const DuplicateGroup({
    required this.endpointLabel,
    required this.occurrenceCount,
    required this.identicalResponseCount,
    required this.withinShortWindowCount,
    required this.shortWindowSeconds,
  });

  final String endpointLabel;

  /// How many requests share the same method + URL + query + body.
  final int occurrenceCount;

  /// Of those, how many returned an identical response body.
  final int identicalResponseCount;

  /// Of those, how many occurred within [shortWindowSeconds] of another call
  /// to the same request signature.
  final int withinShortWindowCount;
  final int shortWindowSeconds;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'endpoint': endpointLabel,
        'occurrenceCount': occurrenceCount,
        'identicalResponseCount': identicalResponseCount,
        'withinShortWindowCount': withinShortWindowCount,
        'shortWindowSeconds': shortWindowSeconds,
      };
}
