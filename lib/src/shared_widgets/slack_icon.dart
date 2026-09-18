import 'package:flutter/material.dart';

/// The Slack logo, used on the "Share" action instead of a generic share icon.
class SlackIcon extends StatelessWidget {
  const SlackIcon({super.key, this.size = 24.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/slack_icon.png',
      package: 'requests_inspector',
      width: size,
      height: size,
    );
  }
}
