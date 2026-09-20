import 'package:flutter/material.dart';

import '../firebase_messaging/firebase_messaging_inspector.dart';
import 'inspector_theme.dart';

/// The "Capture settings" screen behind the inspector's tune button: switches
/// for the log sources the inspector hooks into the running app, as opposed to
/// the [LogStorageDialog] switches, which only decide what gets written to
/// disk.
///
/// This exists so a capture source can be switched off from the device, with
/// no rebuild and no code change, when it turns out to interfere with the app
/// it's meant to be observing - and so the choice sticks across restarts,
/// since that interference usually shows up at launch.
class CaptureSettingsDialog extends StatelessWidget {
  const CaptureSettingsDialog({super.key, required this.isDarkMode});

  final bool isDarkMode;

  /// Whether there's anything to show. The dialog only offers sources the
  /// host app opted into, so it stays hidden for apps using none of them.
  static bool get hasAnySource => FirebaseMessagingInspector.isAvailable;

  static Future<void> show(BuildContext context, {required bool isDarkMode}) {
    return showDialog<void>(
      context: context,
      builder: (context) => CaptureSettingsDialog(isDarkMode: isDarkMode),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const Icon(Icons.tune_rounded,
                      color: InspectorTheme.primary),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Capture settings',
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
                'Switch off a source the inspector hooks into your app. '
                'Your choice is remembered after a restart.',
                style: TextStyle(fontSize: 13.0, color: subtitleColor),
              ),
              const SizedBox(height: 16.0),
              if (FirebaseMessagingInspector.isAvailable)
                _buildFirebaseRow(subtitleColor),
              const SizedBox(height: 16.0),
              SizedBox(
                width: double.infinity,
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
        ),
      ),
    );
  }

  Widget _buildFirebaseRow(Color subtitleColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: FirebaseMessagingInspector.isCapturing,
      builder: (context, isCapturing, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(InspectorTheme.radius),
          border: Border.all(
            color: isCapturing
                ? InspectorTheme.firebaseMessaging
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
                    'Firebase Messaging',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    isCapturing
                        ? 'Listening to onMessage. Switch off if push '
                            'notifications start misbehaving.'
                        : 'Off - FirebaseMessaging is not touched at all, '
                            'including on the next launch.',
                    style: TextStyle(fontSize: 11.5, color: subtitleColor),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isCapturing,
              activeThumbColor: InspectorTheme.firebaseMessaging,
              onChanged: FirebaseMessagingInspector.setEnabled,
            ),
          ],
        ),
      ),
    );
  }
}
