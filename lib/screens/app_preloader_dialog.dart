import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppPreloaderDialog extends StatefulWidget {
  final String message;
  final String subMessage;

  const AppPreloaderDialog({
    super.key,
    this.message = 'লোড হচ্ছে...',
    this.subMessage = 'অনুগ্রহ করে অপেক্ষা করুন ভাই',
  });

  static Future<T?> show<T>(BuildContext context, {String message = 'লোড হচ্ছে...'}) async {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppPreloaderDialog(message: message),
    );
  }

  @override
  State<AppPreloaderDialog> createState() => _AppPreloaderDialogState();
}

class _AppPreloaderDialogState extends State<AppPreloaderDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _controller.value * 2 * math.pi,
                      child: CustomPaint(
                        size: const Size(130, 130),
                        painter: ItalianFlagSpinnerPainter(),
                      ),
                    );
                  },
                ),
                Container(
                  width: 90,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E294B) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'M',
                        style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold, height: 1.1),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'BANGLA',
                        style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, height: 1.1),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'PATENTE B',
                        style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold, height: 1.1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              widget.message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.indigo.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subMessage,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ItalianFlagSpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 7.0;
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    final greenPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 5 * math.pi / 6, 2 * math.pi / 3, false, greenPaint);

    final whitePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi / 6, 2 * math.pi / 3, false, whitePaint);

    final redPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 3 * math.pi / 2, 2 * math.pi / 3, false, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
