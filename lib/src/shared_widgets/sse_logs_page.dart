import 'package:flutter/material.dart';
import 'package:requests_inspector/src/sse/sse_log_controller.dart';

class SseLogsPage extends StatefulWidget {
  const SseLogsPage({super.key, required this.isDarkMode});

  final bool isDarkMode;

  @override
  State<SseLogsPage> createState() => _SseLogsPageState();
}

class _SseLogsPageState extends State<SseLogsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final emptyTextColor =
        widget.isDarkMode ? Colors.white38 : Colors.black38;
    final logTextColor = widget.isDarkMode ? Colors.white70 : Colors.black87;

    return Expanded(
      child: ValueListenableBuilder<List<String>>(
        valueListenable: SseLogController.logs,
        builder: (context, logs, _) {
          _scrollToBottom();
          if (logs.isEmpty) {
            return Center(
              child: Text(
                'No SSE events yet',
                style: TextStyle(color: emptyTextColor, fontSize: 14),
              ),
            );
          }
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: logs.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                logs[index],
                style: TextStyle(
                  color: logTextColor,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
