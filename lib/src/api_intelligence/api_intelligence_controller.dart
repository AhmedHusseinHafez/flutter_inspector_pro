import 'package:flutter/foundation.dart';

import '../request_details.dart';
import 'ai/api_intelligence_ai_provider.dart';
import 'ai/api_intelligence_payload_builder.dart';
import 'analyzer/api_intelligence_analyzer.dart';
import 'models/analysis_result.dart';

enum ApiIntelligenceState { idle, analyzing, completed, failed }

/// Orchestrates on-demand API Intelligence analysis: always runs the
/// deterministic analyzer, then optionally hands the sanitized result to an
/// AI provider (spec §2/§26). Singleton, mirroring this package's other
/// static/singleton controllers (e.g. `LogPersistenceController.instance`).
class ApiIntelligenceController extends ChangeNotifier {
  ApiIntelligenceController._internal();

  static final ApiIntelligenceController instance =
      ApiIntelligenceController._internal();

  ApiIntelligenceAiProvider? aiProvider;

  final _payloadBuilder = const ApiIntelligencePayloadBuilder();

  ApiIntelligenceState _state = ApiIntelligenceState.idle;
  ApiIntelligenceAnalysisResult? _result;
  String? _aiReport;
  String? _aiError;

  ApiIntelligenceState get state => _state;
  ApiIntelligenceAnalysisResult? get result => _result;
  String? get aiReport => _aiReport;
  String? get aiError => _aiError;
  bool get isAnalyzing => _state == ApiIntelligenceState.analyzing;
  bool get hasAiProvider => aiProvider != null;

  /// Runs deterministic analysis over [requests], then (if an AI provider is
  /// configured) requests an interpretation of the sanitized result. Guards
  /// against overlapping runs so the "Analyze Network" action can't be
  /// double-triggered (spec §25).
  Future<void> analyze(List<RequestDetails> requests) async {
    if (isAnalyzing) return;

    _state = ApiIntelligenceState.analyzing;
    _aiReport = null;
    _aiError = null;
    notifyListeners();

    try {
      final result = ApiIntelligenceAnalyzer.analyze(requests);
      _result = result;
      _state = ApiIntelligenceState.completed;
      notifyListeners();

      final provider = aiProvider;
      if (provider != null) {
        try {
          final payload = _payloadBuilder.build(result);
          _aiReport = await provider.generateReport(payload);
        } catch (error) {
          // AI failure never discards the deterministic results already
          // shown (spec §26).
          _aiError = 'AI interpretation failed: $error';
        }
        notifyListeners();
      }
    } catch (error) {
      _state = ApiIntelligenceState.failed;
      _aiError = 'Analysis failed: $error';
      notifyListeners();
    }
  }

  /// Discards the current analysis result (e.g. after "Clear All" empties
  /// the captured requests it was based on). Does not touch [aiProvider].
  void clear() {
    if (isAnalyzing) return;
    _state = ApiIntelligenceState.idle;
    _result = null;
    _aiReport = null;
    _aiError = null;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    aiProvider = null;
    _state = ApiIntelligenceState.idle;
    _result = null;
    _aiReport = null;
    _aiError = null;
  }
}
