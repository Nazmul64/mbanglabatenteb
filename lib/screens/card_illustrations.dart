import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────
//  Base Soft Circular Icon Badge Matching Website SVGs
// ─────────────────────────────────────────────────────
class CardIllustration extends StatelessWidget {
  final Widget child;

  const CardIllustration({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFCBD5E1).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  1. LEZIONI - Computer monitor with yellow play button
// ─────────────────────────────────────────────────────
class TutorialsIllustration extends StatelessWidget {
  const TutorialsIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.desktop_windows_rounded, size: 46, color: Color(0xFF4A90D9)),
          Positioned(
            child: Icon(Icons.play_circle_fill_rounded, size: 20, color: Color(0xFFFFD95A)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  2. TEST - White checklist document with pencil
// ─────────────────────────────────────────────────────
class TasbihIllustration extends StatelessWidget {
  const TasbihIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE0E9FF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A90D9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Icon(Icons.check_rounded, size: 7, color: Colors.white),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Container(height: 3, color: const Color(0xFFD0DDF5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Icon(Icons.check_rounded, size: 7, color: Colors.white),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Container(height: 3, color: const Color(0xFFD0DDF5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD95A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Container(height: 3, color: const Color(0xFFD0DDF5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: -2,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(
                width: 6,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD95A),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: const Color(0xFFFF9800), width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  3. ARGOMENTI - 3 Stacked Books with Graduation Cap
// ─────────────────────────────────────────────────────
class QuotesIllustration extends StatelessWidget {
  const QuotesIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top book (Yellow)
                Container(
                  width: 32,
                  height: 7,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD95A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 2),
                // Middle book (Blue)
                Container(
                  width: 38,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90D9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 2),
                // Bottom book (Red)
                Container(
                  width: 44,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          // Dark Navy Graduation Cap on top
          const Positioned(
            top: -1,
            child: Icon(Icons.school_rounded, size: 28, color: Color(0xFF2C3E7A)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  4. E-CLASS - E-Class Monitor + Red Phone
// ─────────────────────────────────────────────────────
class TextAnalyzerIllustration extends StatelessWidget {
  const TextAnalyzerIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Computer monitor
          Positioned(
            left: 2,
            child: Container(
              width: 34,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Container(
                  width: 28,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Center(
                    child: Text(
                      'E-CLASS',
                      style: TextStyle(
                        fontSize: 5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2C3E7A),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Mobile Phone
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 14,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  5. SFIDA - Golden Trophy Cup with Sparkles
// ─────────────────────────────────────────────────────
class SfidaIllustration extends StatelessWidget {
  const SfidaIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.emoji_events_rounded, size: 44, color: Color(0xFFFFD95A)),
          Positioned(
            top: 4,
            right: 6,
            child: Icon(Icons.star_rounded, size: 10, color: Color(0xFFFF6B6B)),
          ),
          Positioned(
            bottom: 6,
            left: 4,
            child: Icon(Icons.star_rounded, size: 8, color: Color(0xFF4A90D9)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  6. SCHEDA ESAME - Official Exam sheet with Gold Seal
// ─────────────────────────────────────────────────────
class QuizIllustration extends StatelessWidget {
  const QuizIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE0E9FF), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A90D9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  child: const Center(
                    child: Text(
                      'ESAME',
                      style: TextStyle(fontSize: 5.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(height: 3, color: const Color(0xFFE0E9FF)),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(height: 3, width: 20, color: const Color(0xFFE0E9FF)),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(height: 3, color: const Color(0xFFE0E9FF)),
                ),
              ],
            ),
          ),
          // Gold ribbon seal with checkmark at bottom right
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD95A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 11, color: Color(0xFFFF9800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  7. DIZIONARIO - Open Book with Magnifying Glass
// ─────────────────────────────────────────────────────
class DictionaryIllustration extends StatelessWidget {
  const DictionaryIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE0E9FF), width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 2.5, color: const Color(0xFFD0DDF5)),
                        const SizedBox(height: 2),
                        Container(height: 2.5, width: 12, color: const Color(0xFFE0E9FF)),
                        const SizedBox(height: 2),
                        Container(height: 2.5, color: const Color(0xFFD0DDF5)),
                      ],
                    ),
                  ),
                ),
                Container(width: 2, color: const Color(0xFF4A90D9)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 2.5, color: const Color(0xFFD0DDF5)),
                        const SizedBox(height: 2),
                        Container(height: 2.5, width: 10, color: const Color(0xFFE0E9FF)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: -2,
            child: Icon(Icons.search_rounded, size: 20, color: const Color(0xFFFFD95A)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  8. CARTELLI - Italian Traffic Signs (Triangle, STOP & Obbligo)
// ─────────────────────────────────────────────────────
class CartelliIllustration extends StatelessWidget {
  const CartelliIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Metallic sign pole
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB0BEC5), Color(0xFF78909C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 2. Bold Top Red Warning Triangle Sign (Pericolo)
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(36, 32),
              painter: const _TrafficTrianglePainter(),
            ),
          ),

          // 3. Crisp Red STOP Sign (Divieto)
          Positioned(
            bottom: 2,
            left: 1,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'STOP',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),

          // 4. Blue Mandatory Circle Sign (Obbligo)
          Positioned(
            bottom: 4,
            right: 1,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for authentic Italian Traffic Warning Triangle (Red border, white center, black exclamation mark)
class _TrafficTrianglePainter extends CustomPainter {
  const _TrafficTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer Red Triangle
    final outerPath = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final redPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;

    canvas.drawPath(outerPath, redPaint);

    // Inner White Triangle
    final innerPath = Path()
      ..moveTo(w / 2, 6)
      ..lineTo(w - 5, h - 3)
      ..lineTo(5, h - 3)
      ..close();

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawPath(innerPath, whitePaint);

    // Black Exclamation Mark inside triangle
    final blackPaint = Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.fill;

    // Exclamation stem
    final stemPath = Path()
      ..moveTo(w / 2 - 1.2, 11)
      ..lineTo(w / 2 + 1.2, 11)
      ..lineTo(w / 2 + 0.8, 20)
      ..lineTo(w / 2 - 0.8, 20)
      ..close();
    canvas.drawPath(stemPath, blackPaint);

    // Exclamation dot
    canvas.drawCircle(Offset(w / 2, 23.5), 1.2, blackPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────
//  9. SAVED MCQS - Bookmark Ribbon
// ─────────────────────────────────────────────────────
class SavedMcqsIllustration extends StatelessWidget {
  const SavedMcqsIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.bookmark_rounded, size: 44, color: Color(0xFF4A90D9)),
          Positioned(
            child: Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFD95A)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  10. CORRECT MCQS - Green Circle Checkmark Badge
// ─────────────────────────────────────────────────────
class CorrectMcqsIllustration extends StatelessWidget {
  const CorrectMcqsIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE8F9F0),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle_rounded, size: 42, color: Color(0xFF4CAF50)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  11. WRONG MCQS - Red Circle X Badge
// ─────────────────────────────────────────────────────
class WrongMcqsIllustration extends StatelessWidget {
  const WrongMcqsIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF0F0),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.cancel_rounded, size: 42, color: Color(0xFFFF6B6B)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  12. SUPPORT - Support Headset with Chat Bubble
// ─────────────────────────────────────────────────────
class SupportIllustration extends StatelessWidget {
  const SupportIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.headset_mic_rounded, size: 40, color: Color(0xFF4A90D9)),
          Positioned(
            right: 0,
            bottom: 2,
            child: Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFFFFD95A)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  13. TOP PERFORMERS - Gold Trophy with Star
// ─────────────────────────────────────────────────────
class TopPerformersIllustration extends StatelessWidget {
  const TopPerformersIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.emoji_events_rounded, size: 44, color: Color(0xFFF59E0B)),
          Positioned(
            top: 8,
            child: Icon(Icons.star_rounded, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  14. MANUALE - Blue Theory Manual Book
// ─────────────────────────────────────────────────────
class ManualeIllustration extends StatelessWidget {
  const ManualeIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 24,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Center(
                    child: Text('GUIDE', style: TextStyle(fontSize: 4.5, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 9, color: Color(0xFF10B981)),
                    SizedBox(width: 3),
                    Icon(Icons.cancel_rounded, size: 9, color: Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 6,
            bottom: 2,
            child: Container(width: 7, height: 12, color: const Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  15. PATENTE SOCIAL - Social Community App
// ─────────────────────────────────────────────────────
class PatenteSocialIllustration extends StatelessWidget {
  const PatenteSocialIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Container(
                width: 32,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFFEC4899)),
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF10B981)),
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFFEF4444)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  16. TRANSLATION - Globe Language Badge
// ─────────────────────────────────────────────────────
class TranslationIllustration extends StatelessWidget {
  const TranslationIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CardIllustration(
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          ),
        ),
        child: const Center(
          child: Text(
            'A文',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
