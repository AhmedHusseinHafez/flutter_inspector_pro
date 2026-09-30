import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../developer_log/developer_log_entry.dart';
import '../helpers/inspector_helper.dart';
import 'inspector_theme.dart';

class DeveloperLogDetailsPage extends StatelessWidget {
  const DeveloperLogDetailsPage({
    super.key,
    required this.entry,
    required this.isDarkMode,
  });

  final DeveloperLogEntry entry;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

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
                  color: InspectorTheme.colorForLogLevel(entry.level),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  entry.level.label,
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
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _keyValueRow(
                  'Logged at',
                  InspectorHelper.extractTimeText(entry.time),
                  textColor,
                  subtitleColor,
                ),
                if (entry.tag != null)
                  _keyValueRow('Tag', entry.tag!, textColor, subtitleColor),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          _sectionLabel('Message', subtitleColor),
          const SizedBox(height: 8.0),
          _buildTextCard(context, entry.message, textColor, monospace: false),
          if (entry.data != null) ...[
            const SizedBox(height: 16.0),
            _sectionLabel('Data', subtitleColor),
            const SizedBox(height: 8.0),
            _buildTextCard(context, entry.dataPretty, textColor),
          ],
          if (entry.error != null) ...[
            const SizedBox(height: 16.0),
            _sectionLabel('Error', subtitleColor),
            const SizedBox(height: 8.0),
            _buildTextCard(context, '${entry.error}', textColor),
          ],
          if (entry.stackTrace != null) ...[
            const SizedBox(height: 16.0),
            _sectionLabel('Stack trace', subtitleColor),
            const SizedBox(height: 8.0),
            _buildTextCard(context, '${entry.stackTrace}', textColor),
          ],
        ],
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

  Widget _buildTextCard(
    BuildContext context,
    String text,
    Color textColor, {
    bool monospace = true,
  }) {
    return _buildCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                fontFamily: monospace ? 'monospace' : null,
                fontSize: monospace ? 12.0 : 13.0,
                color: textColor,
              ),
            ),
          ),
          InkWell(
            child: const Icon(Icons.copy, color: Colors.grey, size: 18.0),
            onTap: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
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
}
