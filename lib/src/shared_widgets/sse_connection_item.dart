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
    final borderColor = isSelected
        ? InspectorTheme.primary
        : InspectorTheme.border(isDarkMode);

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
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _SseChip(),
                        const SizedBox(width: 6.0),
                        _SseStatusChip(connection: connection),
                      ],
                    ),
                    const SizedBox(height: 6.0),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _SseChip extends StatelessWidget {
  const _SseChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: InspectorTheme.sse,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: const Text(
        'SSE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SseStatusChip extends StatelessWidget {
  const _SseStatusChip({required this.connection});

  final SseConnectionLog connection;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (connection.hasError) {
      color = InspectorTheme.statusError;
      label = 'ERROR';
    } else if (connection.isClosed) {
      color = Colors.grey;
      label = 'CLOSED';
    } else {
      color = InspectorTheme.statusOk;
      label = 'LIVE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
