import 'package:flutter/material.dart';

import '../persistence/log_persistence_controller.dart';
import '../persistence/persisted_log_type.dart';
import 'inspector_theme.dart';

/// The one-time "save logs to disk?" prompt, shown the first time the inspector
/// screen is opened (unless the app passed explicit
/// `LogPersistenceConfig.defaultTypes`, or turned `askOnFirstOpen` off).
///
/// Whatever is picked here - including "Not now" - is remembered, so the prompt
/// never reappears; the same switches stay available afterwards from the
/// inspector's storage button.
class LogStoragePromptDialog extends StatefulWidget {
  const LogStoragePromptDialog({super.key, required this.isDarkMode});

  final bool isDarkMode;

  /// Shows the prompt if disk logging is available and hasn't been answered
  /// yet. Returns immediately otherwise.
  static Future<void> showIfNeeded(
    BuildContext context, {
    required bool isDarkMode,
  }) {
    final controller = LogPersistenceController.instance;
    if (!controller.isReady || !controller.shouldPromptOnOpen) {
      return Future<void>.value();
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LogStoragePromptDialog(isDarkMode: isDarkMode),
    );
  }

  @override
  State<LogStoragePromptDialog> createState() => _LogStoragePromptDialogState();
}

class _LogStoragePromptDialogState extends State<LogStoragePromptDialog> {
  late final Set<PersistedLogType> _selected = {
    ...LogPersistenceController.instance.config.defaultTypes,
  };

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Dialog(
      backgroundColor: InspectorTheme.surface(isDarkMode),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44.0,
              height: 44.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: InspectorTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: const Icon(
                Icons.save_alt_rounded,
                color: InspectorTheme.primary,
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              'Save logs to disk?',
              style: TextStyle(
                fontSize: 17.0,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Logs are kept in memory only and disappear when the app '
              'restarts. Pick the ones worth keeping on disk - you can export '
              'them as a CSV and share them later.',
              style: TextStyle(fontSize: 13.0, color: subtitleColor),
            ),
            const SizedBox(height: 16.0),
            ...PersistedLogType.values.map(_buildTypeTile),
            const SizedBox(height: 20.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side:
                          BorderSide(color: InspectorTheme.border(isDarkMode)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(InspectorTheme.radius),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onPressed: () {
                      LogPersistenceController.instance.declinePrompt();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: InspectorTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(InspectorTheme.radius),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            LogPersistenceController.instance
                                .setEnabledTypes(_selected);
                            Navigator.of(context).pop();
                          },
                    child: const Text('Save selected'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTile(PersistedLogType type) {
    final isDarkMode = widget.isDarkMode;
    final isSelected = _selected.contains(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
        onTap: () => setState(() {
          if (isSelected) {
            _selected.remove(type);
          } else {
            _selected.add(type);
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InspectorTheme.radius),
            border: Border.all(
              color: isSelected
                  ? InspectorTheme.primary
                  : InspectorTheme.border(isDarkMode),
            ),
            color: isSelected
                ? InspectorTheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20.0,
                color: isSelected
                    ? InspectorTheme.primary
                    : (isDarkMode ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  logTypeDescription(type),
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Human-readable label for a log category, shared by the prompt and the
/// storage dialog.
String logTypeDescription(PersistedLogType type) {
  switch (type) {
    case PersistedLogType.http:
      return 'HTTP & GraphQL requests';
    case PersistedLogType.sse:
      return 'SSE / streaming logs';
    case PersistedLogType.firebaseMessaging:
      return 'Firebase Messaging events';
    case PersistedLogType.files:
      return 'File loads (images, PDFs, ...)';
    case PersistedLogType.developerLog:
      return 'Custom developer logs';
  }
}
