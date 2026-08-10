import 'package:flutter/material.dart';
import 'google_translate_dialog.dart';
import '../services/html_text_helper.dart';

class FullTranslateDialog extends StatelessWidget {
  final String italianText;
  final String banglaText;
  final String? imageUrl;

  const FullTranslateDialog({
    super.key,
    required this.italianText,
    required this.banglaText,
    this.imageUrl,
  });

  Widget _buildFormattedItalianText(BuildContext context, bool isDark) {
    final spans = HtmlTextHelper.buildParsedStatementSpans(
      statement: italianText,
      isDark: isDark,
      fontSize: 14.5,
      height: 1.45,
      onTapWord: (rawWord, cleanWord) {
        showDialog(
          context: context,
          builder: (context) => GoogleTranslateDialog(
            italianText: cleanWord.isNotEmpty ? cleanWord : rawWord,
            localTranslation: banglaText,
            imageUrl: imageUrl,
          ),
        );
      },
    );

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Italian Text with underlined clickable words
            _buildFormattedItalianText(context, isDark),
            const SizedBox(height: 14),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
            const SizedBox(height: 14),

            // 2. Bangla Translation Text
            Text(
              banglaText.replaceAll('<br>', '\n').replaceAll('<br/>', '\n'),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Control Row: Speaker Icon on Left, OK button on Right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: Colors.blue, size: 24),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('অডিও প্লে হচ্ছে...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
