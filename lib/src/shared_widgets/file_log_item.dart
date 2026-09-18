import 'package:flutter/material.dart';

import '../file_request_details.dart';
import '../inspector_controller.dart';
import 'inspector_theme.dart';

class FileLogItemWidget extends StatelessWidget {
  const FileLogItemWidget({
    super.key,
    required this.details,
    required this.isDarkMode,
  });

  final FileRequestDetails details;
  final bool isDarkMode;

  bool get _isImage =>
      details.contentType?.toLowerCase().startsWith('image/') ?? false;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        details.isError ? InspectorTheme.statusError : InspectorTheme.statusOk;

    return Material(
      color: InspectorTheme.surface(isDarkMode),
      borderRadius: BorderRadius.circular(InspectorTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
        onTap: () => InspectorController().selectFile(details),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InspectorTheme.radius),
            border: Border.all(color: InspectorTheme.border(isDarkMode)),
          ),
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: _buildThumbnail(),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      details.isError
                          ? (details.error ?? 'HTTP ${details.statusCode}')
                          : '${details.contentType ?? 'file'} · ${_formatBytes(details.contentLength)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                details.statusCode?.toString() ?? 'Err',
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

  Widget _buildThumbnail() {
    if (details.isError) {
      return Container(
        width: 36.0,
        height: 36.0,
        color: InspectorTheme.statusError.withValues(alpha: 0.15),
        child: const Icon(
          Icons.error_outline,
          size: 18.0,
          color: InspectorTheme.statusError,
        ),
      );
    }

    if (_isImage) {
      return Image.network(
        details.url,
        width: 36.0,
        height: 36.0,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 36.0,
          height: 36.0,
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      );
    }

    return Container(
      width: 36.0,
      height: 36.0,
      color: Colors.grey.withValues(alpha: 0.2),
      child: Icon(
        FileTypeIcon.forContentType(details.contentType),
        size: 18.0,
        color: isDarkMode ? Colors.white70 : Colors.black54,
      ),
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Picks a representative icon for a file's `Content-Type`, since not every
/// file (video, PDF, font, archive, ...) can be shown as a thumbnail.
class FileTypeIcon {
  FileTypeIcon._();

  static IconData forContentType(String? contentType) {
    final type = contentType?.toLowerCase() ?? '';
    if (type.startsWith('video/')) return Icons.videocam_outlined;
    if (type.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (type.startsWith('font/') || type.contains('font')) {
      return Icons.text_fields_outlined;
    }
    if (type.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (type.contains('zip') ||
        type.contains('tar') ||
        type.contains('gzip') ||
        type.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }
    if (type.startsWith('text/')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }
}
