import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  String _googleTranslation = '';
  bool _isLoading = true;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _fetchTranslation();
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
              _googleTranslation = result;
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
        _googleTranslation = widget.localTranslation.isNotEmpty
            ? widget.localTranslation
            : 'অনুবাদ লোড করা যায়নি।';
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
            // Header Bar: Uppercase word title + Close button X (Matching Screenshot 3)
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

            // Optional Image Preview Box (Only displayed if valid image URL is uploaded)
            if (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 140,
                  color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                  child: Image.network(
                    ApiService.formatImageUrl(widget.imageUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Word Title
            Text(
              widget.italianText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),

            // Bangla Translation (Matching Screenshot 3)
            _isLoading
                ? const SizedBox(
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)),
                      ),
                    ),
                  )
                : Text(
                    _googleTranslation.isNotEmpty ? _googleTranslation : widget.localTranslation,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
            const SizedBox(height: 20),

            // Action Icons Row: Flag (🇧🇩 Bangla), Bookmark, Search, Audio (Matching Screenshot 3)
            Row(
              children: [
                // Flag & Language Label
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
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
                    color: _isBookmarked ? const Color(0xFF4CAF50) : Colors.black87,
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

                // Search icon
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.black87, size: 22),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${widget.italianText}" অনুসন্ধানের জন্য ডিকশনারিতে নিয়ে যাওয়া হচ্ছে...'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),

                // Audio Speaker icon
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: Colors.black87, size: 22),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${widget.italianText}" এর উচ্চারণ প্লে হচ্ছে...'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Big OK Button at bottom matching Screenshot 3
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

  Widget _buildFallbackImage(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 36, color: isDark ? Colors.white38 : Colors.grey.shade400),
          const SizedBox(height: 6),
          Text(
            'চিত্র উদাহরণ',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
