import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'google_translate_dialog.dart';

class ManualeScreen extends StatefulWidget {
  const ManualeScreen({super.key});

  @override
  State<ManualeScreen> createState() => _ManualeScreenState();
}

class _ManualeScreenState extends State<ManualeScreen> {
  List<dynamic> _topics = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoading = true;
    });
    final topics = await ApiService.fetchManualeChapters();
    if (mounted) {
      setState(() {
        _topics = topics;
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredTopics {
    if (_searchQuery.trim().isEmpty) return _topics;
    final q = _searchQuery.toLowerCase().trim();
    return _topics.where((t) {
      final title = (t['title'] ?? t['name'] ?? '').toString().toLowerCase();
      final content = (t['content'] ?? '').toString().toLowerCase();
      return title.contains(q) || content.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MANUALE (ম্যানুয়াল থিওরি বই)'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'থিওরি বা চ্যাপ্টার খুঁজুন...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Topics List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTopics.isEmpty
                      ? const Center(
                          child: Text(
                            'কোনো ম্যানুয়াল থিওরি পাওয়া যায়নি।',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadTopics,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredTopics.length,
                            itemBuilder: (context, index) {
                              final item = _filteredTopics[index];
                              final id = item['id'] ?? index + 1;
                              final chapNum = item['chapter_number'] ?? item['sort_order'] ?? id;
                              final title = (item['title'] ?? item['name'] ?? 'Capitolo $chapNum').toString();
                              final content = (item['content'] ?? 'Nessuna spiegazione teorica inserita.').toString();
                              final rawImg = (item['image_path'] ?? item['image'] ?? '').toString();
                              final fullImgUrl = ApiService.formatImageUrl(rawImg);

                              List<dynamic> vocabs = item['vocabulary'] ?? [];
                              if (vocabs is String) {
                                vocabs = [];
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
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
                                    // Header Badge & Title
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$chapNum',
                                              style: const TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'CAPITOLO $chapNum',
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // Theory Illustration Image (Top)
                                    if (fullImgUrl.isNotEmpty) ...[
                                      Container(
                                        width: double.infinity,
                                        constraints: const BoxConstraints(maxHeight: 280),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            fullImgUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],

                                    // Theory Content / Explanation Box
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        content.replaceAll(RegExp(r'</?u>'), ''),
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.6,
                                          color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                        ),
                                      ),
                                    ),

                                    // Question Vocabulary Underlines Section
                                    if (vocabs.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          const Icon(Icons.spellcheck_rounded, color: Colors.blue, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Vocabolario & Traduzioni (${vocabs.length})',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: vocabs.length,
                                        itemBuilder: (context, idx) {
                                          final v = vocabs[idx];
                                          final word = (v['italian'] ?? v['word'] ?? '').toString();
                                          final meaning = (v['bangla'] ?? v['meaning'] ?? '').toString();
                                          final vRawImg = (v['image'] ?? '').toString();
                                          final vImgUrl = ApiService.formatImageUrl(vRawImg);

                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 0,
                                            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                                            child: ListTile(
                                              dense: true,
                                              leading: vImgUrl.isNotEmpty
                                                  ? ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Image.network(vImgUrl, width: 36, height: 36, fit: BoxFit.contain),
                                                    )
                                                  : Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(Icons.translate_rounded, color: Colors.blue, size: 18),
                                                    ),
                                              title: Text(word, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              subtitle: Text(meaning, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => GoogleTranslateDialog(
                                                    italianText: word,
                                                    localTranslation: meaning,
                                                    imageUrl: vImgUrl.isNotEmpty ? vImgUrl : null,
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManualeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> topicData;

  const ManualeDetailScreen({super.key, required this.topicData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chapNum = topicData['chapter_number'] ?? topicData['id'] ?? 1;
    final title = (topicData['title'] ?? topicData['name'] ?? 'Capitolo $chapNum').toString();
    final content = (topicData['content'] ?? 'Nessuna spiegazione teorica inserita.').toString();
    final rawImg = (topicData['image_path'] ?? topicData['image'] ?? '').toString();
    final fullImgUrl = ApiService.formatImageUrl(rawImg);

    List<dynamic> vocabs = topicData['vocabulary'] ?? [];
    if (vocabs is String) {
      vocabs = [];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Capitolo $chapNum'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chapter Label
              Text(
                'CAPITOLO $chapNum',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Main Illustration Image
              if (fullImgUrl.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 260),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      fullImgUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Content Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  content.replaceAll(RegExp(r'</?u>'), ''),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Vocabulary Cards List
              if (vocabs.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.spellcheck_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Vocabolario & Traduzioni (${vocabs.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vocabs.length,
                  itemBuilder: (context, idx) {
                    final v = vocabs[idx];
                    final word = (v['italian'] ?? v['word'] ?? '').toString();
                    final meaning = (v['bangla'] ?? v['meaning'] ?? '').toString();
                    final vRawImg = (v['image'] ?? '').toString();
                    final vImgUrl = ApiService.formatImageUrl(vRawImg);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      child: ListTile(
                        leading: vImgUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(vImgUrl, width: 40, height: 40, fit: BoxFit.contain),
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.translate_rounded, color: Colors.blue, size: 20),
                              ),
                        title: Text(word, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(meaning, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => GoogleTranslateDialog(
                              italianText: word,
                              localTranslation: meaning,
                              imageUrl: vImgUrl.isNotEmpty ? vImgUrl : null,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
