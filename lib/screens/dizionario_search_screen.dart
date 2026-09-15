import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/api_service.dart';
import '../models/question_database.dart';
import 'triangle_pattern_painter.dart';
import 'image_zoom_dialog.dart';
import 'quiz_practice_screen.dart';
import 'cartelli_screen.dart';
import 'manuale_screen.dart';

class DizionarioSearchScreen extends StatefulWidget {
  const DizionarioSearchScreen({super.key});

  @override
  State<DizionarioSearchScreen> createState() => _DizionarioSearchScreenState();
}

class _DizionarioSearchScreenState extends State<DizionarioSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  
  String _searchQuery = '';
  String _selectedLetter = '';
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounceTimer;

  static const List<String> _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _initTts() {
    _flutterTts.setLanguage('it-IT');
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
  }

  void _speakItalian(String text) {
    if (text.trim().isNotEmpty) {
      _flutterTts.stop();
      _flutterTts.speak(text.trim());
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      _searchQuery = query;
      _selectedLetter = '';
      _debounceTimer?.cancel();
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
          _isLoading = false;
        });
      } else {
        _debounceTimer = Timer(const Duration(milliseconds: 150), () {
          _performSearch(query: query, letter: '');
        });
      }
    }
  }

  Future<void> _performSearch({String query = '', String letter = ''}) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final cleanQuery = query.trim().toLowerCase();
    final cleanLetter = letter.trim().toUpperCase();
    final List<Map<String, dynamic>> combinedResults = [];
    final Set<String> seenWords = {};

    try {
      // 1. Fetch from Server Dictionary Search API
      final res = await ApiService.searchDictionary(query: query, letter: letter);
      final List<dynamic> list = (res != null && res['results'] is List) ? res['results'] : [];
      
      for (var item in list) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final itWord = (m['word'] ?? m['it'] ?? m['italian'] ?? m['it_word'] ?? '').toString().trim();
          if (itWord.isNotEmpty && !seenWords.contains(itWord.toLowerCase())) {
            seenWords.add(itWord.toLowerCase());
            combinedResults.add(m);
          }
        }
      }

      // 2. If query given and combinedResults empty, also check words endpoint
      if (combinedResults.isEmpty && cleanQuery.isNotEmpty) {
        final wordsList = await ApiService.fetchWords(query: query);
        for (var item in wordsList) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final itWord = (m['word'] ?? m['it'] ?? m['italian'] ?? m['it_word'] ?? '').toString().trim();
            if (itWord.isNotEmpty && !seenWords.contains(itWord.toLowerCase())) {
              seenWords.add(itWord.toLowerCase());
              combinedResults.add(m);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Dictionary server search error: $e');
    }

    // 3. Match against offline/local Patente Glossary Database
    try {
      QuestionDatabase.globalGlossary.forEach((itPhrase, bnMeaning) {
        final itLower = itPhrase.toLowerCase();
        final bnLower = bnMeaning.toLowerCase();

        bool matches = false;
        if (cleanLetter.isNotEmpty) {
          matches = itPhrase.toUpperCase().startsWith(cleanLetter);
        } else if (cleanQuery.isNotEmpty) {
          matches = itLower.contains(cleanQuery) || bnLower.contains(cleanQuery);
        }

        if (matches && !seenWords.contains(itLower)) {
          seenWords.add(itLower);
          combinedResults.add({
            'word': itPhrase,
            'bn': bnMeaning,
            'definition': bnMeaning,
            'source': 'Patente B Glossary',
            'target_type': 'argomenti',
          });
        }
      });
    } catch (e) {
      debugPrint('Glossary search error: $e');
    }

    if (mounted) {
      setState(() {
        _searchResults = combinedResults;
        _isLoading = false;
      });
    }
  }

  void _onLetterSelected(String letter) {
    setState(() {
      _selectedLetter = letter;
      _searchQuery = '';
      _searchController.text = '';
    });
    _performSearch(query: '', letter: letter);
  }

  void _resetSearch() {
    setState(() {
      _searchController.text = '';
      _searchQuery = '';
      _selectedLetter = '';
      _searchResults = [];
      _hasSearched = false;
      _isLoading = false;
    });
  }

  void _navigateToTarget(Map<String, dynamic> item) {
    final targetType = (item['target_type'] ?? '').toString().toLowerCase();
    final pageId = item['page_id'] != null ? int.tryParse(item['page_id'].toString()) : null;
    final chapterId = item['chapter_id'] != null ? int.tryParse(item['chapter_id'].toString()) : null;
    final chapterTitle = item['chapter']?.toString() ?? 'অনুশীলন';

    if (targetType.contains('cartelli')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CartelliScreen()),
      );
    } else if (targetType.contains('manuale')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ManualeScreen()),
      );
    } else {
      // Default to Argomenti Quiz Practice Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizPracticeScreen(
            quizTitle: chapterTitle,
            initialChapterId: chapterId,
            initialPage: pageId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Dizionario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF4CAF50)),
            tooltip: 'উচ্চারণ সহায়িকা',
            onPressed: () => _speakItalian('Dizionario Patente B'),
          ),
        ],
      ),
      body: Stack(
        children: [
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Banner Matching Screenshot
                _buildHeaderBanner(isDark),

                // 2. Search Box & A-Z Letters Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Column(
                    children: [
                      _buildSearchField(isDark),
                      const SizedBox(height: 10),
                      _buildAlphabetFilterBar(isDark),
                    ],
                  ),
                ),

                // 3. Search Results Count Header
                if (_hasSearched)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_searchResults.length}টি ফলাফল পাওয়া গেছে',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty || _selectedLetter.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _searchQuery.isNotEmpty ? 'সার্চ: "$_searchQuery"' : 'অক্ষর: "$_selectedLetter"',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                // 4. Main Content Area
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                        )
                      : !_hasSearched
                          ? _buildInitialPlaceholder(isDark)
                          : _searchResults.isEmpty
                              ? _buildNotFoundView(isDark)
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = _searchResults[index];
                                    if (item is Map) {
                                      return _buildResultCard(Map<String, dynamic>.from(item), isDark);
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'MCQ VOCABULARY SEARCH',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'DIZIONARIO (অভিধান)',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            'এমসিকিউ প্রশ্ন ও থিওরি অধ্যায়ের আন্ডারলাইন করা সকল শব্দের বাংলা অর্থ খুঁজুন',
            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'ইতালীয় বা বাংলা শব্দ লিখুন...',
          hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 22),
          suffixIcon: (_searchQuery.isNotEmpty || _selectedLetter.isNotEmpty)
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  onPressed: _resetSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildAlphabetFilterBar(bool isDark) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _alphabet.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isReset = _selectedLetter.isEmpty && _searchQuery.isEmpty;
            return InkWell(
              onTap: _resetSearch,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isReset
                      ? const Color(0xFF0284C7)
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isReset ? const Color(0xFF0284C7) : (isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                ),
                child: Center(
                  child: Text(
                    'রিসেট (Reset)',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isReset ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                    ),
                  ),
                ),
              ),
            );
          }

          final letter = _alphabet[index - 1];
          final isSelected = _selectedLetter == letter;

          return InkWell(
            onTap: () => _onLetterSelected(letter),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 30,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0284C7)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0284C7) : (isDark ? Colors.white10 : Colors.grey.shade300),
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitialPlaceholder(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_rounded, size: 44, color: Color(0xFF0284C7)),
              ),
              const SizedBox(height: 14),
              const Text(
                'শব্দার্থ অনুসন্ধান করুন',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'যেকোনো ইতালীয় বা বাংলা শব্দ লিখে সার্চ করুন অথবা A-Z অক্ষর সিলেক্ট করুন। সরাসরি সংশ্লিষ্ট এমসিকিউ পেজে যাওয়ার সুবিধা রয়েছে।',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotFoundView(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sentiment_dissatisfied_rounded, size: 44, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'শব্দটি পাওয়া যায়নি (Not Found)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'বানান সঠিক আছে কিনা যাচাই করে পুনরায় অনুসন্ধান করুন।',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _resetSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('রিসেট করুন', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item, bool isDark) {
    final word = (item['word'] ?? item['it'] ?? item['italian'] ?? item['it_word'] ?? item['title'] ?? '').toString().trim();
    final bn = (item['bn'] ?? item['bangla'] ?? item['bn_meaning'] ?? item['definition'] ?? item['desc_bn'] ?? item['meaning'] ?? '').toString().trim();
    final source = (item['source'] ?? item['target_type'] ?? 'Dizionario Patente').toString();
    final rawImage = (item['image'] ?? item['image_url'] ?? item['cover_image'] ?? '').toString();
    final imageUrl = ApiService.formatImageUrl(rawImage);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Word Details & Buttons
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Line: Word Badge + TTS Speaker + Source Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Gold / Yellow Word Badge matching Screenshot
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE047),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        word.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF713F12),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Speaker TTS Button
                    InkWell(
                      onTap: () => _speakItalian(word),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volume_up_rounded, size: 15, color: Color(0xFF0284C7)),
                      ),
                    ),
                    const Spacer(),
                    // Source Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        source,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bangla Meaning in Green matching screenshot
                Text(
                  '→ $bn',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(height: 12),

                // Blue Action Button: [এই এমসিকিউ পেজে যান ↗]
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToTarget(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 13),
                    label: const Text(
                      'এই এমসিকিউ পেজে যান',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right: Image Thumbnail if present
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => ImageZoomDialog.show(context, imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
