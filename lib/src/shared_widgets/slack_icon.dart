import 'package:flutter/material.dart';

/// The Slack logo, used on the "Share" action instead of a generic share icon.
///
/// This is drawn with a [CustomPainter] instead of loaded from a bundled PNG
/// so it always renders in consuming apps, regardless of how they bundle
/// (or fail to bundle) this package's asset files.
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
  static const Color _blue = Color(0xFF36C5F0);
  static const Color _green = Color(0xFF2EB67D);
  static const Color _yellow = Color(0xFFECB22E);
  static const Color _pink = Color(0xFFE01E5A);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()..style = PaintingStyle.fill;

    // Blue: top-left bar + blob.
    paint.color = _blue;
    canvas.drawRRect(
      _pill(const Rect.fromLTRB(4, 27, 48, 48)),
      paint,
    );
    canvas.drawRRect(
      _blob(const Rect.fromLTRB(27, 2, 48, 23), missingCorner: _Corner.bottomLeft),
      paint,
    );

    // Green: top-right bar + blob.
    paint.color = _green;
    canvas.drawRRect(
      _pill(const Rect.fromLTRB(52, 4, 73, 48)),
      paint,
    );
    canvas.drawRRect(
      _blob(const Rect.fromLTRB(77, 27, 98, 48), missingCorner: _Corner.topLeft),
      paint,
    );

    // Yellow: bottom-right bar + blob.
    paint.color = _yellow;
    canvas.drawRRect(
      _pill(const Rect.fromLTRB(52, 52, 96, 73)),
      paint,
    );
    canvas.drawRRect(
      _blob(const Rect.fromLTRB(52, 77, 73, 98), missingCorner: _Corner.topRight),
      paint,
    );

    // Pink: bottom-left bar + blob.
    paint.color = _pink;
    canvas.drawRRect(
      _pill(const Rect.fromLTRB(27, 52, 48, 96)),
      paint,
    );
    canvas.drawRRect(
      _blob(const Rect.fromLTRB(4, 52, 25, 73), missingCorner: _Corner.bottomRight),
      paint,
    );

    canvas.restore();
  }

  /// A fully-rounded stadium/pill shape spanning [rect].
  RRect _pill(Rect rect) {
    final radius = Radius.circular(
      rect.shortestSide / 2,
    );
    return RRect.fromRectAndRadius(rect, radius);
  }

  /// A rounded-square "blob" with three rounded corners and one square
  /// corner (the [missingCorner]).
  RRect _blob(Rect rect, {required _Corner missingCorner}) {
    final radius = Radius.circular(rect.shortestSide / 2);
    const zero = Radius.zero;
    return RRect.fromRectAndCorners(
      rect,
      topLeft: missingCorner == _Corner.topLeft ? zero : radius,
      topRight: missingCorner == _Corner.topRight ? zero : radius,
      bottomLeft: missingCorner == _Corner.bottomLeft ? zero : radius,
      bottomRight: missingCorner == _Corner.bottomRight ? zero : radius,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }
