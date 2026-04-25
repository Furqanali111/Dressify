import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class DashedRRectPainter extends CustomPainter {
  DashedRRectPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 8,
    this.gapLength = 6,
    this.radius = 20,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);

    final ui.PathMetrics metrics = path.computeMetrics();
    for (final ui.PathMetric m in metrics) {
      double distance = 0;
      while (distance < m.length) {
        final double next = distance + dashLength;
        canvas.drawPath(
          m.extractPath(distance, next.clamp(0, m.length)),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength ||
      old.radius != radius;
}
