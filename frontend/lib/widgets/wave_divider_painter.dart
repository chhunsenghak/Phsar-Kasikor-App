import 'package:flutter/material.dart';

/// Traces the gentle S-curve used to cut a gradient hero band into the page
/// background beneath it — shared by every screen that reuses the hero
/// motif introduced on the login/register screens, scaled to whatever width
/// the hero ends up with.
class WaveDividerPainter extends CustomPainter {
  final Color color;
  const WaveDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(w * 0.19, h, w * 0.38, h, w * 0.5, h * 0.5)
      ..cubicTo(w * 0.62, 0, w * 0.81, 0, w, h * 0.65)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant WaveDividerPainter oldDelegate) => oldDelegate.color != color;
}
