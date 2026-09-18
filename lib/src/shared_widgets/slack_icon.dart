import 'package:flutter/material.dart';

/// A small Slack-branded glyph (four rounded bars in Slack's brand colors),
/// used on the "Share" action instead of a generic share icon.
class SlackIcon extends StatelessWidget {
  const SlackIcon({super.key, this.size = 24.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SlackIconPainter()),
    );
  }
}

class _SlackIconPainter extends CustomPainter {
  static const _blue = Color(0xFF36C5F0);
  static const _green = Color(0xFF2EB67D);
  static const _yellow = Color(0xFFECB22E);
  static const _pink = Color(0xFFE01E5A);

  @override
  void paint(Canvas canvas, Size size) {
    final barLength = size.width * 0.42;
    final barThickness = size.width * 0.16;
    final radius = Radius.circular(barThickness / 2);

    void drawBar(Rect rect, Color color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = color,
      );
    }

    final w = size.width;
    final h = size.height;

    // Top-left vertical bar (green)
    drawBar(
      Rect.fromLTWH(
        w * 0.16,
        h * 0.06,
        barThickness,
        barLength,
      ),
      _green,
    );
    // Top-right horizontal bar (blue)
    drawBar(
      Rect.fromLTWH(
        w * 0.34,
        h * 0.16,
        barLength,
        barThickness,
      ),
      _blue,
    );
    // Bottom-right vertical bar (yellow)
    drawBar(
      Rect.fromLTWH(
        w * 0.68,
        h * 0.52,
        barThickness,
        barLength,
      ),
      _yellow,
    );
    // Bottom-left horizontal bar (pink)
    drawBar(
      Rect.fromLTWH(
        w * 0.16,
        h * 0.68,
        barLength,
        barThickness,
      ),
      _pink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
