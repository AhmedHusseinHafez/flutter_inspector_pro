/// Evidence about whether a response appears to have used compression
/// (spec §15). Only populated when both the declared/transferred size and
/// the decoded body size are inferable from telemetry.
class CompressionObservation {
  const CompressionObservation({
    required this.endpointLabel,
    required this.contentEncoding,
    required this.decodedBytes,
    required this.declaredContentLength,
  });

  final String endpointLabel;

  /// Value of the `Content-Encoding` response header, if present.
  final String? contentEncoding;

  /// Size of the decoded (parsed) body, as re-encoded to JSON/UTF-8.
  final int decodedBytes;

  /// Value of the `Content-Length` response header, if present - this is
  /// the size actually transferred over the wire, which is smaller than
  /// [decodedBytes] when compression was used.
  final int? declaredContentLength;

  bool get isLikelyCompressed =>
      contentEncoding != null &&
      contentEncoding!.toLowerCase() != 'identity';

  double? get compressionRatio {
    if (declaredContentLength == null || declaredContentLength == 0) {
      return null;
    }
    return decodedBytes / declaredContentLength!;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'endpoint': endpointLabel,
        if (contentEncoding != null) 'contentEncoding': contentEncoding,
        'decodedBytes': decodedBytes,
        if (declaredContentLength != null)
          'declaredContentLength': declaredContentLength,
        if (compressionRatio != null)
          'compressionRatio': compressionRatio!.toStringAsFixed(2),
      };
}
