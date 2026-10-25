import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HtmlTextHelper {
  /// Italian grammatical stopwords/particles that shouldn't have dictionary underlines
  static const Set<String> italianStopwords = {
    'il', 'lo', 'la', 'i', 'gli', 'le', "l'", 'un', 'uno', 'una', "un'",
    'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra',
    'e', 'ed', 'o', 'od', 'né', 'se', 'non', 'ne', 'ci', 'vi', 'si',
    'mi', 'ti', 'del', 'dello', 'della', 'dei', 'degli', 'delle',
    'al', 'allo', 'alla', 'ai', 'agli', 'alle', 'dal', 'dallo', 'dalla',
    'dai', 'dagli', 'dalle', 'nel', 'nello', 'nella', 'nei', 'negli', 'nelle',
    'sul', 'sullo', 'sulla', 'sui', 'sugli', 'sulle', 'col', 'coi', 'che'
  };

  /// Strip all HTML tags from a text string (useful for TTS or plain text display)
  static String stripHtml(String text) {
    return text
        .replaceAll('<br>', ' ')
        .replaceAll('<br/>', ' ')
        .replaceAll('<br />', ' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Parse text containing `<u>...</u>` and vocabulary phrases into InlineSpans.
  /// Styling matches modern premium typography: Slate Charcoal (never pitch black)
  /// with underlines appearing ONLY on explicitly underlined words from Admin Panel.
  static List<InlineSpan> buildParsedStatementSpans({
    required String statement,
    required bool isDark,
    required void Function(String phrase, String cleanPhrase) onTapWord,
    double fontSize = 16.0,
    double height = 1.45,
    Color? underlineColor,
    Color? textColor,
    FontWeight? normalFontWeight,
    FontWeight? underlinedFontWeight,
    List<dynamic>? vocabulary,
  }) {
    final List<InlineSpan> spans = [];
    final activeUnderlineColor = underlineColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));
    final activeTextColor = textColor ?? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));
    final effectiveNormalWeight = normalFontWeight ?? FontWeight.w500;
    // Underlined words must NOT be bold - keep normal font weight identical to surrounding text
    final effectiveUnderlinedWeight = underlinedFontWeight ?? effectiveNormalWeight;

    // 1. Normalize line breaks and multiple spaces
    String cleanText = statement
        .replaceAll('\r\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('<br>', ' ')
        .replaceAll('<br/>', ' ')
        .replaceAll('<br />', ' ')
        .trim();

    // 2. Regex for <u>...</u> tags
    final regExp = RegExp(r'<u>(.*?)</u>', caseSensitive: false, dotAll: true);
    final matches = regExp.allMatches(cleanText);

    if (matches.isEmpty) {
      // If no <u> tags, check if specific vocabulary words from admin panel should be underlined
      final textWithoutHtml = cleanText.replaceAll(RegExp(r'<[^>]*>'), '');
      spans.addAll(_buildVocabularyAwareSpans(
        text: textWithoutHtml,
        isDark: isDark,
        fontSize: fontSize,
        height: height,
        underlineColor: activeUnderlineColor,
        textColor: activeTextColor,
        normalFontWeight: effectiveNormalWeight,
        underlinedFontWeight: effectiveUnderlinedWeight,
        vocabulary: vocabulary,
        onTapWord: onTapWord,
      ));
      return spans;
    }

    int lastIndex = 0;
    for (final match in matches) {
      // Process normal text BEFORE <u> tag - NO UNDERLINE
      if (match.start > lastIndex) {
        final normalSegment = cleanText.substring(lastIndex, match.start).replaceAll(RegExp(r'<[^>]*>'), '');
        if (normalSegment.isNotEmpty) {
          spans.addAll(_renderPlainWords(
            text: normalSegment,
            fontSize: fontSize,
            height: height,
            textColor: activeTextColor,
            normalFontWeight: effectiveNormalWeight,
            onTapWord: onTapWord,
          ));
        }
      }

      // Process text INSIDE <u> tag - UNDERLINED
      final rawInner = match.group(1) ?? '';
      final underlinedContent = rawInner.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      if (underlinedContent.isNotEmpty) {
        final cleanPhrase = underlinedContent.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
        final phraseWords = underlinedContent.split(RegExp(r'\s+'));

        for (int w = 0; w < phraseWords.length; w++) {
          final word = phraseWords[w];
          if (word.isEmpty) continue;

          spans.add(
            TextSpan(
              text: word,
              style: TextStyle(
                fontSize: fontSize,
                height: height,
                fontWeight: effectiveUnderlinedWeight,
                color: activeTextColor,
                decoration: TextDecoration.underline,
                decorationColor: activeUnderlineColor,
                decorationThickness: 1.3,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => onTapWord(underlinedContent, cleanPhrase),
            ),
          );

          if (w < phraseWords.length - 1) {
            spans.add(
              TextSpan(
                text: ' ',
                style: TextStyle(
                  fontSize: fontSize,
                  height: height,
                  color: activeTextColor,
                  decoration: TextDecoration.none,
                ),
              ),
            );
          }
        }

        // If the original tag had trailing space or text after tag starts without space, keep separation clean
        if (rawInner.endsWith(' ') || (match.end < cleanText.length && !cleanText.substring(match.end).startsWith(' '))) {
          spans.add(
            TextSpan(
              text: ' ',
              style: TextStyle(
                fontSize: fontSize,
                height: height,
                color: activeTextColor,
                decoration: TextDecoration.none,
              ),
            ),
          );
        }
      }

      lastIndex = match.end;
    }

    // Process text AFTER last <u> tag - NO UNDERLINE
    if (lastIndex < cleanText.length) {
      final remainingSegment = cleanText.substring(lastIndex).replaceAll(RegExp(r'<[^>]*>'), '');
      if (remainingSegment.isNotEmpty) {
        spans.addAll(_renderPlainWords(
          text: remainingSegment,
          fontSize: fontSize,
          height: height,
          textColor: activeTextColor,
          normalFontWeight: effectiveNormalWeight,
          onTapWord: onTapWord,
        ));
      }
    }

    return spans;
  }

  /// Highlight only explicitly registered vocabulary words from admin panel
  static List<InlineSpan> _buildVocabularyAwareSpans({
    required String text,
    required bool isDark,
    required double fontSize,
    required double height,
    required Color underlineColor,
    required Color textColor,
    required FontWeight normalFontWeight,
    required FontWeight underlinedFontWeight,
    List<dynamic>? vocabulary,
    required void Function(String phrase, String cleanPhrase) onTapWord,
  }) {
    final List<InlineSpan> spans = [];

    // Collect candidate multi-word phrases strictly from question vocabulary
    final List<String> candidatePhrases = [];

    if (vocabulary != null && vocabulary.isNotEmpty) {
      for (var v in vocabulary) {
        if (v is Map) {
          final it = (v['italian'] ?? v['word'] ?? v['italian_word'] ?? '').toString().trim();
          if (it.isNotEmpty && !candidatePhrases.any((p) => p.toLowerCase() == it.toLowerCase())) {
            candidatePhrases.add(it);
          }
        }
      }
    }

    candidatePhrases.sort((a, b) => b.length.compareTo(a.length));

    int cursor = 0;
    while (cursor < text.length) {
      int bestMatchStart = -1;
      int bestMatchEnd = -1;
      String? bestMatchedPhrase;

      for (final phrase in candidatePhrases) {
        final pattern = RegExp(r'\b' + RegExp.escape(phrase) + r'\b', caseSensitive: false);
        final match = pattern.matchAsPrefix(text, cursor);
        if (match != null) {
          bestMatchStart = match.start;
          bestMatchEnd = match.end;
          bestMatchedPhrase = text.substring(match.start, match.end);
          break;
        }
      }

      if (bestMatchedPhrase != null && bestMatchStart == cursor) {
        final cleanPhrase = bestMatchedPhrase.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
        final phraseWords = bestMatchedPhrase.split(RegExp(r'\s+'));

        for (int w = 0; w < phraseWords.length; w++) {
          final word = phraseWords[w];
          if (word.isEmpty) continue;

          spans.add(
            TextSpan(
              text: word,
              style: TextStyle(
                fontSize: fontSize,
                height: height,
                fontWeight: underlinedFontWeight,
                color: textColor,
                decoration: TextDecoration.underline,
                decorationColor: underlineColor,
                decorationThickness: 1.3,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => onTapWord(bestMatchedPhrase!, cleanPhrase),
            ),
          );

          if (w < phraseWords.length - 1) {
            spans.add(
              TextSpan(
                text: ' ',
                style: TextStyle(
                  fontSize: fontSize,
                  height: height,
                  color: textColor,
                  decoration: TextDecoration.none,
                ),
              ),
            );
          }
        }

        cursor = bestMatchEnd;
        if (cursor < text.length && text[cursor] == ' ') {
          spans.add(TextSpan(text: ' ', style: TextStyle(fontSize: fontSize, height: height, color: textColor, decoration: TextDecoration.none)));
          cursor++;
        }
      } else {
        // Single word processing - Plain word with NO underline
        final nextSpace = text.indexOf(' ', cursor);
        final endOfWord = nextSpace == -1 ? text.length : nextSpace;
        final singleWord = text.substring(cursor, endOfWord);

        if (singleWord.trim().isNotEmpty) {
          final cleanWord = singleWord.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

          // Underline ONLY if explicitly registered in question's vocabulary list
          bool isExplicitVocab = false;
          if (vocabulary != null && vocabulary.isNotEmpty) {
            isExplicitVocab = vocabulary.any((v) {
              if (v is Map) {
                final it = (v['italian'] ?? v['word'] ?? v['italian_word'] ?? '').toString().trim().toLowerCase();
                return it.isNotEmpty && (it == cleanWord || it == singleWord.toLowerCase().trim());
              }
              return false;
            });
          }

          spans.add(
            TextSpan(
              text: singleWord,
              style: TextStyle(
                fontSize: fontSize,
                height: height,
                fontWeight: isExplicitVocab ? underlinedFontWeight : normalFontWeight,
                color: textColor,
                decoration: isExplicitVocab ? TextDecoration.underline : TextDecoration.none,
                decorationColor: isExplicitVocab ? underlineColor : null,
                decorationThickness: 1.3,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => onTapWord(singleWord, cleanWord),
            ),
          );
        }

        cursor = endOfWord;
        if (cursor < text.length && text[cursor] == ' ') {
          spans.add(TextSpan(text: ' ', style: TextStyle(fontSize: fontSize, height: height, color: textColor, decoration: TextDecoration.none)));
          cursor++;
        }
      }
    }

    return spans;
  }

  /// Plain words outside of `<u>...</u>` - NEVER underlined!
  static List<InlineSpan> _renderPlainWords({
    required String text,
    required double fontSize,
    required double height,
    required Color textColor,
    required FontWeight normalFontWeight,
    required void Function(String phrase, String cleanPhrase) onTapWord,
  }) {
    final List<InlineSpan> spans = [];
    final words = text.split(RegExp(r'\s+'));

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;

      final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      spans.add(
        TextSpan(
          text: word,
          style: TextStyle(
            fontSize: fontSize,
            height: height,
            fontWeight: normalFontWeight,
            color: textColor,
            decoration: TextDecoration.none, // Crucial: Plain words NEVER have underline
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onTapWord(word, cleanWord),
        ),
      );

      if (i < words.length - 1) {
        spans.add(
          TextSpan(
            text: ' ',
            style: TextStyle(
              fontSize: fontSize,
              height: height,
              color: textColor,
              decoration: TextDecoration.none,
            ),
          ),
        );
      }
    }

    return spans;
  }
}
