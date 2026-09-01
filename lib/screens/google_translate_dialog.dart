import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/api_service.dart';

class GoogleTranslateDialog extends StatefulWidget {
  final String italianText;
  final String localTranslation;
  final String? imageUrl;

  const GoogleTranslateDialog({
    super.key,
    required this.italianText,
    required this.localTranslation,
    this.imageUrl,
  });

  @override
  State<GoogleTranslateDialog> createState() => _GoogleTranslateDialogState();
}

class _GoogleTranslateDialogState extends State<GoogleTranslateDialog> {
  String _translation = '';
  bool _isLoading = true;
  bool _isBookmarked = false;
  final FlutterTts _flutterTts = FlutterTts();

  bool get _hasValidImage {
    final img = widget.imageUrl?.trim() ?? '';
    return img.isNotEmpty &&
        img.toLowerCase() != 'null' &&
        img.toLowerCase() != 'undefined' &&
        img.toLowerCase() != 'none';
  }

  @override
  void initState() {
    super.initState();
    _initTts();
    if (widget.localTranslation.trim().isNotEmpty) {
      _translation = widget.localTranslation.trim();
      _isLoading = false;
    } else {
      _fetchTranslation();
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  void _initTts() {
    _flutterTts.setLanguage('it-IT');
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
  }

  Future<void> _speakWord() async {
    await _flutterTts.setLanguage('it-IT');
    await _flutterTts.speak(widget.italianText);
  }

  Future<void> _fetchTranslation() async {
    try {
      final url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=it&tl=bn&dt=t&q=${Uri.encodeComponent(widget.italianText)}';
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(responseBody);
        if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
          final List parts = decoded[0];
          String result = '';
          for (var part in parts) {
            if (part is List && part.isNotEmpty) {
              result += part[0].toString();
            }
          }
          if (mounted) {
            setState(() {
              _translation = result;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Translation error: $e');
    }
    if (mounted) {
      setState(() {
        _translation = widget.localTranslation.isNotEmpty
            ? widget.localTranslation
            : 'অনুবাদ পাওয়া যায়নি';
        _isLoading = false;
      });
    }
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
              color: Colors.black.withOpacity(0.2),
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
            // Header Bar: Uppercase word title + Close button X
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.italianText.toUpperCase(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Word / Phrase Title in Italian
                    Text(
                      widget.italianText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ONLY display Image Preview Box if this specific word actually has an image!
                    if (_hasValidImage) ...[
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 180),
                            color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                            child: Image.network(
                              ApiService.formatImageUrl(widget.imageUrl),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Bangla Translation Box
                    _isLoading
                        ? const SizedBox(
                            height: 24,
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22C55E)),
                              ),
                            ),
                          )
                        : Text(
                            _translation,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: isDark ? Colors.white : const Color(0xFF16A34A),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Icons Row: Flag (🇧🇩 Bangla), Bookmark, Search, Audio
            Row(
              children: [
                // BD Flag & Label
                Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF006A4E), // BD Flag Green
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircleAvatar(
                          radius: 5,
                          backgroundColor: Color(0xFFF42A41), // Red circle
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Bangla',
                      style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),

                // Bookmark icon
                IconButton(
                  icon: Icon(
                    _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _isBookmarked ? const Color(0xFF22C55E) : (isDark ? Colors.white70 : Colors.black87),
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _isBookmarked = !_isBookmarked;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isBookmarked ? 'শব্দটি বুকমার্ক করা হয়েছে' : 'বুকমার্ক সরানো হয়েছে'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),

                // Audio Speaker icon
                IconButton(
                  icon: Icon(Icons.volume_up_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 22),
                  onPressed: _speakWord,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Big OK Button at bottom
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF8FAFC),
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 0,
                  side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
