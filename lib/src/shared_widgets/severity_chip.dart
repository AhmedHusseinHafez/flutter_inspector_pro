import 'package:flutter/material.dart';
import 'package:requests_inspector/requests_inspector.dart';

import 'inspector_theme.dart';

class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.severity});

  final FindingSeverity severity;

  Color get _color {
    switch (severity) {
      case FindingSeverity.healthy:
        return InspectorTheme.severityHealthy;
      case FindingSeverity.watch:
        return InspectorTheme.severityWatch;
      case FindingSeverity.optimizationCandidate:
        return InspectorTheme.severityOptimizationCandidate;
      case FindingSeverity.highPriorityInvestigation:
        return InspectorTheme.severityHighPriority;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        severity.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
