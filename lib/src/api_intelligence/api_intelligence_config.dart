import 'ai/api_intelligence_ai_provider.dart';

/// Configuration for the API Intelligence tab, passed to [RequestsInspector].
/// Deterministic analysis always runs regardless of this config; [aiProvider]
/// only controls whether an AI interpretation layer is also attempted.
class ApiIntelligenceConfig {
  const ApiIntelligenceConfig({this.aiProvider});

  /// Optional host-app-implemented AI interpretation layer. Leave null to
  /// ship deterministic-only analysis (spec §26).
  final ApiIntelligenceAiProvider? aiProvider;
}
