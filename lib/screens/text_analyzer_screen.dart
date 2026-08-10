import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class TextAnalyzerScreen extends StatefulWidget {
  const TextAnalyzerScreen({super.key});

  @override
  State<TextAnalyzerScreen> createState() => _TextAnalyzerScreenState();
}

class _TextAnalyzerScreenState extends State<TextAnalyzerScreen> {
  final TextEditingController _controller = TextEditingController();
  int _charCount = 0;
  int _charNoSpaces = 0;
  int _wordCount = 0;
  int _sentenceCount = 0;
  int _banglaCharCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_analyzeText);
  }

  @override
  void dispose() {
    _controller.removeListener(_analyzeText);
    _controller.dispose();
    super.dispose();
  }

  void _analyzeText() {
    final text = _controller.text;
    setState(() {
      _charCount = text.length;
      _charNoSpaces = text.replaceAll(RegExp(r'\s+'), '').length;
      
      // Word count calculation
      if (text.trim().isEmpty) {
        _wordCount = 0;
      } else {
        _wordCount = text.trim().split(RegExp(r'\s+')).length;
      }

      // Sentence count calculation
      if (text.trim().isEmpty) {
        _sentenceCount = 0;
      } else {
        // Splitting by Bengali full stop (।) and English (. ! ?)
        _sentenceCount = text.split(RegExp(r'[।\.!\?]')).where((s) => s.trim().isNotEmpty).length;
      }

      // Bangla character detection (Unicode block: 0980–09FF)
      _banglaCharCount = 0;
      for (int i = 0; i < text.length; i++) {
        int code = text.codeUnitAt(i);
        if (code >= 0x0980 && code <= 0x09FF) {
          _banglaCharCount++;
        }
      }
    });
  }

  Future<void> _copyToClipboard() async {
    if (_controller.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('টেক্সট ক্লিপবোর্ডে কপি করা হয়েছে! 📋'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _controller.text = data.text!;
      });
    }
  }

  void _clearText() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input Box Card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 8,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'আপনার বাংলা লেখা এখানে লিখুন বা পেস্ট করুন...',
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Paste Button
                      TextButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.paste, size: 18),
                        label: const Text('পেস্ট'),
                      ),
                      const SizedBox(width: 8),
                      // Copy Button
                      TextButton.icon(
                        onPressed: _controller.text.isNotEmpty ? _copyToClipboard : null,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('কপি'),
                      ),
                      const SizedBox(width: 8),
                      // Clear Button
                      IconButton(
                        onPressed: _controller.text.isNotEmpty ? _clearText : null,
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'মুছে ফেলুন',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // Analysis Section Title
          const Text(
            'বিশ্লেষণ ফলাফল',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          // Statistics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard('শব্দ (Words)', '$_wordCount', Icons.wb_auto, AppTheme.primaryGradient),
              _buildStatCard('অক্ষর (Characters)', '$_charCount', Icons.abc, AppTheme.purpleGradient),
              _buildStatCard('বাক্য (Sentences)', '$_sentenceCount', Icons.wrap_text, AppTheme.sunsetGradient),
              _buildStatCard(
                'বাংলা অক্ষর (Bangla)',
                '$_banglaCharCount',
                Icons.translate,
                LinearGradient(
                  colors: [Colors.teal.shade400, Colors.green.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Gradient gradient) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                Icon(icon, color: isDark ? Colors.white24 : Colors.black12, size: 20),
              ],
            ),
            ShaderMask(
              shaderCallback: (bounds) => gradient.createShader(Offset.zero & bounds.size),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Required for gradient shader
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
