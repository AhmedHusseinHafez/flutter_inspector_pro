import '../models/finding.dart';

/// Generic bundle returned by each sub-analyzer: the raw evidence items it
/// computed, plus any findings derived from them. Kept as a plain class
/// (rather than a Dart 3 record) so this module stays compatible with the
/// package's `>=2.17.0` SDK floor.
class AnalyzerOutput<T> {
  const AnalyzerOutput(this.items, this.findings);

  final List<T> items;
  final List<ApiIntelligenceFinding> findings;
}
