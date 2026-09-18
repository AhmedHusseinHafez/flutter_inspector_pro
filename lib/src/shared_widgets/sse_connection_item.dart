import 'package:flutter/material.dart';

import '../sse/sse_log_controller.dart';
import 'inspector_theme.dart';

class SseConnectionItemWidget extends StatelessWidget {
  const SseConnectionItemWidget({
    super.key,
    required this.connection,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  final SseConnectionLog connection;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? InspectorTheme.primary : InspectorTheme.border(isDarkMode);

    final Color statusColor;
    final String statusLabel;
    if (connection.hasError) {
      statusColor = InspectorTheme.statusError;
      statusLabel = 'ERROR';
    } else if (connection.isClosed) {
      statusColor = Colors.grey;
      statusLabel = 'CLOSED';
    } else {
      statusColor = InspectorTheme.statusOk;
      statusLabel = 'LIVE';
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(InspectorTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: InspectorTheme.surface(isDarkMode),
            borderRadius: BorderRadius.circular(InspectorTheme.radius),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44.0,
                height: 36.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: InspectorTheme.sse,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: const Text(
                  'SSE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${connection.lines.length} event'
                      '${connection.lines.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
