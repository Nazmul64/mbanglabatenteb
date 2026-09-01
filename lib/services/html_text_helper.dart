import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/question_database.dart';

class HtmlTextHelper {
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
  /// Underlines are rendered in solid BLACK in light mode (`Colors.black87`) or white/light grey in dark mode.
  /// Multi-word phrases inside `<u>...</u>` or matching vocabulary entries are treated as single cohesive entities.
  static List<InlineSpan> buildParsedStatementSpans({
    required String statement,
    required bool isDark,
    required void Function(String phrase, String cleanPhrase) onTapWord,
    double fontSize = 15.0,
    double height = 1.45,
    Color? underlineColor,
    Color? textColor,
    FontWeight? normalFontWeight,
    FontWeight? underlinedFontWeight,
    List<dynamic>? vocabulary,
  }) {
    final List<InlineSpan> spans = [];
    // Underlines are strictly BLACK in light mode, White/LightGrey in dark mode
    final activeUnderlineColor = underlineColor ?? (isDark ? Colors.white70 : Colors.black87);
    final activeTextColor = textColor ?? (isDark ? Colors.white : const Color(0xFF1E293B));

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
      // If no <u> tags, parse text matching against multi-word vocabulary phrases & words (at most once per phrase)
      final textWithoutHtml = cleanText.replaceAll(RegExp(r'<[^>]*>'), '');
      spans.addAll(_buildVocabularyAwareSpans(
        text: textWithoutHtml,
        isDark: isDark,
        fontSize: fontSize,
        height: height,
        underlineColor: activeUnderlineColor,
        textColor: activeTextColor,
        normalFontWeight: normalFontWeight,
        underlinedFontWeight: underlinedFontWeight,
        vocabulary: vocabulary,
        onTapWord: onTapWord,
      ));
      return spans;
    }

    int lastIndex = 0;
    for (final match in matches) {
      // Process normal text BEFORE <u> tag without duplicate underlines
      if (match.start > lastIndex) {
        final normalSegment = cleanText.substring(lastIndex, match.start).replaceAll(RegExp(r'<[^>]*>'), '');
        if (normalSegment.isNotEmpty) {
          spans.addAll(_renderPlainWords(
            text: normalSegment,
            fontSize: fontSize,
            height: height,
            textColor: activeTextColor,
            normalFontWeight: normalFontWeight,
            onTapWord: onTapWord,
          ));
        }
      }

      // Process text INSIDE <u> tag (Only the explicitly tagged phrase is underlined)
      final rawInner = match.group(1) ?? '';
      final underlinedContent = rawInner.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      if (underlinedContent.isNotEmpty) {
        final cleanPhrase = underlinedContent.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();

        // Split phrase into words but underline them together
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
                fontWeight: underlinedFontWeight ?? FontWeight.bold,
                color: activeTextColor,
                decoration: TextDecoration.underline,
                decorationColor: activeUnderlineColor,
                decorationThickness: 1.8,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => onTapWord(underlinedContent, cleanPhrase),
            ),
          );

          // Add space between words
          spans.add(
            TextSpan(
              text: ' ',
              style: TextStyle(fontSize: fontSize, height: height),
            ),
          );
        }
      }

      lastIndex = match.end;
    }

    // Process text AFTER last <u> tag without duplicate underlines
    if (lastIndex < cleanText.length) {
      final remainingSegment = cleanText.substring(lastIndex).replaceAll(RegExp(r'<[^>]*>'), '');
      if (remainingSegment.isNotEmpty) {
        spans.addAll(_renderPlainWords(
          text: remainingSegment,
          fontSize: fontSize,
          height: height,
          textColor: activeTextColor,
          normalFontWeight: normalFontWeight,
          onTapWord: onTapWord,
        ));
      }
    }

    return spans;
  }

  /// Highlight words and multi-word phrases from vocabulary & glossary
  static List<InlineSpan> _buildVocabularyAwareSpans({
    required String text,
    required bool isDark,
    required double fontSize,
    required double height,
    required Color underlineColor,
    required Color textColor,
    FontWeight? normalFontWeight,
    FontWeight? underlinedFontWeight,
    List<dynamic>? vocabulary,
    required void Function(String phrase, String cleanPhrase) onTapWord,
  }) {
    final List<InlineSpan> spans = [];

    // Collect all candidate phrases (both multi-word and single-word) from vocabulary and globalGlossary
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

    // Also include global glossary phrases that exist in the text
    final lowerText = text.toLowerCase();
    for (final k in QuestionDatabase.globalGlossary.keys) {
      if (k.contains(' ') && lowerText.contains(k.toLowerCase())) {
        if (!candidatePhrases.any((p) => p.toLowerCase() == k.toLowerCase())) {
          candidatePhrases.add(k);
        }
      }
    }

    // Sort phrases by length descending (longest phrase first) so multi-word matches take precedence
    candidatePhrases.sort((a, b) => b.length.compareTo(a.length));

    if (candidatePhrases.isEmpty) {
      // If no phrases, split by words and render normally
      return _renderPlainWords(
        text: text,
        fontSize: fontSize,
        height: height,
        textColor: textColor,
        normalFontWeight: normalFontWeight,
        onTapWord: onTapWord,
      );
    }

    // Find non-overlapping occurrences of phrases in the text (each matched phrase at most once)
    final Set<String> matchedPhrases = {};
    int cursor = 0;
    while (cursor < text.length) {
      int bestMatchStart = -1;
      int bestMatchEnd = -1;
      String? bestMatchedPhrase;

      for (final phrase in candidatePhrases) {
        if (matchedPhrases.contains(phrase.toLowerCase())) continue;
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
        matchedPhrases.add(bestMatchedPhrase.toLowerCase());
        // Matched a phrase starting right at cursor
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
                fontWeight: underlinedFontWeight ?? FontWeight.bold,
                color: textColor,
                decoration: TextDecoration.underline,
                decorationColor: underlineColor,
                decorationThickness: 1.8,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => onTapWord(bestMatchedPhrase!, cleanPhrase),
            ),
          );

          if (w < phraseWords.length - 1) {
            spans.add(
              TextSpan(
                text: ' ',
                style: TextStyle(fontSize: fontSize, height: height),
              ),
            );
          }
        }

        cursor = bestMatchEnd;
        if (cursor < text.length && text[cursor] == ' ') {
          spans.add(TextSpan(text: ' ', style: TextStyle(fontSize: fontSize, height: height)));
          cursor++;
        }
      } else {
        // Move forward by one word
        final nextSpace = text.indexOf(' ', cursor);
        final endOfWord = nextSpace == -1 ? text.length : nextSpace;
        final singleWord = text.substring(cursor, endOfWord);

        if (singleWord.trim().isNotEmpty) {
          final cleanWord = singleWord.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          
          bool isVocabSingle = false;
          for (final p in candidatePhrases) {
            if (!matchedPhrases.contains(p.toLowerCase()) &&
                (p.toLowerCase() == singleWord.toLowerCase() || p.toLowerCase() == cleanWord)) {
              isVocabSingle = true;
              matchedPhrases.add(p.toLowerCase());
              break;
            }
          }

          spans.add(
            TextSpan(
              text: singleWord,
              style: TextStyle(
                fontSize: fontSize,
                height: height,
                fontWeight: isVocabSingle
                    ? (underlinedFontWeight ?? FontWeight.bold)
                    : (normalFontWeight ?? FontWeight.w600),
                color: textColor,
                decoration: isVocabSingle ? TextDecoration.underline : TextDecoration.none,
                decorationColor: isVocabSingle ? underlineColor : null,
                decorationThickness: 1.8,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => onTapWord(singleWord, cleanWord),
            ),
          );
        }

        cursor = endOfWord;
        if (cursor < text.length && text[cursor] == ' ') {
          spans.add(TextSpan(text: ' ', style: TextStyle(fontSize: fontSize, height: height)));
          cursor++;
        }
      }
    }

    return spans;
  }

  static List<InlineSpan> _renderPlainWords({
    required String text,
    required double fontSize,
    required double height,
    required Color textColor,
    FontWeight? normalFontWeight,
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
            fontWeight: normalFontWeight ?? FontWeight.w600,
            color: textColor,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onTapWord(word, cleanWord),
        ),
      );

      if (i < words.length - 1) {
        spans.add(
          TextSpan(
            text: ' ',
            style: TextStyle(fontSize: fontSize, height: height),
          ),
        );
      }
    }

    return spans;
  }
}
