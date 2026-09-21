import 'payload_analysis.dart';

/// Structural complexity of a decoded JSON response, independent of raw byte
/// size (spec §19): object/array counts and nesting depth.
class ResponseComplexity {
  const ResponseComplexity({
    required this.objectCount,
    required this.arrayCount,
    required this.maxArrayLength,
    required this.maxNestingDepth,
    required this.complexityClass,
  });

  final int objectCount;
  final int arrayCount;
  final int maxArrayLength;
  final int maxNestingDepth;
  final PayloadClass complexityClass;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'objectCount': objectCount,
        'arrayCount': arrayCount,
        'maxArrayLength': maxArrayLength,
        'maxNestingDepth': maxNestingDepth,
        'complexityClass': complexityClass.label,
      };

  /// Walks a decoded JSON value and computes structural stats. Capped
  /// traversal (max nodes) so a pathological response can't make an
  /// on-demand analysis pass expensive.
  static ResponseComplexity? analyze(dynamic value, {int maxNodes = 20000}) {
    if (value == null) return null;
    if (value is! Map && value is! List) return null;

    var objectCount = 0;
    var arrayCount = 0;
    var maxArrayLength = 0;
    var maxDepth = 0;
    var visited = 0;

    void walk(dynamic node, int depth) {
      if (visited >= maxNodes) return;
      visited++;
      if (depth > maxDepth) maxDepth = depth;

      if (node is Map) {
        objectCount++;
        for (final v in node.values) {
          if (visited >= maxNodes) break;
          walk(v, depth + 1);
        }
      } else if (node is List) {
        arrayCount++;
        if (node.length > maxArrayLength) maxArrayLength = node.length;
        for (final v in node) {
          if (visited >= maxNodes) break;
          walk(v, depth + 1);
        }
      }
    }

    walk(value, 1);

    final complexityClass = _classify(
      objectCount: objectCount,
      arrayCount: arrayCount,
      maxArrayLength: maxArrayLength,
      maxDepth: maxDepth,
    );

    return ResponseComplexity(
      objectCount: objectCount,
      arrayCount: arrayCount,
      maxArrayLength: maxArrayLength,
      maxNestingDepth: maxDepth,
      complexityClass: complexityClass,
    );
  }

  static PayloadClass _classify({
    required int objectCount,
    required int arrayCount,
    required int maxArrayLength,
    required int maxDepth,
  }) {
    final nodeCount = objectCount + arrayCount;
    if (nodeCount < 25 && maxArrayLength < 50 && maxDepth <= 4) {
      return PayloadClass.normal;
    }
    if (nodeCount < 150 && maxArrayLength < 200 && maxDepth <= 6) {
      return PayloadClass.moderate;
    }
    if (nodeCount < 800 && maxArrayLength < 1000 && maxDepth <= 9) {
      return PayloadClass.heavy;
    }
    return PayloadClass.veryHeavy;
  }
}
