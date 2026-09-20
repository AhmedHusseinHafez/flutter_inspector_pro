import 'package:flutter/material.dart';

import '../persistence/log_export_format.dart';
import '../persistence/log_exporter.dart';
import '../persistence/log_file_store.dart';
import '../persistence/log_persistence_controller.dart';
import '../persistence/persisted_log_type.dart';
import 'inspector_theme.dart';
import 'log_storage_prompt_dialog.dart' show logTypeDescription;

/// The "Save logs to disk" screen behind the inspector's storage button: one
/// switch per log category, what each one currently occupies on disk, and the
/// export/share and clear actions.
class LogStorageDialog extends StatefulWidget {
  const LogStorageDialog({super.key, required this.isDarkMode});

  final bool isDarkMode;

  static Future<void> show(BuildContext context, {required bool isDarkMode}) {
    return showDialog<void>(
      context: context,
      builder: (context) => LogStorageDialog(isDarkMode: isDarkMode),
    );
  }

  @override
  State<LogStorageDialog> createState() => _LogStorageDialogState();
}

class _LogStorageDialogState extends State<LogStorageDialog> {
  final _controller = LogPersistenceController.instance;

  Map<PersistedLogType, PersistedLogStats> _stats = const {};
  LogExportFormat _format = LogExportFormat.csv;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final stats = await _controller.stats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  int get _totalEntries =>
      _stats.values.fold(0, (sum, stats) => sum + stats.entryCount);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Dialog(
      backgroundColor: InspectorTheme.surface(isDarkMode),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.save_alt_rounded,
                      color: InspectorTheme.primary),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Save logs to disk',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              Text(
                _controller.isReady
                    ? 'Pick which logs keep being written to this device, so '
                        'they survive app restarts.'
                    : 'Disk logging isn\'t available on this platform.',
                style: TextStyle(fontSize: 13.0, color: subtitleColor),
              ),
              const SizedBox(height: 16.0),
              ValueListenableBuilder<Set<PersistedLogType>>(
                valueListenable: _controller.enabledTypes,
                builder: (context, enabledTypes, _) => Column(
                  children: [
                    for (final type in PersistedLogType.values)
                      _buildTypeRow(
                        type: type,
                        isEnabled: enabledTypes.contains(type),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              _sectionLabel('Export', subtitleColor),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  for (final format in LogExportFormat.values) ...[
                    _formatChip(format),
                    const SizedBox(width: 8.0),
                  ],
                ],
              ),
              const SizedBox(height: 12.0),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: InspectorTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(InspectorTheme.radius),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  onPressed:
                      _isBusy || _totalEntries == 0 ? null : _exportAndShare,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 16.0,
                          height: 16.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded, size: 18.0),
                  label: Text('Export ${_format.label} & share'),
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                _totalEntries == 0
                    ? 'Nothing saved yet - switch on a category above and the '
                        'logs it records will show up here.'
                    : 'Exports all $_totalEntries saved entries as a single '
                        '${_format.label} file, then opens the share sheet - '
                        'email, Slack, Drive, Files, anything installed.',
                style: TextStyle(fontSize: 11.5, color: subtitleColor),
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: InspectorTheme.statusError,
                        side: BorderSide(
                            color: InspectorTheme.border(isDarkMode)),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(InspectorTheme.radius),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      onPressed:
                          _totalEntries == 0 ? null : _confirmClearSavedLogs,
                      child: const Text('Delete saved logs'),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            InspectorTheme.primary.withValues(alpha: 0.14),
                        foregroundColor: InspectorTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(InspectorTheme.radius),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeRow({
    required PersistedLogType type,
    required bool isEnabled,
  }) {
    final isDarkMode = widget.isDarkMode;
    final stats = _stats[type] ?? PersistedLogStats.empty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(InspectorTheme.radius),
          border: Border.all(
            color: isEnabled
                ? InspectorTheme.primary
                : InspectorTheme.border(isDarkMode),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    logTypeDescription(type),
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    stats.summary,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              activeThumbColor: Colors.white,
              activeTrackColor: InspectorTheme.primary,
              onChanged: _controller.isReady
                  ? (value) async {
                      await _controller.setTypeEnabled(type, value);
                      await _refreshStats();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatChip(LogExportFormat format) {
    final isDarkMode = widget.isDarkMode;
    final isSelected = _format == format;
    return GestureDetector(
      onTap: () => setState(() => _format = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? InspectorTheme.primary
              : InspectorTheme.surface(isDarkMode),
          borderRadius: BorderRadius.circular(InspectorTheme.radius),
          border: Border.all(
            color: isSelected
                ? InspectorTheme.primary
                : InspectorTheme.border(isDarkMode),
          ),
        ),
        child: Text(
          format.label,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Text(
        text,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.4,
        ),
      );

  Future<void> _exportAndShare() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    setState(() => _isBusy = true);
    LogExportResult? result;
    Object? error;
    try {
      result = await LogExporter.exportAndShare(
        format: _format,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    setState(() => _isBusy = false);

    final message = error != null
        ? 'Export failed: $error'
        : result == null
            ? 'Disk logging isn\'t available on this platform.'
            : 'Exported ${result.entryCount} '
                '${result.entryCount == 1 ? 'entry' : 'entries'} '
                'to ${result.fileName}';
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Deleting is irreversible (the files are removed, not just hidden), so it
  /// asks first - same as the inspector's own "Clear All".
  Future<void> _confirmClearSavedLogs() async {
    final isDarkMode = widget.isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: InspectorTheme.surface(isDarkMode),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Text(
          'Delete saved logs?',
          style: TextStyle(
            fontSize: 17.0,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'This permanently removes all $_totalEntries saved '
          '${_totalEntries == 1 ? 'entry' : 'entries'} from this device. '
          'Export them first if you still need them.',
          style: TextStyle(
            fontSize: 13.0,
            color: isDarkMode ? Colors.white54 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: InspectorTheme.statusError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _controller.clear();
    await _refreshStats();
  }
}
