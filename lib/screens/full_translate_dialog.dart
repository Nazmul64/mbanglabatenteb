import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'google_translate_dialog.dart';
import 'image_zoom_dialog.dart';
import '../services/html_text_helper.dart';
import '../services/api_service.dart';
import '../models/question_database.dart';

class FullTranslateDialog extends StatefulWidget {
  final String italianText;
  final String banglaText;
  final String? imageUrl;
  final List<dynamic>? vocabulary;

  const FullTranslateDialog({
    super.key,
    required this.italianText,
    required this.banglaText,
    this.imageUrl,
    this.vocabulary,
  });

  @override
  State<FullTranslateDialog> createState() => _FullTranslateDialogState();
}

class _FullTranslateDialogState extends State<FullTranslateDialog> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    _flutterTts.setLanguage('it-IT');
    _flutterTts.setSpeechRate(0.45);
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _toggleSpeak() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      final cleanText = widget.italianText.replaceAll(RegExp(r'<[^>]*>'), '');
      if (cleanText.trim().isNotEmpty) {
        setState(() => _isSpeaking = true);
        await _flutterTts.speak(cleanText);
      }
    }
  }

  String? _resolveEffectiveImageUrl() {
    if (widget.imageUrl != null &&
        widget.imageUrl!.trim().isNotEmpty &&
        widget.imageUrl!.trim().toLowerCase() != 'null' &&
        widget.imageUrl!.trim().toLowerCase() != 'undefined') {
      return widget.imageUrl;
    }
    if (widget.vocabulary != null) {
      for (var v in widget.vocabulary!) {
        if (v is Map) {
          final img = (v['image'] ?? v['image_path'] ?? v['img'] ?? v['photo'] ?? v['image_url'])?.toString().trim();
          if (img != null && img.isNotEmpty && img.toLowerCase() != 'null' && img.toLowerCase() != 'undefined' && img.toLowerCase() != 'none') {
            return img;
          }
        }
      }
    }
    return null;
  }

  Widget _buildFormattedItalianText(BuildContext context, bool isDark) {
    return RichText(
      text: TextSpan(
        children: HtmlTextHelper.buildParsedStatementSpans(
          statement: widget.italianText,
          isDark: isDark,
          fontSize: 14.5,
          height: 1.45,
          vocabulary: widget.vocabulary,
          underlineColor: isDark ? Colors.white70 : Colors.black87,
          onTapWord: (rawWord, cleanWord) {
            String? vocabImage;
            String translation = '';
            if (widget.vocabulary != null) {
              for (var item in widget.vocabulary!) {
                if (item is Map) {
                  final word = (item['italian'] ?? item['word'] ?? item['italian_word'] ?? '').toString().trim().toLowerCase();
                  final rawLower = rawWord.toLowerCase().trim();
                  final cleanLower = cleanWord.toLowerCase().trim();
                  if (word.isNotEmpty && (word == cleanLower || word == rawLower)) {
                    final bn = (item['bangla'] ?? item['meaning'] ?? item['bangla_meaning'] ?? item['translation'] ?? '').toString().trim();
                    if (bn.isNotEmpty) translation = bn;
                    final img = (item['image'] ?? item['image_path'] ?? item['img'] ?? item['photo'] ?? item['image_url'] ?? '').toString().trim();
                    if (img.isNotEmpty && img.toLowerCase() != 'null' && img.toLowerCase() != 'undefined' && img.toLowerCase() != 'none') {
                      vocabImage = img;
                    }
                    break;
                  }
                }
              }
            }

            if (translation.isEmpty && QuestionDatabase.globalGlossary.containsKey(cleanWord.toLowerCase())) {
              translation = QuestionDatabase.globalGlossary[cleanWord.toLowerCase()]!;
            } else if (translation.isEmpty && QuestionDatabase.globalGlossary.containsKey(rawWord.toLowerCase())) {
              translation = QuestionDatabase.globalGlossary[rawWord.toLowerCase()]!;
            }

            showDialog(
              context: context,
              builder: (context) => GoogleTranslateDialog(
                italianText: rawWord.isNotEmpty ? rawWord : cleanWord,
                localTranslation: translation,
                imageUrl: vocabImage ?? _resolveEffectiveImageUrl(),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveImage = _resolveEffectiveImageUrl();
    final formattedImgUrl = ApiService.formatImageUrl(effectiveImage);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Italian Text with clickable underlined words
                    _buildFormattedItalianText(context, isDark),
                    const SizedBox(height: 14),

                    // 2. Question/Vocabulary Image (centered in the middle between Italian and Bengali)
                    if (formattedImgUrl.isNotEmpty) ...[
                      Center(
                        child: GestureDetector(
                          onTap: () => ImageZoomDialog.show(context, effectiveImage),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                              ),
                              child: Image.network(
                                formattedImgUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                    const SizedBox(height: 14),

                    // 3. Bengali Translation
                    Text(
                      widget.banglaText.replaceAll('<br>', '\n').replaceAll('<br/>', '\n'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Action Buttons Footer: Speaker Icon on Left, OK button on Right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    _isSpeaking ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.blue.shade600,
                    size: 26,
                  ),
                  onPressed: _toggleSpeak,
                  tooltip: 'উচ্চারণ শুনুন',
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                    side: BorderSide(color: Colors.blue.shade600, width: 1.5),
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
