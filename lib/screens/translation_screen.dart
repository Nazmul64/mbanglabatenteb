import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/api_service.dart';

enum TranslationMode { bnToIt, itToBn }

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();

  TranslationMode _mode = TranslationMode.bnToIt;
  String _translatedText = '';
  bool _isTranslating = false;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _handleTranslate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অনুবাদ করার জন্য কিছু লিখুন।')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });

    final fromLang = _mode == TranslationMode.bnToIt ? 'bn' : 'it';
    final toLang = _mode == TranslationMode.bnToIt ? 'it' : 'bn';

    final res = await ApiService.translateText(
      text: text,
      fromLang: fromLang,
      toLang: toLang,
    );

    if (mounted) {
      setState(() {
        _isTranslating = false;
        if (res != null && res['translated_text'] != null) {
          _translatedText = res['translated_text'].toString();
        } else {
          _translatedText = 'অনুবাদ করতে ব্যর্থ হয়েছে। পুনরায় চেষ্টা করুন।';
        }
      });
    }
  }

  Future<void> _speakResult() async {
    if (_translatedText.isEmpty || _isPlayingAudio) return;
    setState(() => _isPlayingAudio = true);

    final lang = _mode == TranslationMode.bnToIt ? 'it-IT' : 'bn-BD';
    await _flutterTts.setLanguage(lang);
    await _flutterTts.speak(_translatedText);
  }

  void _copyToClipboard() {
    if (_translatedText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _translatedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('অনুবাদ কপি করা হয়েছে!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Subtitle Header
              const Text(
                'অনুবাদ ও উচ্চারণ (Translation)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'বাংলা ➔ ইতালিয়ান এবং ইতালিয়ান ➔ বাংলা তাৎক্ষণিক অনুবাদ ও সঠিক উচ্চারণ',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 18),

              // Mode Switcher Toggle Tabs
              Row(
                children: [
                  Expanded(
                    child: _buildModeTab(
                      label: 'Translate Bangla to Italian',
                      sublabel: 'বাংলা ➔ ইতালিয়ান',
                      mode: TranslationMode.bnToIt,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModeTab(
                      label: 'Translate Italian to Bangla',
                      sublabel: 'ইতালিয়ান ➔ বাংলা',
                      mode: TranslationMode.itToBn,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Input Card Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge & Clear button row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _mode == TranslationMode.bnToIt ? 'বাংলা ➔ ইতালিয়ান' : 'ইতালিয়ান ➔ বাংলা',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        if (_inputController.text.isNotEmpty)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _inputController.clear();
                                _translatedText = '';
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text(
                                'পরিষ্কার করুন',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Input Textfield
                    TextField(
                      controller: _inputController,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: _mode == TranslationMode.bnToIt
                            ? 'বাংলা বাক্য বা শব্দ লিখুন... (যেমন: শুভ সকাল)'
                            : 'ইতালিয়ান বাক্য বা শব্দ লিখুন... (যেমন: Buongiorno)',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 12),

                    // Submit Translate Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _isTranslating ? null : _handleTranslate,
                        icon: _isTranslating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.g_translate_rounded, size: 18),
                        label: Text(
                          _isTranslating ? 'অনুবাদ হচ্ছে...' : 'অনুবাদ করুন',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Output Result Card
              if (_translatedText.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _mode == TranslationMode.bnToIt ? 'ইতালিয়ান অনুবাদ:' : 'বাংলা অনুবাদ:',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.blue),
                            onPressed: _copyToClipboard,
                            tooltip: 'কপি করুন',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _translatedText,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Audio Play Listen Button
                      OutlinedButton.icon(
                        onPressed: _speakResult,
                        icon: Icon(
                          _isPlayingAudio ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                          size: 20,
                          color: Colors.green,
                        ),
                        label: Text(
                          _isPlayingAudio ? 'শুনছেন...' : 'সঠিক উচ্চারণ শুনুন',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required String sublabel,
    required TranslationMode mode,
    required bool isDark,
  }) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _mode = mode;
          _translatedText = '';
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              sublabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.blue : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.blue.shade700 : (isDark ? Colors.white38 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
