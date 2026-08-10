import 'package:flutter/material.dart';
import '../theme.dart';

class TasbihScreen extends StatefulWidget {
  final int count;
  final int target;
  final String currentDhikr;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<int> onTargetChanged;
  final ValueChanged<String> onDhikrChanged;

  final VoidCallback onReset;

  const TasbihScreen({
    super.key,
    required this.count,
    required this.target,
    required this.currentDhikr,
    required this.onCountChanged,
    required this.onTargetChanged,
    required this.onDhikrChanged,
    required this.onReset,
  });

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<String> _dhikrList = [
    'সুবহানাল্লাহ (Subhanallah)',
    'আলহামদুলিল্লাহ (Alhamdulillah)',
    'আল্লাহু আকবার (Allahu Akbar)',
    'লা ইলাহা ইল্লাল্লাহ (La ilaha illallah)',
    'আস্তাগফিরুল্লাহ (Astaghfirullah)',
    'সুবহানাল্লাহি ওয়া বিহামদিহি',
  ];

  final List<int> _targetsList = [33, 100, 1000];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _increment() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    if (widget.target > 0 && widget.count >= widget.target) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.currentDhikr.split(" ")[0]} জিকির সম্পূর্ণ হয়েছে! 🎉'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
      widget.onCountChanged(1);
    } else {
      widget.onCountChanged(widget.count + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double progress = widget.target > 0 ? (widget.count / widget.target).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Settings Cards
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E294B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Dhikr Selector
                  DropdownButtonFormField<String>(
                    value: widget.currentDhikr,
                    decoration: InputDecoration(
                      labelText: 'জিকির নির্বাচন করুন',
                      labelStyle: TextStyle(color: isDark ? Colors.cyan : Colors.blue, fontWeight: FontWeight.bold),
                      border: InputBorder.none,
                    ),
                    dropdownColor: isDark ? const Color(0xFF1E294B) : Colors.white,
                    items: _dhikrList.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) widget.onDhikrChanged(val);
                    },
                  ),
                  const Divider(height: 20),
                  // Target Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'লক্ষ্যমাত্রা:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Row(
                        children: [
                          ..._targetsList.map((targetVal) {
                            final isSelected = widget.target == targetVal;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text('$targetVal', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
                                selected: isSelected,
                                selectedColor: Colors.blue,
                                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                                onSelected: (selected) {
                                  if (selected) widget.onTargetChanged(targetVal);
                                },
                              ),
                            );
                          }),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text('অসীম', style: TextStyle(fontWeight: FontWeight.bold, color: widget.target == 0 ? Colors.white : Colors.grey)),
                              selected: widget.target == 0,
                              selectedColor: Colors.blue,
                              backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                              onSelected: (selected) {
                                if (selected) widget.onTargetChanged(0);
                              },
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Radial Progress and Tap Circle
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ring Glow
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: widget.target > 0 ? progress : 1.0,
                      strokeWidth: 8,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                      color: widget.target > 0 && widget.count >= widget.target
                          ? AppTheme.accentPink
                          : AppTheme.accentCyan,
                    ),
                  ),
                  // Inner Button
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: GestureDetector(
                      onTap: _increment,
                      child: Container(
                        width: 215,
                        height: 215,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.target > 0 && widget.count >= widget.target
                              ? AppTheme.sunsetGradient
                              : AppTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: (widget.target > 0 && widget.count >= widget.target
                                      ? AppTheme.accentPink
                                      : AppTheme.accentCyan)
                                  .withOpacity(0.35),
                              blurRadius: 25,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'জিকির সংখ্যা',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.count}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (widget.target > 0)
                              Text(
                                'লক্ষ্য: ${widget.target}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 45),

            // Controls Bottom Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reset Button
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDark ? const Color(0xFF1E294B) : Colors.white,
                        title: const Text('রিসেট নিশ্চিতকরণ', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('আপনি কি নিশ্চিত যে জিকির সংখ্যা শূন্য করতে চান?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('না', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              widget.onReset();
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'হ্যাঁ, রিসেট করুন',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('রিসেট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                
                // Info Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app_rounded, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'ট্যাপ করতে বৃত্তের মাঝে চাপুন',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
