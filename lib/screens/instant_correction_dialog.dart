import 'package:flutter/material.dart';

class InstantCorrectionDialog extends StatefulWidget {
  final ValueChanged<bool> onSelection; // true: Yes, false: No

  const InstantCorrectionDialog({
    super.key,
    required this.onSelection,
  });

  @override
  State<InstantCorrectionDialog> createState() => _InstantCorrectionDialogState();
}

class _InstantCorrectionDialogState extends State<InstantCorrectionDialog> {
  bool _disableTranslations = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E294B) : Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title matching Screenshot 2
            Text(
              'Vuoi la correzione istantanea\ndurante il test?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.3,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Do you want immediate correct answer during test?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // Disabilita Traduzioni ? Toggle Switch Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Disabilita Traduzioni ?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Switch(
                    value: _disableTranslations,
                    activeColor: const Color(0xFF22C55E),
                    onChanged: (val) {
                      setState(() {
                        _disableTranslations = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Buttons Row: No & Sì matching Screenshot 2
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSelection(false);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSelection(true);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Sì', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
