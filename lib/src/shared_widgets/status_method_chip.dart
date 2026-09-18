import 'package:flutter/material.dart';

import '../enums/requests_methods.dart';
import 'inspector_theme.dart';

class MethodChip extends StatelessWidget {
  const MethodChip({super.key, required this.method});

  final RequestMethod method;

  @override
  Widget build(BuildContext context) {
    final color = InspectorTheme.colorForMethod(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        method.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.statusCode});

  final int? statusCode;

  @override
  Widget build(BuildContext context) {
    final color = InspectorTheme.colorForStatusCode(statusCode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        statusCode?.toString() ?? 'Err',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
