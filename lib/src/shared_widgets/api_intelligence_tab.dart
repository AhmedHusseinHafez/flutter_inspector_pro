import 'package:flutter/material.dart';
import 'package:requests_inspector/requests_inspector.dart';

import 'empty_state.dart';
import 'finding_card.dart';
import 'inspector_theme.dart';

/// The "API Intelligence" inspector tab (spec §1/§25): an on-demand,
/// evidence-based analysis of the network telemetry captured so far.
/// Analysis never runs automatically - it is always triggered by the
/// "Analyze Network" button.
class ApiIntelligenceTab extends StatelessWidget {
  const ApiIntelligenceTab({super.key, required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListenableBuilder(
        listenable: ApiIntelligenceController.instance,
        builder: (context, _) {
          final controller = ApiIntelligenceController.instance;
          final requests = InspectorController().requestsList;

          if (requests.isEmpty && controller.result == null) {
            return EmptyState(
              icon: Icons.insights_outlined,
              title: 'No network data available.',
              message: 'Use the application to capture network activity, '
                  'then run the analysis.',
              isDarkMode: isDarkMode,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12.0),
            children: [
              _buildAnalyzeBar(context, controller, requests.length),
              const SizedBox(height: 12.0),
              if (controller.state == ApiIntelligenceState.failed &&
                  controller.aiError != null)
                _buildErrorBanner(controller.aiError!),
              if (controller.result != null) ...[
                _buildSessionOverview(controller.result!),
                const SizedBox(height: 12.0),
                _buildAiSection(controller),
                const SizedBox(height: 12.0),
                ..._buildFindingSections(context, controller.result!),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnalyzeBar(
    BuildContext context,
    ApiIntelligenceController controller,
    int requestCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: InspectorTheme.surface(isDarkMode),
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
        border: Border.all(color: InspectorTheme.border(isDarkMode)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$requestCount HTTP request(s) captured in this session.',
              style: TextStyle(
                fontSize: 12.5,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          FilledButton.icon(
            onPressed: controller.isAnalyzing || requestCount == 0
                ? null
                : () => controller.analyze(InspectorController().requestsList),
            icon: controller.isAnalyzing
                ? const SizedBox(
                    width: 14.0,
                    height: 14.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 18.0),
            label: Text(controller.isAnalyzing ? 'Analyzing...' : 'Analyze Network'),
            style: FilledButton.styleFrom(
              backgroundColor: InspectorTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: InspectorTheme.statusError.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12.5, color: InspectorTheme.statusError),
      ),
    );
  }

  Widget _buildSessionOverview(ApiIntelligenceAnalysisResult result) {
    final session = result.session;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    final lines = <String>[
      '${session.requestCount} network requests',
      '${session.uniqueEndpointCount} unique endpoints',
      '${_formatBytes(session.totalResponseBytes)} total response data',
      '${result.duplicateGroups.length} potential duplicate request group(s)',
      '${session.failedRequestCount} failed request(s)',
      if (!result.hasTimingPhaseData)
        'Timing analysis is based on total request duration only - detailed '
            'phase timing (DNS/TLS/TTFB) was not available.',
    ];

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: InspectorTheme.surface(isDarkMode),
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
        border: Border.all(color: InspectorTheme.border(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Overview',
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6.0),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                line,
                style: TextStyle(fontSize: 12.0, color: subtitleColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiSection(ApiIntelligenceController controller) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    String body;
    if (controller.aiReport != null) {
      body = controller.aiReport!;
    } else if (controller.aiError != null) {
      body = 'Local network analysis completed.\n\n${controller.aiError}';
    } else if (!controller.hasAiProvider) {
      body = 'Local network analysis completed.\n\n'
          'AI interpretation is unavailable.';
    } else {
      body = 'Local network analysis completed.\n\n'
          'Waiting for AI interpretation...';
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: InspectorTheme.surface(isDarkMode),
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
        border: Border.all(color: InspectorTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16.0, color: InspectorTheme.primary),
              const SizedBox(width: 6.0),
              Text(
                'AI Interpretation',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          SelectableText(
            body,
            style: TextStyle(fontSize: 12.5, color: textColor, height: 1.4),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFindingSections(
    BuildContext context,
    ApiIntelligenceAnalysisResult result,
  ) {
    final sections = <Widget>[];
    for (final category in ApiIntelligenceCategory.values) {
      final findings = result.findingsOf(category);
      if (findings.isEmpty) continue;

      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
          child: Text(
            category.label,
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDarkMode ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
      );
      for (final finding in findings) {
        sections.add(
          FindingCard(
            finding: finding,
            isDarkMode: isDarkMode,
            onEndpointTap: finding.endpoint == null
                ? null
                : (endpoint) => _jumpToEndpoint(endpoint),
          ),
        );
      }
    }
    return sections;
  }

  void _jumpToEndpoint(String endpointLabel) {
    final parts = endpointLabel.split(' ');
    if (parts.length < 2) return;
    final methodName = parts.first;
    final path = parts.sublist(1).join(' ');

    final controller = InspectorController();
    controller.setItemTypeFilter(ItemTypeFilter.http);
    final method = RequestMethod.values
        .where((m) => m.name == methodName)
        .cast<RequestMethod?>()
        .firstWhere((m) => m != null, orElse: () => null);
    controller.setRequestMethodFilter(method);
    controller.searchForRequests(path);
    controller.selectedTab = 0;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
