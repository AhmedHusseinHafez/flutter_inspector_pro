/// Evidence for a request that was followed by an identical request shortly
/// after a failure (spec §13).
class RetryGroup {
  const RetryGroup({
    required this.endpointLabel,
    required this.attemptCount,
    required this.finalStatusCode,
    required this.succeededEventually,
    required this.firstAttempt,
    required this.lastAttempt,
  });

  final String endpointLabel;
  final int attemptCount;
  final int? finalStatusCode;
  final bool succeededEventually;
  final DateTime firstAttempt;
  final DateTime lastAttempt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'endpoint': endpointLabel,
        'attemptCount': attemptCount,
        'finalStatusCode': finalStatusCode,
        'succeededEventually': succeededEventually,
        'spanMs': lastAttempt.difference(firstAttempt).inMilliseconds,
      };
}
