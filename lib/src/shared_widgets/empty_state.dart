import 'package:flutter/material.dart';
import 'package:requests_inspector/src/shared_widgets/inspector_theme.dart';

/// A centered, icon-led placeholder shown wherever a tab or panel has
/// nothing to display yet (no requests, no images, nothing selected).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    required this.isDarkMode,
  });

  final IconData icon;
  final String title;
  final String? message;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final messageColor = isDarkMode ? Colors.white38 : Colors.black38;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.0,
              height: 72.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: InspectorTheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32.0,
                color: InspectorTheme.primary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 18.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6.0),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: messageColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
