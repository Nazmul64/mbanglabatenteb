import 'package:flutter/material.dart';
import 'triangle_pattern_painter.dart';
import 'quiz_practice_screen.dart';
import 'instant_correction_dialog.dart';
import '../models/mcq_question.dart';
import '../services/api_service.dart';

class SubTopic {
  final int pageId;
  final String title;
  final int total;
  int correct;
  int errors;
  int unanswered;
  bool isSelected;

  SubTopic({
    this.pageId = 1,
    required this.title,
    required this.total,
    this.correct = 0,
    this.errors = 0,
    this.isSelected = false,
  }) : unanswered = (total - (correct + errors)).clamp(0, total);

  void reset() {
    correct = 0;
    errors = 0;
    unanswered = total;
  }

  void completeAll() {
    correct = total;
    errors = 0;
    unanswered = 0;
  }
}

class ScegliSchedaScreen extends StatefulWidget {
  final int? initialChapterId;

  const ScegliSchedaScreen({
    super.key,
    this.initialChapterId,
  });

  @override
  State<ScegliSchedaScreen> createState() => _ScegliSchedaScreenState();
}

class _ScegliSchedaScreenState extends State<ScegliSchedaScreen> {
  late String _selectedCategory;
  late List<String> _categories;
  final Map<String, int> _chapterIdMap = {};
  final Map<String, List<SubTopic>> _subtopicsCache = {};
  bool _isLoadingPages = false;

  @override
  void initState() {
    super.initState();
    _categories = [];
    _selectedCategory = 'Caricamento...';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingPages = true;
    });

    final apiChapters = await ApiService.fetchChapters();
    if (mounted) {
      if (apiChapters.isNotEmpty) {
        _categories = apiChapters.map((ch) {
          final id = ch['id'] is int ? ch['id'] as int : int.tryParse('${ch['id']}') ?? 1;
          final chapNum = ch['chapter_number'] ?? id;
          final name = (ch['name'] ?? ch['title'] ?? 'Capitolo $id').toString().toUpperCase();
          final key = '$chapNum) $name';
          _chapterIdMap[key] = id;
          return key;
        }).toList();

        if (widget.initialChapterId != null) {
          final found = apiChapters.firstWhere(
            (c) => c['id'] == widget.initialChapterId || c['chapter_number'] == widget.initialChapterId,
            orElse: () => apiChapters.first,
          );
          final id = found['id'] is int ? found['id'] as int : int.tryParse('${found['id']}') ?? 1;
          final chapNum = found['chapter_number'] ?? id;
          final name = (found['name'] ?? found['title'] ?? 'Capitolo $id').toString().toUpperCase();
          _selectedCategory = '$chapNum) $name';
          _chapterIdMap[_selectedCategory] = id;
        } else {
          _selectedCategory = _categories.first;
        }
      } else {
        _categories = [];
        _selectedCategory = 'Nessun Capitolo Trovato';
      }
    }

    if (_categories.isNotEmpty) {
      await _loadApiPagesForSelectedCategory();
    } else {
      setState(() {
        _isLoadingPages = false;
      });
    }
  }

  Future<void> _loadApiPagesForSelectedCategory() async {
    int chapterId = _chapterIdMap[_selectedCategory] ?? widget.initialChapterId ?? 1;
    if (chapterId == 1 && _selectedCategory.contains(')')) {
      final match = RegExp(r'^(\d+)\)').firstMatch(_selectedCategory);
      if (match != null) {
        chapterId = int.tryParse(match.group(1)!) ?? chapterId;
      }
    }

    setState(() {
      _isLoadingPages = true;
    });

    final apiPages = await ApiService.fetchChapterPages(chapterId);
    if (mounted) {
      final List<SubTopic> loadedList = [];
      if (apiPages.isNotEmpty) {
        for (var i = 0; i < apiPages.length; i++) {
          final p = apiPages[i];
          final pId = p['id'] is int ? p['id'] as int : int.tryParse('${p['id']}') ?? (i + 1);
          final titleStr = (p['title'] ?? 'Pagina ${i + 1}').toString();
          final total = p['questions_count'] ?? p['question_count'] ?? p['totale'] ?? 0;
          final pageNum = p['sort_order'] ?? p['page_number'] ?? (i + 1);
          loadedList.add(SubTopic(
            pageId: pId,
            title: '$pageNum) $titleStr',
            total: total > 0 ? total : 0,
            correct: p['corrette'] ?? 0,
            errors: p['errori'] ?? 0,
          ));
        }
      }
      setState(() {
        _subtopicsCache[_selectedCategory] = loadedList;
        _isLoadingPages = false;
      });
    }
  }

  List<SubTopic> _getCurrentSubtopics() {
    return _subtopicsCache[_selectedCategory] ?? [];
  }

  bool _isSelectActive = false;

  void _unselectAll() {
    setState(() {
      _isSelectActive = false;
      for (var sub in _getCurrentSubtopics()) {
        sub.isSelected = false;
      }
    });
  }

  void _onSelectButtonPressed() {
    setState(() {
      _isSelectActive = true;
      for (var sub in _getCurrentSubtopics()) {
        sub.isSelected = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _isSelectActive = true;
      for (var sub in _getCurrentSubtopics()) {
        sub.isSelected = true;
      }
    });
  }

  Future<void> _startSelectedQuiz() async {
    final currentSubtopics = _getCurrentSubtopics();
    if (currentSubtopics.isEmpty) return;

    var selectedSubs = currentSubtopics.where((s) => s.isSelected).toList();
    if (selectedSubs.isEmpty) {
      selectedSubs = currentSubtopics;
    }

    setState(() {
      _isLoadingPages = true;
    });

    List<McqQuestion> allQuestions = [];
    for (var sub in selectedSubs) {
      final pageDetails = await ApiService.fetchPageDetails(sub.pageId);
      if (pageDetails != null && pageDetails['questions'] is List) {
        final qList = (pageDetails['questions'] as List).map((q) => McqQuestion.fromJson(q)).toList();
        allQuestions.addAll(qList);
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingPages = false;
      });

      if (allQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('সিলেক্ট করা পেজে কোনো প্রশ্ন পাওয়া যায়নি')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => InstantCorrectionDialog(
          onSelection: (instantCorrection) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuizPracticeScreen(
                  questions: allQuestions,
                  quizTitle: _selectedCategory,
                ),
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentSubtopics = _getCurrentSubtopics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scegli Scheda'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 8),
        child: ElevatedButton(
          onPressed: _startSelectedQuiz,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 6,
            shadowColor: Colors.black38,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.quiz_rounded, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'MCQ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background triangles pattern
          Positioned.fill(
            child: CustomPaint(
              painter: TrianglePatternPainter(
                triangleColor: isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.blue.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dropdown selection category card
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.blue, size: 30),
                          items: _categories.map((String cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(
                                cat,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCategory = val;
                              });
                              _loadApiPagesForSelectedCategory();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Three buttons: Unselect All, Select, Select All
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _unselectAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Unselect All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (!_isSelectActive) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _onSelectButtonPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                              foregroundColor: isDark ? Colors.white70 : Colors.black87,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('Select', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                            foregroundColor: const Color(0xFF22C55E),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Select All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Subtopic Progress Card list
                  Expanded(
                    child: _isLoadingPages
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: currentSubtopics.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final sub = currentSubtopics[index];
                              return _buildSubtopicCard(sub, isDark);
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

  Widget _buildSubtopicCard(SubTopic sub, bool isDark) {
    int totalVal = sub.total;
    int correctVal = sub.correct;
    int errorsVal = sub.errors;
    int unansweredVal = sub.unanswered;

    double correctShare = totalVal > 0 ? correctVal / totalVal : 0.0;
    double errorShare = totalVal > 0 ? errorsVal / totalVal : 0.0;
    double unansweredShare = totalVal > 0 ? unansweredVal / totalVal : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      elevation: sub.isSelected ? 2 : 0,
      color: sub.isSelected
          ? (isDark ? const Color(0xFF163224) : const Color(0xFFF0FDF4))
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: sub.isSelected ? const Color(0xFF22C55E) : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
          width: sub.isSelected ? 2.0 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: () async {
          if (_isSelectActive || _getCurrentSubtopics().any((s) => s.isSelected)) {
            setState(() {
              sub.isSelected = !sub.isSelected;
              _isSelectActive = _getCurrentSubtopics().any((s) => s.isSelected);
            });
            return;
          }
          setState(() {
            _isLoadingPages = true;
          });
          final pageDetails = await ApiService.fetchPageDetails(sub.pageId);
          List<McqQuestion> questions = [];
          if (pageDetails != null && pageDetails['questions'] is List) {
            questions = (pageDetails['questions'] as List).map((q) => McqQuestion.fromJson(q)).toList();
          }

          if (mounted) {
            setState(() {
              _isLoadingPages = false;
            });

            if (questions.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('এই পেজে কোনো MCQ প্রশ্ন যুক্ত করা হয়নি')),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuizPracticeScreen(
                  questions: questions,
                  quizTitle: sub.title,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtopic Title with selection checkmark / chevron
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sub.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: sub.isSelected ? const Color(0xFF16A34A) : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        sub.isSelected = !sub.isSelected;
                        _isSelectActive = _getCurrentSubtopics().any((s) => s.isSelected);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: sub.isSelected ? Colors.green.withOpacity(0.15) : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        sub.isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                        size: 20,
                        color: sub.isSelected ? Colors.green : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats and progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatText('Corrette: ', '$correctVal', const Color(0xFF4CAF50)),
                      _buildStatText('Errori: ', '$errorsVal', const Color(0xFFEF4444)),
                      _buildStatText('Non risposte: ', '$unansweredVal', const Color(0xFFF59E0B)),
                      _buildStatText('Totale: ', '$totalVal', isDark ? Colors.white70 : Colors.black87),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Multi-segment progress bar (green, red, amber, background)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 8,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      child: Row(
                        children: [
                          if (correctShare > 0)
                            Expanded(
                              flex: (correctShare * 1000).round(),
                              child: Container(color: const Color(0xFF4CAF50)),
                            ),
                          if (errorShare > 0)
                            Expanded(
                              flex: (errorShare * 1000).round(),
                              child: Container(color: const Color(0xFFEF4444)),
                            ),
                          if (unansweredShare > 0)
                            Expanded(
                              flex: (unansweredShare * 1000).round(),
                              child: Container(color: const Color(0xFFF59E0B)),
                            ),
                          if (totalVal == 0)
                            Expanded(
                              child: Container(color: Colors.transparent),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatText(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11),
        children: [
          TextSpan(text: label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          TextSpan(text: value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

