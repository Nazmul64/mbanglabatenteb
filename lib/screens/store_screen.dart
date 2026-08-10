import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'triangle_pattern_painter.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _loadingComplete = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Auto complete loading simulation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _loadingComplete = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pbk Online Store'),
        backgroundColor: isDark ? const Color(0xFF121829) : Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background triangles
          Positioned.fill(
            child: CustomPaint(
              painter: TrianglePatternPainter(
                triangleColor: isDark
                    ? Colors.white.withOpacity(0.015)
                    : Colors.blue.withOpacity(0.03),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: _loadingComplete
                  ? _buildPremiumStoreLayout(isDark)
                  : _buildItalianSpinnerLoader(isDark),
            ),
          ),
        ],
      ),
    );
  }

  // --- Italian flag styled circular spinner loader ---
  Widget _buildItalianSpinnerLoader(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(150, 150),
                    painter: _ItalianFlagSpinnerPainter(),
                  ),
                );
              },
            ),
            Container(
              width: 100,
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E294B) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
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
        const SizedBox(height: 36),
        Text(
          'প্রিমিয়াম স্টোর লোড হচ্ছে...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white70 : Colors.indigo.shade900,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'অনুগ্রহ করে অপেক্ষা করুন ভাই',
          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // --- Store items layout ---
  Widget _buildPremiumStoreLayout(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E294B).withOpacity(0.5) : Colors.indigo.shade50.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.indigo.shade100,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber,
                          blurRadius: 15,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'M Bangla Patente Premium',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'অভিনন্দন ভাই! আপনার অ্যাকাউন্টটি প্রিমিয়াম সংস্করণে অ্যাক্টিভেট করা আছে।',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.4, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'প্রিমিয়াম মেম্বারশিপের সুবিধাসমূহ:',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.2),
            ),
            const SizedBox(height: 16),

            // Features Grid/List
            _buildFeatureRow(Icons.check_circle_rounded, '৩০টি পূর্ণাঙ্গ মক এক্সাম সিমুলেশন টেস্ট', isDark),
            _buildFeatureRow(Icons.check_circle_rounded, 'সম্পূর্ণ বাংলা ডিক্টেশন ও প্রশ্ন ব্যাংক ব্যাখ্যা', isDark),
            _buildFeatureRow(Icons.check_circle_rounded, '২৪/৭ শিক্ষক ও লাইভ চ্যাট সাপোর্ট', isDark),
            _buildFeatureRow(Icons.check_circle_rounded, 'ইতালিয়ান-বাংলা হাই-ডেফিনিশন ভিজ্যুয়াল অভিধান', isDark),
            _buildFeatureRow(Icons.check_circle_rounded, 'অধ্যায় ভিত্তিক ভিডিও লেকচার ক্লাস হ্যান্ডনোট', isDark),
            
            const SizedBox(height: 36),

            // Pricing Plans Row
            const Text(
              'অন্যান্য প্রিমিয়াম সাবস্ক্রিপশন প্ল্যান:',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.2),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildPlanCard('১ মাস (Basic)', '€19.99', false, isDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildPlanCard('১২ মাস (Best)', '€99.99', true, isDark),
                ),
              ],
            ),
            const SizedBox(height: 36),

            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('ড্যাশবোর্ডে ফিরে যান', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String title, String price, bool isPopular, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E294B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular 
              ? Colors.amber 
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300),
          width: isPopular ? 2.5 : 1.2,
        ),
        boxShadow: [
          if (isPopular)
            BoxShadow(
              color: Colors.amber.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
            ),
        ],
      ),
      child: Column(
        children: [
          if (isPopular) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'RECOMMENDED',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            'সক্রিয় করুন',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPopular ? Colors.amber : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItalianFlagSpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 8.0;
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    // Green Arc (Left)
    final greenPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 5 * math.pi / 6, 2 * math.pi / 3, false, greenPaint);

    // White Arc (Top)
    final whitePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi / 6, 2 * math.pi / 3, false, whitePaint);

    // Red Arc (Right)
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
