import 'package:flutter/material.dart';

import '../developer_log/developer_log_entry.dart';
import '../enums/developer_log_level_enum.dart';
import '../helpers/inspector_helper.dart';
import 'inspector_theme.dart';

class DeveloperLogItemWidget extends StatelessWidget {
  const DeveloperLogItemWidget({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  final DeveloperLogEntry entry;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? InspectorTheme.primary : InspectorTheme.border(isDarkMode);
    final levelColor = InspectorTheme.colorForLogLevel(entry.level);

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
                  color: levelColor,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Icon(
                  _iconForLevel(entry.level),
                  color: Colors.white,
                  size: 20.0,
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      entry.tag == null
                          ? entry.level.label
                          : '${entry.level.label} · ${entry.tag}',
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
                InspectorHelper.extractTimeText(entry.time),
                style: TextStyle(
                  fontSize: 11.0,
                  color: isDarkMode ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForLevel(DeveloperLogLevel level) {
    switch (level) {
      case DeveloperLogLevel.verbose:
      case DeveloperLogLevel.debug:
        return Icons.terminal_rounded;
      case DeveloperLogLevel.info:
        return Icons.info_outline_rounded;
      case DeveloperLogLevel.warning:
        return Icons.warning_amber_rounded;
      case DeveloperLogLevel.error:
        return Icons.error_outline_rounded;
    }
  }
}
