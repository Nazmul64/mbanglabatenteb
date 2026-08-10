import 'package:flutter/material.dart';

class HtmlTextHelper {
  /// Strip all HTML tags from a text string (useful for TTS or plain text display)
  static String stripHtml(String text) {
    return text
        .replaceAll('<br>', ' ')
        .replaceAll('<br/>', ' ')
        .replaceAll('<br />', ' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  /// Parse text containing `<u>...</u>` (and other HTML tags) into InlineSpans.
  /// Words inside `<u>...</u>` receive a custom green underline decoration (bottom border).
  /// Words outside `<u>...</u>` display as clean normal text without any underline decoration.
  /// All raw HTML tags like `<u>` and `</u>` are completely parsed and hidden from view.
  static List<InlineSpan> buildParsedStatementSpans({
    required String statement,
    required bool isDark,
    required void Function(String word, String cleanWord) onTapWord,
    double fontSize = 15.0,
    double height = 1.5,
    Color? underlineColor,
    Color? textColor,
    FontWeight? normalFontWeight,
    FontWeight? underlinedFontWeight,
  }) {
    final List<InlineSpan> spans = [];
    final activeUnderlineColor = underlineColor ?? const Color(0xFF4CAF50);

    // 1. Clean line breaks
    final cleanText = statement
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n');

    // 2. Regex for <u>...</u> tags
    final regExp = RegExp(r'<u>(.*?)</u>', caseSensitive: false, dotAll: true);
    final matches = regExp.allMatches(cleanText);

    if (matches.isEmpty) {
      // No <u> tags: strip any stray HTML tags and render normal text spans
      final textWithoutHtml = cleanText.replaceAll(RegExp(r'<[^>]*>'), '');
      spans.addAll(_buildWordSpans(
        text: textWithoutHtml,
        isUnderlined: false,
        isDark: isDark,
        fontSize: fontSize,
        height: height,
        underlineColor: activeUnderlineColor,
        overrideTextColor: textColor,
        normalFontWeight: normalFontWeight,
        underlinedFontWeight: underlinedFontWeight,
        onTapWord: onTapWord,
      ));
      return spans;
    }

    int lastIndex = 0;
    for (final match in matches) {
      // Process text BEFORE <u> tag
      if (match.start > lastIndex) {
        final normalSegment = cleanText.substring(lastIndex, match.start).replaceAll(RegExp(r'<[^>]*>'), '');
        if (normalSegment.isNotEmpty) {
          spans.addAll(_buildWordSpans(
            text: normalSegment,
            isUnderlined: false,
            isDark: isDark,
            fontSize: fontSize,
            height: height,
            underlineColor: activeUnderlineColor,
            overrideTextColor: textColor,
            normalFontWeight: normalFontWeight,
            underlinedFontWeight: underlinedFontWeight,
            onTapWord: onTapWord,
          ));
        }
      }

      // Process text INSIDE <u> tag
      final underlinedContent = (match.group(1) ?? '').replaceAll(RegExp(r'<[^>]*>'), '');
      if (underlinedContent.isNotEmpty) {
        spans.addAll(_buildWordSpans(
          text: underlinedContent,
          isUnderlined: true,
          isDark: isDark,
          fontSize: fontSize,
          height: height,
          underlineColor: activeUnderlineColor,
          overrideTextColor: textColor,
          normalFontWeight: normalFontWeight,
          underlinedFontWeight: underlinedFontWeight,
          onTapWord: onTapWord,
        ));
      }

      lastIndex = match.end;
    }

    // Process text AFTER last <u> tag
    if (lastIndex < cleanText.length) {
      final remainingSegment = cleanText.substring(lastIndex).replaceAll(RegExp(r'<[^>]*>'), '');
      if (remainingSegment.isNotEmpty) {
        spans.addAll(_buildWordSpans(
          text: remainingSegment,
          isUnderlined: false,
          isDark: isDark,
          fontSize: fontSize,
          height: height,
          underlineColor: activeUnderlineColor,
          overrideTextColor: textColor,
          normalFontWeight: normalFontWeight,
          underlinedFontWeight: underlinedFontWeight,
          onTapWord: onTapWord,
        ));
      }
    }

    return spans;
  }

  static List<InlineSpan> _buildWordSpans({
    required String text,
    required bool isUnderlined,
    required bool isDark,
    required double fontSize,
    required double height,
    required Color underlineColor,
    Color? overrideTextColor,
    FontWeight? normalFontWeight,
    FontWeight? underlinedFontWeight,
    required void Function(String word, String cleanWord) onTapWord,
  }) {
    final List<InlineSpan> spans = [];
    final words = text.split(' ');

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) {
        spans.add(const TextSpan(text: ' '));
        continue;
      }

      final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z]'), '');

      if (isUnderlined) {
        // UNDERLINED WORD (from <u>...</u>)
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InkWell(
              onTap: () => onTapWord(word, cleanWord),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.only(bottom: 1.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: underlineColor,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: height,
                    fontWeight: underlinedFontWeight ?? FontWeight.bold,
                    color: overrideTextColor ?? (isDark ? Colors.green.shade300 : const Color(0xFF1E293B)),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        // NORMAL WORD (no bottom border, no underline!)
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InkWell(
              onTap: () => onTapWord(word, cleanWord),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.0),
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: height,
                    fontWeight: normalFontWeight ?? FontWeight.w600,
                    color: overrideTextColor ?? (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (i < words.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return spans;
  }
}
