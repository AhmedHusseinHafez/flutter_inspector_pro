/// Header hygiene evidence for one endpoint (spec §14): counts only, never
/// raw header values (those must go through the sanitizer before display).
class HeaderObservation {
  const HeaderObservation({
    required this.endpointLabel,
    required this.requestHeaderCount,
    required this.responseHeaderCount,
    required this.hasContentEncoding,
    required this.hasVary,
    required this.hasRetryAfter,
    required this.redirectCount,
  });

  final String endpointLabel;
  final int requestHeaderCount;
  final int responseHeaderCount;
  final bool hasContentEncoding;
  final bool hasVary;
  final bool hasRetryAfter;
  final int redirectCount;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'endpoint': endpointLabel,
        'requestHeaderCount': requestHeaderCount,
        'responseHeaderCount': responseHeaderCount,
        'hasContentEncoding': hasContentEncoding,
        'hasVary': hasVary,
        'hasRetryAfter': hasRetryAfter,
        'redirectCount': redirectCount,
      };
}
