import 'package:flutter/material.dart';
import 'triangle_pattern_painter.dart';
import 'google_translate_dialog.dart';
import '../services/html_text_helper.dart';
import '../models/question_database.dart';

class ExamResultItem {
  final int index;
  final String italian;
  final String bangla;
  final bool isVero;
  final bool? userSelectedVero;
  final String chapterName;

  ExamResultItem({
    required this.index,
    required this.italian,
    required this.bangla,
    required this.isVero,
    required this.userSelectedVero,
    required this.chapterName,
  });

  bool get isAttempted => userSelectedVero != null;
  bool get isCorrect => userSelectedVero == isVero;
}

class ExamResultScreen extends StatefulWidget {
  final List<ExamResultItem> results;
  final int durationSeconds;

  const ExamResultScreen({
    super.key,
    required this.results,
    required this.durationSeconds,
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  String _filterMode = 'all'; // 'all', 'correct', 'error', 'no_response'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final total = widget.results.length;
    final attempted = widget.results.where((r) => r.isAttempted).length;
    final correct = widget.results.where((r) => r.isAttempted && r.isCorrect).length;
    final incorrect = widget.results.where((r) => r.isAttempted && !r.isCorrect).length;
    final noResponse = widget.results.where((r) => !r.isAttempted).length;

    final bool isPassed = incorrect <= 3;
    final double scorePercent = total > 0 ? (correct / total) * 100 : 0;
    final minutes = widget.durationSeconds ~/ 60;
    final seconds = widget.durationSeconds % 60;

    List<ExamResultItem> filteredList = widget.results;
    if (_filterMode == 'correct') {
      filteredList = widget.results.where((r) => r.isAttempted && r.isCorrect).toList();
    } else if (_filterMode == 'error') {
      filteredList = widget.results.where((r) => r.isAttempted && !r.isCorrect).toList();
    } else if (_filterMode == 'no_response') {
      filteredList = widget.results.where((r) => !r.isAttempted).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risultato del Test', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Result Status Card (Matching Screenshot 2)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E294B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('🥰', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        Text(
                          isPassed ? 'Idoneo (Pass)' : 'Bocciato (Fail)',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isPassed ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Result: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                            Text(isPassed ? 'Pass ✔' : 'Fail ✘', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isPassed ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Score: ${scorePercent.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Tempo: $minutes minuti $seconds secondi',
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. 5 Summary Metric Boxes (Matching Screenshot 2)
                  Row(
                    children: [
                      _buildMetricCard('TOTAL QUESTIONS', '$total', Colors.blue, isDark),
                      _buildMetricCard('ATTEMPTED', '$attempted', Colors.teal, isDark),
                      _buildMetricCard('CORRECT', '$correct', const Color(0xFF22C55E), isDark),
                      _buildMetricCard('INCORRECT', '$incorrect', const Color(0xFFEF4444), isDark),
                      _buildMetricCard('NO RESPONSE', '$noResponse', const Color(0xFFF59E0B), isDark),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Yellow accent bar
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Topic Performance Analysis Header
                  Row(
                    children: [
                      const Icon(Icons.language_rounded, size: 18, color: Color(0xFF22C55E)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Analisi delle prestazioni per argomento (টপিক পারফরম্যান্স বিশ্লেষণ)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Filter Pill Badges (Matching Screenshot 3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() => _filterMode = 'all'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _filterMode == 'all' ? const Color(0xFF1E294B) : (isDark ? Colors.white10 : Colors.grey.shade100),
                          foregroundColor: _filterMode == 'all' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text('Mostra tutte', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      _buildFilterBadge('Corrette: $correct', const Color(0xFF22C55E), 'correct', isDark),
                      _buildFilterBadge('Errori: $incorrect', const Color(0xFFEF4444), 'error', isDark),
                      _buildFilterBadge('Non risposte: $noResponse', const Color(0xFFF59E0B), 'no_response', isDark),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 5. Questions Detailed List (Matching Screenshot 3)
                  Column(
                    children: filteredList.map((item) => _buildQuestionResultCard(item, isDark)).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E294B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 6.5, fontWeight: FontWeight.w900, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBadge(String label, Color color, String mode, bool isDark) {
    bool isSelected = _filterMode == mode;
    return InkWell(
      onTap: () => setState(() => _filterMode = mode),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? color : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildQuestionResultCard(ExamResultItem item, bool isDark) {
    Color cardColor;
    String statusText;
    Color statusColor;

    if (!item.isAttempted) {
      cardColor = const Color(0xFFF59E0B);
      statusText = 'No Response';
      statusColor = const Color(0xFFF59E0B);
    } else if (item.isCorrect) {
      cardColor = const Color(0xFF22C55E);
      statusText = 'Corretto';
      statusColor = const Color(0xFF16A34A);
    } else {
      cardColor = const Color(0xFFEF4444);
      statusText = 'Errore';
      statusColor = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E294B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardColor,
          width: 2.0,
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
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header: Domanda #N & Status Badge (Matching Screenshot 3)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Domanda #${item.index}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        !item.isAttempted
                            ? Icons.info_outline_rounded
                            : (item.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded),
                        size: 10,
                        color: statusColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Italian Question Statement with Underlined Vocabulary Tap
            RichText(
              text: TextSpan(
                children: _buildUnderlinedStatement(item.italian, isDark),
              ),
            ),
            const SizedBox(height: 14),

            // Option Boxes: VERO (True) & FALSO (False) (Matching Screenshot 3)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: item.isVero
                          ? const Color(0xFF22C55E).withOpacity(0.1)
                          : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.isVero ? const Color(0xFF22C55E) : Colors.grey.shade300,
                        width: item.isVero ? 2.0 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'VERO (True)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: item.isVero ? const Color(0xFF16A34A) : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        if (item.isVero) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !item.isVero
                          ? const Color(0xFF22C55E).withOpacity(0.1)
                          : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !item.isVero ? const Color(0xFF22C55E) : Colors.grey.shade300,
                        width: !item.isVero ? 2.0 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'FALSO (False)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: !item.isVero ? const Color(0xFF16A34A) : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        if (!item.isVero) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Answer Result Details Footer (Matching Screenshot 3)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risposta Corretta: ${item.isVero ? "V" : "F"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '(TU) Hai risposto: ${!item.isAttempted ? "Non hai risposto (No Response)" : (item.userSelectedVero! ? "Vero" : "Falso")}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: !item.isAttempted
                          ? const Color(0xFFF59E0B)
                          : (item.isCorrect ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _buildUnderlinedStatement(String statement, bool isDark) {
    return HtmlTextHelper.buildParsedStatementSpans(
      statement: statement,
      isDark: isDark,
      fontSize: 13.0,
      onTapWord: (rawWord, cleanWord) {
        String translation = '';
        if (QuestionDatabase.globalGlossary.containsKey(cleanWord.toLowerCase())) {
          translation = QuestionDatabase.globalGlossary[cleanWord.toLowerCase()]!;
        }
        if (translation.isEmpty && QuestionDatabase.globalGlossary.containsKey(rawWord.toLowerCase())) {
          translation = QuestionDatabase.globalGlossary[rawWord.toLowerCase()]!;
        }

        showDialog(
          context: context,
          builder: (context) => GoogleTranslateDialog(
            italianText: rawWord.isNotEmpty ? rawWord : cleanWord,
            localTranslation: translation,
          ),
        );
      },
    );
  }
}
