import 'package:flutter/material.dart';
import 'package:requests_inspector/requests_inspector.dart';

import 'inspector_theme.dart';
import 'severity_chip.dart';

/// Renders one [ApiIntelligenceFinding] in the §24 shape: endpoint,
/// observation, evidence, potential impact, suggested investigation.
class FindingCard extends StatelessWidget {
  const FindingCard({
    super.key,
    required this.finding,
    required this.isDarkMode,
    this.onEndpointTap,
  });

  final ApiIntelligenceFinding finding;
  final bool isDarkMode;
  final void Function(String endpoint)? onEndpointTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: InspectorTheme.surface(isDarkMode),
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
        border: Border.all(color: InspectorTheme.border(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SeverityChip(severity: finding.severity),
              const SizedBox(width: 8.0),
              if (finding.endpoint != null)
                Expanded(
                  child: InkWell(
                    onTap: onEndpointTap == null
                        ? null
                        : () => onEndpointTap!(finding.endpoint!),
                    child: Text(
                      finding.endpoint!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: onEndpointTap == null
                            ? textColor
                            : InspectorTheme.primary,
                        decoration: onEndpointTap == null
                            ? TextDecoration.none
                            : TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            finding.observation,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (finding.evidence.isNotEmpty) ...[
            const SizedBox(height: 6.0),
            ...finding.evidence.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  '• $e',
                  style: TextStyle(fontSize: 12.0, color: subtitleColor),
                ),
              ),
            ),
          ],
          if (finding.potentialImpact != null) ...[
            const SizedBox(height: 6.0),
            Text(
              'Potential impact: ${finding.potentialImpact}',
              style: TextStyle(fontSize: 12.0, color: subtitleColor),
            ),
          ],
          if (finding.suggestedInvestigation != null) ...[
            const SizedBox(height: 4.0),
            Text(
              'Suggested investigation: ${finding.suggestedInvestigation}',
              style: TextStyle(
                fontSize: 12.0,
                color: subtitleColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
