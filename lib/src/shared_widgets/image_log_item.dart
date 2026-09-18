import 'package:flutter/material.dart';

import '../image_request_details.dart';
import '../inspector_controller.dart';
import 'inspector_theme.dart';

class ImageLogItemWidget extends StatelessWidget {
  const ImageLogItemWidget({
    super.key,
    required this.details,
    required this.isDarkMode,
  });

  final ImageRequestDetails details;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        details.isError ? InspectorTheme.statusError : InspectorTheme.statusOk;

    return Material(
      color: InspectorTheme.surface(isDarkMode),
      borderRadius: BorderRadius.circular(InspectorTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
        onTap: () => InspectorController().selectImage(details),
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
                child: details.isError
                    ? Container(
                        width: 36.0,
                        height: 36.0,
                        color:
                            InspectorTheme.statusError.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 18.0,
                          color: InspectorTheme.statusError,
                        ),
                      )
                    : Image.network(
                        details.url,
                        width: 36.0,
                        height: 36.0,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 36.0,
                          height: 36.0,
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
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
                          : '${details.contentType ?? 'image'} · ${_formatBytes(details.contentLength)}',
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

  String _formatBytes(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}
