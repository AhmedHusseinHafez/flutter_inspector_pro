import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../file_request_details.dart';
import '../helpers/inspector_helper.dart';
import 'file_log_item.dart';
import 'inspector_theme.dart';

class FileRequestDetailsPage extends StatelessWidget {
  const FileRequestDetailsPage({
    super.key,
    required this.file,
    required this.isDarkMode,
  });

  final FileRequestDetails file;
  final bool isDarkMode;

  bool get _isImage =>
      file.contentType?.toLowerCase().startsWith('image/') ?? false;

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;
    final statusColor =
        file.isError ? InspectorTheme.statusError : InspectorTheme.statusOk;

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 96.0),
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  file.statusCode?.toString() ?? 'Error',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            file.url,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12.0),
          _buildPreview(),
          const SizedBox(height: 16.0),
          _buildMetadataSection(textColor, subtitleColor),
          if (file.isError) ...[
            const SizedBox(height: 16.0),
            _sectionLabel('Error', subtitleColor),
            const SizedBox(height: 8.0),
            _buildCard(
              child: SelectableText(
                file.error ?? 'HTTP ${file.statusCode}',
                style: TextStyle(
                  fontSize: 13.0,
                  color: InspectorTheme.statusError,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16.0),
          _buildCopyUrlButton(context),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (file.isError) {
      return _buildCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Icon(
              Icons.error_outline,
              size: 40.0,
              color: InspectorTheme.statusError.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    if (!_isImage) {
      return _buildCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Icon(
              FileTypeIcon.forContentType(file.contentType),
              size: 40.0,
              color: isDarkMode ? Colors.white54 : Colors.black45,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(InspectorTheme.radius),
      child: Container(
        width: double.infinity,
        color: InspectorTheme.surface(isDarkMode),
        constraints: const BoxConstraints(maxHeight: 260.0),
        child: Image.network(
          file.url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Icon(
              Icons.broken_image_outlined,
              size: 40.0,
              color: Colors.grey.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataSection(Color textColor, Color subtitleColor) {
    final sentTimeText = InspectorHelper.extractTimeText(file.sentTime);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _keyValueRow('Sent at', sentTimeText, textColor, subtitleColor),
          if (file.receivedTime != null) ...[
            _keyValueRow(
              'Received at',
              InspectorHelper.extractTimeText(file.receivedTime!),
              textColor,
              subtitleColor,
            ),
            _keyValueRow(
              'Duration',
              InspectorHelper.calculateDuration(
                  file.sentTime, file.receivedTime!),
              textColor,
              subtitleColor,
            ),
          ],
          if (file.contentType != null)
            _keyValueRow(
                'Content type', file.contentType!, textColor, subtitleColor),
          if (file.contentLength != null)
            _keyValueRow('Size', _formatBytes(file.contentLength!), textColor,
                subtitleColor),
        ],
      ),
    );
  }

  Widget _buildCopyUrlButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: file.url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL copied to clipboard')),
          );
        },
        icon: const Icon(Icons.copy, size: 16.0),
        label: const Text('Copy URL'),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: InspectorTheme.surface(isDarkMode),
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
        border: Border.all(color: InspectorTheme.border(isDarkMode)),
      ),
      child: child,
    );
  }

  Widget _keyValueRow(
    String key,
    String value,
    Color textColor,
    Color subtitleColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.0,
            child: Text(
              key,
              style: TextStyle(fontSize: 12.0, color: subtitleColor),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 13.0, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
