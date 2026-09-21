import 'ai/api_intelligence_ai_provider.dart';
import 'ai/gemini_api_intelligence_ai_provider.dart';

/// Configuration for the API Intelligence tab, passed to [RequestsInspector].
/// Deterministic analysis always runs regardless of this config - AI
/// interpretation is only attempted when either [geminiApiKey] or
/// [aiProvider] is set.
///
/// The easiest way to turn AI interpretation on is to paste a Gemini API key:
///
/// ```dart
/// RequestsInspector(
///   apiIntelligence: ApiIntelligenceConfig(geminiApiKey: 'YOUR_GEMINI_API_KEY'),
///   ...
/// )
/// ```
///
/// For a custom backend/LLM instead of Gemini directly, pass [aiProvider]
/// (your own [ApiIntelligenceAiProvider] implementation) instead of
/// [geminiApiKey].
class ApiIntelligenceConfig {
  ApiIntelligenceConfig({
    ApiIntelligenceAiProvider? aiProvider,
    String? geminiApiKey,
    String geminiModel = 'gemini-2.0-flash',
  })  : assert(
          aiProvider == null || geminiApiKey == null,
          'Pass either aiProvider or geminiApiKey, not both.',
        ),
        aiProvider = aiProvider ??
            (geminiApiKey == null
                ? null
                : GeminiApiIntelligenceAiProvider(
                    apiKey: geminiApiKey,
                    model: geminiModel,
                  ));

  /// The AI interpretation layer actually used - either what you passed in
  /// directly, or a [GeminiApiIntelligenceAiProvider] built from
  /// [geminiApiKey]. Null means deterministic-only analysis (spec §26).
  final ApiIntelligenceAiProvider? aiProvider;
}
