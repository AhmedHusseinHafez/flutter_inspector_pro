import 'package:flutter/material.dart';

import 'inspector_theme.dart';

class RunAgainButton extends StatefulWidget {
  const RunAgainButton({
    super.key,
    required this.onTap,
    required this.isDarkMode, // Pass isDarkMode directly
  });

  final Future<void> Function() onTap;
  final bool isDarkMode; // New parameter

  @override
  _RunAgainButtonState createState() => _RunAgainButtonState();
}

class _RunAgainButtonState extends State<RunAgainButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // No need for a Selector here, as isDarkMode is passed as a direct prop
    return _isLoading
        ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: InspectorTheme.primary,
              ),
            ),
          )
        : Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20.0),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                _setBusy();
                widget.onTap().whenComplete(_setReady);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: InspectorTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Run',
                      style: TextStyle(
                        color: InspectorTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.0,
                      ),
                    ),
                    Icon(
                      Icons.play_arrow_rounded,
                      color: InspectorTheme.primary,
                      size: 18.0,
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  void _setBusy() => setState(() => _isLoading = true);

  void _setReady() => setState(() => _isLoading = false);
}
