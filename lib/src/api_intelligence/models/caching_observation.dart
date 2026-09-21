/// Caching-header evidence for one endpoint (spec §7).
class CachingObservation {
  const CachingObservation({
    required this.endpointLabel,
    required this.callCount,
    required this.hasCacheControl,
    required this.hasETag,
    required this.hasLastModified,
    required this.hasExpires,
    required this.responsesLookStable,
  });

  final String endpointLabel;
  final int callCount;
  final bool hasCacheControl;
  final bool hasETag;
  final bool hasLastModified;
  final bool hasExpires;

  /// True when repeated calls to this endpoint returned byte-identical
  /// response bodies.
  final bool responsesLookStable;

  bool get hasAnyCachingHeader =>
      hasCacheControl || hasETag || hasLastModified || hasExpires;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'endpoint': endpointLabel,
        'callCount': callCount,
        'hasCacheControl': hasCacheControl,
        'hasETag': hasETag,
        'hasLastModified': hasLastModified,
        'hasExpires': hasExpires,
        'responsesLookStable': responsesLookStable,
      };
}
