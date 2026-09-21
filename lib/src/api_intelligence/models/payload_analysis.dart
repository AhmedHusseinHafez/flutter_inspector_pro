/// Size/structure classification shared by payload size (spec §8) and
/// response structural complexity (spec §19). Describes the observed data;
/// it does not by itself mean "problem".
enum PayloadClass { normal, moderate, heavy, veryHeavy }

extension PayloadClassLabel on PayloadClass {
  String get label {
    switch (this) {
      case PayloadClass.normal:
        return 'Normal';
      case PayloadClass.moderate:
        return 'Moderate';
      case PayloadClass.heavy:
        return 'Heavy';
      case PayloadClass.veryHeavy:
        return 'Very Heavy';
    }
  }
}

/// Payload size classification for one endpoint's responses (spec §8).
class PayloadAnalysis {
  const PayloadAnalysis({
    required this.endpointLabel,
    required this.averageBytes,
    required this.maxBytes,
    required this.sizeClass,
  });

  final String endpointLabel;
  final double averageBytes;
  final int maxBytes;
  final PayloadClass sizeClass;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'endpoint': endpointLabel,
        'averageBytes': averageBytes.round(),
        'maxBytes': maxBytes,
        'sizeClass': sizeClass.label,
      };

  /// Thresholds are in bytes; deliberately conservative for typical mobile
  /// JSON API responses. Not a hard "correct" answer - a documented,
  /// consistent yardstick so responses can be compared to each other.
  static PayloadClass classify(int bytes) {
    if (bytes < 20 * 1024) return PayloadClass.normal;
    if (bytes < 100 * 1024) return PayloadClass.moderate;
    if (bytes < 500 * 1024) return PayloadClass.heavy;
    return PayloadClass.veryHeavy;
  }
}
