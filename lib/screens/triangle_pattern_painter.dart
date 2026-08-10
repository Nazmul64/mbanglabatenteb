import 'package:flutter/material.dart';

class TrianglePatternPainter extends CustomPainter {
  final Color triangleColor;

  TrianglePatternPainter({required this.triangleColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = triangleColor
      ..style = PaintingStyle.fill;

    // Dimensions for grid tiling
    const double spacingX = 50.0;
    const double spacingY = 45.0;
    const double triangleWidth = 14.0;
    const double triangleHeight = 12.0;

    int rowIndex = 0;
    for (double y = 0; y < size.height + spacingY; y += spacingY) {
      // Offset alternate rows for a beautiful staggered, honeycomb-like pattern
      double offsetX = (rowIndex % 2 == 0) ? 0.0 : spacingX / 2;
      for (double x = -spacingX; x < size.width + spacingX; x += spacingX) {
        final path = Path();
        
        // Coordinates for an upward-pointing triangle centered at (x + offsetX, y)
        double centerX = x + offsetX;
        double centerY = y;

        path.moveTo(centerX, centerY - triangleHeight / 2); // Top apex
        path.lineTo(centerX - triangleWidth / 2, centerY + triangleHeight / 2); // Bottom-left
        path.lineTo(centerX + triangleWidth / 2, centerY + triangleHeight / 2); // Bottom-right
        path.close();

        canvas.drawPath(path, paint);
      }
      rowIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant TrianglePatternPainter oldDelegate) {
    return oldDelegate.triangleColor != triangleColor;
  }
}
