import 'package:flutter/material.dart';

import '../sse/sse_log_controller.dart';

class SseConnectionDetailsPage extends StatelessWidget {
  const SseConnectionDetailsPage({
    super.key,
    required this.connection,
    required this.isDarkMode,
  });

  final SseConnectionLog connection;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final logTextColor = isDarkMode ? Colors.white70 : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 4.0),
            child: Text(
              connection.url,
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              '${connection.lines.length} event'
              '${connection.lines.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12.0, color: subtitleColor),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: connection.lines.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  connection.lines[index],
                  style: TextStyle(
                    color: logTextColor,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
