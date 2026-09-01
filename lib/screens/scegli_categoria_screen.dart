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
  final Widget diagram;
  int correct;
  int errors;
  int total;
  bool isSelected;

  PatenteCategory({
    required this.id,
    required this.title,
    required this.diagram,
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
  List<PatenteCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    QuestionDatabase.initialize();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoading = true;
    });
    final apiChapters = await ApiService.fetchChapters();
    if (mounted) {
      if (apiChapters.isNotEmpty) {
        setState(() {
          _categories = apiChapters.map((ch) {
            final id = ch['id'] is int ? ch['id'] as int : int.tryParse('${ch['id']}') ?? 1;
            final titleStr = (ch['name'] ?? ch['title'] ?? 'Capitolo $id').toString();
            final total = ch['questions_count'] ?? ch['question_count'] ?? ch['totale'] ?? 0;
            final imgPath = (ch['cover_image'] ?? ch['image'] ?? '').toString();
            final fullImgUrl = ApiService.formatImageUrl(imgPath);
            final chapNum = ch['chapter_number'] ?? id;

            return PatenteCategory(
              id: id,
              title: '$chapNum) ${titleStr.toUpperCase()}',
              diagram: fullImgUrl.isNotEmpty
                  ? _buildNetworkImageDiagram(fullImgUrl)
                  : _buildChapterDiagram(id),
              correct: ch['corrette'] ?? 0,
              errors: ch['errori'] ?? 0,
              total: total > 0 ? total : 0,
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _categories = [];
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildNetworkImageDiagram(String url) {
    return Container(
      height: 140,
      width: double.infinity,
      alignment: Alignment.center,
      color: Colors.transparent,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.school_rounded, size: 48, color: Colors.purple)),
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

  Widget _buildChapterDiagram(int chapterId) {
    if (chapterId == 1) {
      return _buildRoadLayoutDiagram();
    } else if (chapterId == 2) {
      return _buildDangerSignsDiagram();
    } else {
      return _buildGenericChapterDiagram(chapterId);
    }
  }

  Widget _buildGenericChapterDiagram(int chapterId) {
    IconData icon;
    Color color;
    switch (chapterId % 6) {
      case 0:
        icon = Icons.traffic_rounded;
        color = Colors.blue;
        break;
      case 1:
        icon = Icons.warning_amber_rounded;
        color = Colors.red;
        break;
      case 2:
        icon = Icons.directions_car_rounded;
        color = Colors.green;
        break;
      case 3:
        icon = Icons.assignment_rounded;
        color = Colors.orange;
        break;
      case 4:
        icon = Icons.school_rounded;
        color = Colors.purple;
        break;
      default:
        icon = Icons.verified_user_rounded;
        color = Colors.teal;
    }
    return Container(
      height: 140,
      color: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: 8),
            Text(
              'Capitolo $chapterId',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadLayoutDiagram() {
    return Container(
      height: 140,
      color: Colors.transparent,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Text(
            'LA STRADA',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.blue),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildRoadSection('MARCIAPIEDE', Colors.grey.shade400, 24),
              const SizedBox(width: 4),
              _buildRoadSection('PISTA\nCICLABILE', Colors.green.shade400, 26),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 75,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (index) => Container(width: 10, height: 2, color: Colors.white60)),
                        ),
                      ),
                      Positioned(
                        left: 10, top: 12,
                        child: Container(width: 22, height: 12, decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(3))),
                      ),
                      Positioned(
                        right: 10, bottom: 12,
                        child: Container(width: 22, height: 12, decoration: BoxDecoration(color: Colors.blue.shade400, borderRadius: BorderRadius.circular(3))),
                      ),
                      const Positioned(
                        bottom: 4,
                        child: Text(
                          'CARREGGIATA',
                          style: TextStyle(fontSize: 7.5, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildRoadSection('BANCHINA', Colors.grey.shade400, 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoadSection(String label, Color color, double width) {
    return Container(
      width: width,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(2),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 5.5, fontWeight: FontWeight.w900, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDangerSignsDiagram() {
    return Container(
      height: 140,
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 8,
            child: Text(
              'SEGNALI DI PERICOLO',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.red),
            ),
          ),
          Positioned(
            left: 20, bottom: 16,
            child: _buildTriangleSign(Icons.navigation_rounded),
          ),
          Positioned(
            bottom: 16,
            child: _buildTriangleSign(Icons.train_rounded),
          ),
          Positioned(
            right: 20, bottom: 16,
            child: _buildTriangleSign(Icons.warning_amber_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTriangleSign(IconData icon) {
    return CustomPaint(
      size: const Size(54, 46),
      painter: _TriangleSignPainter(),
      child: SizedBox(
        width: 54,
        height: 46,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Icon(icon, size: 18, color: Colors.black),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARGOMENTI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  // Sub-header Row matching Screenshot 2: "Tutti i Capitoli" & "25 Capitoli"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tutti i Capitoli',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '${_categories.length} Capitoli',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action buttons (Unselect All, Select [hidden when active], Select All)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _unselectAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Unselect All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (!_isSelectActive) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _activateSelectMode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                              foregroundColor: isDark ? Colors.white70 : Colors.black87,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Select', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Select All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Categories List matching Screenshots 2 & 3
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
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

          // Floating Action Button MCQ >
          Positioned(
            bottom: 24,
            right: 24,
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
            color: Colors.black.withOpacity(0.02),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Image/Diagram Block
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: cat.diagram,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriangleSignPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 4)
      ..lineTo(4, size.height - 4)
      ..lineTo(size.width - 4, size.height - 4)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
