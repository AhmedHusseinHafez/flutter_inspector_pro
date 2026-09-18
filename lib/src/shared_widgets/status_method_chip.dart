import 'package:flutter/material.dart';

import '../enums/requests_methods.dart';
import 'inspector_theme.dart';

class MethodChip extends StatelessWidget {
  const MethodChip({super.key, required this.method});

  final RequestMethod method;

  static const Map<RequestMethod, Color> _colors = {
    RequestMethod.GET: InspectorTheme.methodGet,
    RequestMethod.POST: InspectorTheme.methodPost,
    RequestMethod.PUT: InspectorTheme.methodPut,
    RequestMethod.PATCH: InspectorTheme.methodPatch,
    RequestMethod.DELETE: InspectorTheme.methodDelete,
    RequestMethod.WS: InspectorTheme.methodWs,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[method] ?? Colors.grey;
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

  static Color _colorFor(int? statusCode) {
    if (statusCode == null) return InspectorTheme.statusError;
    if (statusCode > 399) return InspectorTheme.statusError;
    if (statusCode > 299) return InspectorTheme.statusRedirect;
    return InspectorTheme.statusOk;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(statusCode);
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
