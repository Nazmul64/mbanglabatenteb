import 'dart:async';
import 'package:flutter/material.dart';
import 'triangle_pattern_painter.dart';
import '../services/api_service.dart';
import '../models/question_database.dart';

class PatenteWord {
  final String italian;
  final String bangla;
  final String english;
  final String explanation;
  final String example;
  final String audioUrl;
  bool isSaved;

  PatenteWord({
    required this.italian,
    required this.bangla,
    required this.english,
    required this.explanation,
    required this.example,
    this.audioUrl = '',
    this.isSaved = false,
  });
}

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<PatenteWord> _words = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadDictionaryWords('');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      _searchQuery = query;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        _loadDictionaryWords(_searchQuery);
      });
    }
  }

  Future<void> _loadDictionaryWords(String query) async {
    setState(() {
      _isLoading = true;
    });

    final apiData = await ApiService.fetchDictionary(search: query);
    final List<PatenteWord> loaded = [];
    final Set<String> seen = {};

    if (apiData.isNotEmpty) {
      for (var item in apiData) {
        if (item is Map) {
          final itWord = (item['word'] ?? item['italian'] ?? item['it_word'] ?? item['title'] ?? '').toString().trim();
          final bnWord = (item['bn'] ?? item['bangla'] ?? item['bn_word'] ?? item['bn_meaning'] ?? item['definition'] ?? '').toString().trim();
          final descBn = (item['desc_bn'] ?? item['desc_it'] ?? item['definition'] ?? item['bn_description'] ?? item['explanation'] ?? '').toString().trim();
          final enWord = (item['en_word'] ?? item['english'] ?? '').toString().trim();
          final example = (item['example'] ?? item['it_example'] ?? '').toString().trim();
          final audio = (item['audio'] ?? item['voice'] ?? '').toString().trim();

          if (itWord.isNotEmpty || bnWord.isNotEmpty) {
            seen.add(itWord.toLowerCase());
            loaded.add(PatenteWord(
              italian: itWord.isNotEmpty ? itWord : bnWord,
              bangla: bnWord,
              english: enWord,
              explanation: descBn,
              example: example,
              audioUrl: audio,
            ));
          }
        }
      }
    }

    // Glossary Fallback
    final cleanQ = query.trim().toLowerCase();
    QuestionDatabase.globalGlossary.forEach((it, bn) {
      final itLower = it.toLowerCase();
      final bnLower = bn.toLowerCase();
      if ((cleanQ.isEmpty || itLower.contains(cleanQ) || bnLower.contains(cleanQ)) && !seen.contains(itLower)) {
        seen.add(itLower);
        loaded.add(PatenteWord(
          italian: it,
          bangla: bn,
          english: '',
          explanation: bn,
          example: '',
          audioUrl: '',
        ));
      }
    });

    if (mounted) {
      setState(() {
        _words = loaded;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dizionario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF121829) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background triangles pattern
          Positioned.fill(
            child: CustomPaint(
              painter: TrianglePatternPainter(
                triangleColor: isDark
                    ? Colors.white.withOpacity(0.015)
                    : Colors.blue.withOpacity(0.02),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                children: [
                  // Search box matching Screenshot 2: "ইতালীয় বা বাংলা শব্দ দিয়ে খুঁজুন..."
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E294B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'ইতালীয় বা বাংলা শব্দ দিয়ে খুঁজুন...',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.cyan : Colors.blue.shade600),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadDictionaryWords('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dictionary Word Cards List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                        : _words.isEmpty
                            ? const Center(
                                child: Text('কোনো শব্দ পাওয়া যায়নি', style: TextStyle(color: Colors.grey, fontSize: 14)),
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _words.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final word = _words[index];
                                  return _buildDictionaryCard(word, isDark);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDictionaryCard(PatenteWord word, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E294B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Italian Word Title (Blue bold text matching Screenshot 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    word.italian,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2962FF), // Blue title matching screenshot
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF2962FF), size: 22),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${word.italian}" এর উচ্চারণ চালানো হচ্ছে...'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'উচ্চারণ শুনুন',
                ),
              ],
            ),

            // Subtitle text in bold grey
            if (word.bangla.isNotEmpty) ...[
              Text(
                word.bangla,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Bangla Explanation Paragraph matching Screenshot 2
            if (word.explanation.isNotEmpty) ...[
              Text(
                word.explanation,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Green Example / Keyword Text matching Screenshot 2
            if (word.example.isNotEmpty) ...[
              Text(
                word.example,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50), // Green example text matching screenshot
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
