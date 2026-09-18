import 'package:flutter/material.dart';

import '../enums/firebase_messaging_event_type_enum.dart';
import '../firebase_messaging/firebase_messaging_event.dart';
import '../helpers/inspector_helper.dart';
import 'inspector_theme.dart';

class FirebaseMessagingItemWidget extends StatelessWidget {
  const FirebaseMessagingItemWidget({
    super.key,
    required this.event,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  final FirebaseMessagingEvent event;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? InspectorTheme.primary : InspectorTheme.border(isDarkMode);

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
                  color: InspectorTheme.firebaseMessaging,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
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
                      event.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      event.type.label,
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
                InspectorHelper.extractTimeText(event.receivedAt),
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
}
