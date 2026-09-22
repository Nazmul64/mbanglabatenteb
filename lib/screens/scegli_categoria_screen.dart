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
    final formatted = ApiService.formatImageUrl(url);
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
