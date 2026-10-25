import 'package:flutter/material.dart';
import 'triangle_pattern_painter.dart';
import 'scegli_scheda_screen.dart';
import 'exam_simulation_screen.dart';
import '../models/question_database.dart';
import '../models/mcq_question.dart';
import '../services/api_service.dart';

class PatenteCategory {
  final int id;
  final String title;
  final Widget? diagram;
  int correct;
  int errors;
  int total;
  bool isSelected;

  PatenteCategory({
    required this.id,
    required this.title,
    this.diagram,
    this.correct = 0,
    this.errors = 0,
    required this.total,
    this.isSelected = false,
  });

  int get unanswered => (total - (correct + errors)).clamp(0, total);
}

class ScegliCategoriaScreen extends StatefulWidget {
  const ScegliCategoriaScreen({super.key});

  @override
  State<ScegliCategoriaScreen> createState() => _ScegliCategoriaScreenState();
}

class _ScegliCategoriaScreenState extends State<ScegliCategoriaScreen> {
  static List<PatenteCategory> _cachedCategories = [];
  List<PatenteCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (_cachedCategories.isNotEmpty) {
      _categories = List.from(_cachedCategories);
      _isLoading = false;
    }
    QuestionDatabase.initialize();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    if (_categories.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final apiChapters = await ApiService.fetchChapters();
      if (mounted && apiChapters.isNotEmpty) {
        final parsed = apiChapters.map((ch) {
          final id = ch['id'] is int ? ch['id'] as int : int.tryParse('${ch['id']}') ?? 1;
          final titleStr = (ch['name'] ?? ch['title'] ?? 'Capitolo $id').toString();
          final total = ch['questions_count'] ?? ch['question_count'] ?? ch['totale'] ?? 0;
          String imgPath = '';
          for (final k in ['cover_image', 'image', 'image_path', 'thumbnail', 'img', 'photo', 'icon', 'picture']) {
            final val = ch[k]?.toString().trim();
            if (val != null && val.isNotEmpty && val.toLowerCase() != 'null' && val.toLowerCase() != 'undefined') {
              imgPath = val;
              break;
            }
          }
          final fullImgUrl = ApiService.formatImageUrl(imgPath);
          final chapNum = ch['chapter_number'] ?? id;

          return PatenteCategory(
            id: id,
            title: '$chapNum) ${titleStr.toUpperCase()}',
            diagram: fullImgUrl.isNotEmpty
                ? _buildNetworkImageDiagram(fullImgUrl)
                : null,
            correct: ch['corrette'] ?? 0,
            errors: ch['errori'] ?? 0,
            total: total > 0 ? total : 0,
          );
        }).toList();

        _cachedCategories = List.from(parsed);
        setState(() {
          _categories = parsed;
        });
      }
    } catch (e) {
      debugPrint('Error loading chapters: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildNetworkImageDiagram(String url) {
    final formatted = ApiService.formatImageUrl(url);
    if (formatted.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 140,
      width: double.infinity,
      alignment: Alignment.center,
      color: Colors.transparent,
      child: Image.network(
        formatted,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
      ),
    );
  }

  bool _isSelectActive = false;

  void _unselectAll() {
    setState(() {
      _isSelectActive = false;
      for (var cat in _categories) {
        cat.isSelected = false;
      }
    });
  }

  void _activateSelectMode() {
    setState(() {
      _isSelectActive = true;
    });
  }

  void _selectAll() {
    setState(() {
      _isSelectActive = true;
      for (var cat in _categories) {
        cat.isSelected = true;
      }
    });
  }

  int get _selectedCount => _categories.where((c) => c.isSelected).length;

  Future<void> _startSelectedQuiz() async {
    var selectedChapterIds = _categories.where((c) => c.isSelected).map((c) => c.id).toList();
    if (selectedChapterIds.isEmpty) {
      selectedChapterIds = _categories.map((c) => c.id).toList();
    }

    setState(() {
      _isLoading = true;
    });

    List<McqQuestion> allQuestions = [];
    try {
      final pagesLists = await Future.wait(
        selectedChapterIds.map((chId) => ApiService.fetchChapterPages(chId)),
      );

      final pageDetailFutures = <Future<Map<String, dynamic>?>>[];
      for (final pages in pagesLists) {
        for (final p in pages) {
          final pId = p['id'] is int ? p['id'] as int : int.tryParse('${p['id']}') ?? 1;
          pageDetailFutures.add(ApiService.fetchPageDetails(pId));
        }
      }

      final pageDetailsList = await Future.wait(pageDetailFutures);
      for (final details in pageDetailsList) {
        if (details != null && details['questions'] is List) {
          final qList = (details['questions'] as List).map((q) => McqQuestion.fromJson(q)).toList();
          allQuestions.addAll(qList);
        }
      }
    } catch (e) {
      debugPrint('Error starting quiz: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (allQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('সিলেক্ট করা অংশে কোনো এমসিকিউ প্রশ্ন পাওয়া যায়নি')),
        );
        return;
      }

      if (allQuestions.length > 30) {
        allQuestions.shuffle();
        allQuestions = allQuestions.take(30).toList();
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExamSimulationScreen(
            customQuestions: allQuestions,
            examTitle: 'Argomenti Test (${allQuestions.length} Quesiti)',
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
      appBar: AppBar(
        title: const Text('Scegli Categoria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 4),
        child: ElevatedButton(
          onPressed: _startSelectedQuiz,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
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
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white, letterSpacing: 0.5),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Action buttons (Unselect All, Select [hidden when active], Select All)
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Unselect All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (!_isSelectActive) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _activateSelectMode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                              foregroundColor: isDark ? Colors.white70 : Colors.black87,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Select All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Categories List matching Screenshot 1
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: _categories.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              return _buildCategoryCard(cat, isDark);
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

  Widget _buildCategoryCard(PatenteCategory cat, bool isDark) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: cat.isSelected
            ? (isDark ? const Color(0xFF132A24) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cat.isSelected ? const Color(0xFF22C55E) : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
          width: cat.isSelected ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectActive) {
            setState(() {
              cat.isSelected = !cat.isSelected;
            });
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScegliSchedaScreen(initialChapterId: cat.id),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Chapter Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cat.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Image/Diagram Block (only if an image is uploaded)
              if (cat.diagram != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: cat.diagram!,
                ),
              ],
              const SizedBox(height: 14),

              // Progresso Title (Centered)
              Center(
                child: Text(
                  'Progresso',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 4 Stat Columns: Corrette, Errori, Non risposte, Totale
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn('Corrette', '${cat.correct}', const Color(0xFF4CAF50), isDark),
                  _buildStatColumn('Errori', '${cat.errors}', const Color(0xFFEF4444), isDark),
                  _buildStatColumn('Non risposte', '${cat.unanswered}', isDark ? Colors.white70 : Colors.black87, isDark),
                  _buildStatColumn('Totale', '${cat.total}', isDark ? Colors.white70 : Colors.black87, isDark),
                ],
              ),
              const SizedBox(height: 10),

              // Multi-Color Progress Bar
              _buildMultiColorProgressBar(
                correct: cat.correct,
                errors: cat.errors,
                total: cat.total,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildMultiColorProgressBar({
    required int correct,
    required int errors,
    required int total,
    required bool isDark,
  }) {
    final totalVal = total > 0 ? total : 0;
    final correctVal = correct.clamp(0, totalVal);
    final errorsVal = errors.clamp(0, totalVal);
    final unansweredVal = (totalVal - (correctVal + errorsVal)).clamp(0, totalVal);

    final double correctFlex = totalVal > 0 ? (correctVal / totalVal) : 0.0;
    final double errorFlex = totalVal > 0 ? (errorsVal / totalVal) : 0.0;
    final double unansweredFlex = totalVal > 0 ? (unansweredVal / totalVal) : 1.0;

    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Row(
          children: [
            if (correctVal > 0)
              Expanded(
                flex: (correctFlex * 1000).round(),
                child: Container(
                  color: const Color(0xFF4CAF50),
                ),
              ),
            if (errorsVal > 0)
              Expanded(
                flex: (errorFlex * 1000).round(),
                child: Container(
                  color: const Color(0xFFEF4444),
                ),
              ),
            if (unansweredVal > 0 || totalVal == 0)
              Expanded(
                flex: totalVal > 0 ? (unansweredFlex * 1000).round() : 1000,
                child: Container(
                  color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

