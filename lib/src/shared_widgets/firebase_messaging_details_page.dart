import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../enums/firebase_messaging_event_type_enum.dart';
import '../firebase_messaging/firebase_messaging_event.dart';
import '../helpers/inspector_helper.dart';
import 'inspector_theme.dart';

class FirebaseMessagingDetailsPage extends StatelessWidget {
  const FirebaseMessagingDetailsPage({
    super.key,
    required this.event,
    required this.isDarkMode,
  });

  final FirebaseMessagingEvent event;
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
                  color: InspectorTheme.firebaseMessaging,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  event.type.label,
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
            event.displayTitle,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8.0),
          _buildMetadataSection(context, textColor, subtitleColor),
          if (event.hasNotification) ...[
            const SizedBox(height: 16.0),
            _sectionLabel('Notification', subtitleColor),
            const SizedBox(height: 8.0),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event.notificationTitle != null)
                    _keyValueRow('Title', event.notificationTitle!, textColor,
                        subtitleColor),
                  if (event.notificationBody != null)
                    _keyValueRow('Body', event.notificationBody!, textColor,
                        subtitleColor),
                ],
              ),
            ),
          ],
          if (event.android != null) ...[
            const SizedBox(height: 16.0),
            _sectionLabel('Android notification', subtitleColor),
            const SizedBox(height: 8.0),
            _buildJsonCard(context, event.androidPretty, textColor),
          ],
          if (event.apple != null) ...[
            const SizedBox(height: 16.0),
            _sectionLabel('Apple/APNs notification', subtitleColor),
            const SizedBox(height: 8.0),
            _buildJsonCard(context, event.applePretty, textColor),
          ],
          if (event.data != null) ...[
            const SizedBox(height: 16.0),
            _sectionLabel('Data', subtitleColor),
            const SizedBox(height: 8.0),
            _buildJsonCard(context, event.dataPretty, textColor),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataSection(
    BuildContext context,
    Color textColor,
    Color subtitleColor,
  ) {
    final receivedAtText = InspectorHelper.extractTimeText(event.receivedAt);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _keyValueRow('Received at', receivedAtText, textColor, subtitleColor),
          if (event.sentTime != null)
            _keyValueRow(
                'Sent at', event.sentTime.toString(), textColor, subtitleColor),
          if (event.messageId != null)
            _keyValueRow(
                'Message ID', event.messageId!, textColor, subtitleColor),
          if (event.senderId != null)
            _keyValueRow(
                'Sender ID', event.senderId!, textColor, subtitleColor),
          if (event.from != null)
            _keyValueRow('From', event.from!, textColor, subtitleColor),
          if (event.messageType != null)
            _keyValueRow(
                'Message type', event.messageType!, textColor, subtitleColor),
          if (event.collapseKey != null)
            _keyValueRow(
                'Collapse key', event.collapseKey!, textColor, subtitleColor),
          if (event.ttl != null)
            _keyValueRow('TTL', '${event.ttl}', textColor, subtitleColor),
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

  Widget _buildJsonCard(
      BuildContext context, String prettyJson, Color textColor) {
    return _buildCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              prettyJson,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.0,
                color: textColor,
              ),
            ),
          ),
          InkWell(
            child: const Icon(Icons.copy, color: Colors.grey, size: 18.0),
            onTap: () {
              Clipboard.setData(ClipboardData(text: prettyJson));
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
