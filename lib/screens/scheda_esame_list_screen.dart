import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'triangle_pattern_painter.dart';
import 'exam_simulation_screen.dart';
import 'instant_correction_dialog.dart';
import 'full_translate_dialog.dart';
import '../models/mcq_question.dart';
import '../services/api_service.dart';
import '../services/html_text_helper.dart';

class PassedExamSummary {
  final int id;
  final String studentName;
  final String? avatar;
  final String motorizzazione;
  final String examDate;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final int totalCount;
  final bool isPassed;

  PassedExamSummary({
    required this.id,
    required this.studentName,
    this.avatar,
    required this.motorizzazione,
    required this.examDate,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    this.totalCount = 30,
    this.isPassed = true,
  });

  factory PassedExamSummary.fromJson(Map<String, dynamic> json) {
    return PassedExamSummary(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      studentName: (json['student_name'] ?? json['name'] ?? 'Candidato Patente B').toString(),
      avatar: json['avatar']?.toString(),
      motorizzazione: (json['motorizzazione'] ?? json['city'] ?? 'Motorizzazione Civile').toString(),
      examDate: (json['exam_date'] ?? json['date'] ?? '').toString(),
      correctCount: json['correct_count'] is int ? json['correct_count'] as int : int.tryParse('${json['correct_count']}') ?? 27,
      wrongCount: json['wrong_count'] is int ? json['wrong_count'] as int : int.tryParse('${json['wrong_count']}') ?? 0,
      unansweredCount: json['unanswered_count'] is int ? json['unanswered_count'] as int : int.tryParse('${json['unanswered_count']}') ?? 0,
      totalCount: json['total_count'] is int ? json['total_count'] as int : int.tryParse('${json['total_count']}') ?? 30,
      isPassed: json['is_passed'] == true || json['is_passed'] == 1 || json['is_passed'] == '1',
    );
  }
}

class SchedaEsameListScreen extends StatefulWidget {
  const SchedaEsameListScreen({super.key});

  @override
  State<SchedaEsameListScreen> createState() => _SchedaEsameListScreenState();
}

class _SchedaEsameListScreenState extends State<SchedaEsameListScreen> {
  List<PassedExamSummary> _exams = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPassedExams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPassedExams() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rawList = await ApiService.fetchPassedExams(query: _searchQuery);
      const fakeNames = {
        'tanvir ahmed',
        'rashidul islam',
        'farhana akter',
        'md. nazmul hassan',
      };

      if (mounted) {
        setState(() {
          _exams = rawList.map((item) {
            if (item is Map) {
              return PassedExamSummary.fromJson(Map<String, dynamic>.from(item));
            }
            return PassedExamSummary(
              id: 0,
              studentName: '',
              motorizzazione: '',
              examDate: '',
              correctCount: 27,
              wrongCount: 3,
              unansweredCount: 0,
            );
          }).where((e) => e.id > 0 && e.studentName.trim().isNotEmpty && !fakeNames.contains(e.studentName.trim().toLowerCase())).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading passed exams: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openExamQuestions(PassedExamSummary exam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PassedExamQuestionsScreen(examSummary: exam),
      ),
    );
  }

  void _startNewExamSimulation() {
    showDialog(
      context: context,
      builder: (context) => InstantCorrectionDialog(
        onSelection: (instantCorrection) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ExamSimulationScreen(),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredExams = _exams.where((e) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.studentName.toLowerCase().contains(q) ||
          e.motorizzazione.toLowerCase().contains(q) ||
          e.id.toString().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Scheda Esame (Passed Sheets)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF22C55E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: TrianglePatternPainter(
                triangleColor: isDark
                    ? Colors.white.withOpacity(0.015)
                    : Colors.green.withOpacity(0.02),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top Header Info Card & New Exam Button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // "Start New Exam" Primary Button
                      ElevatedButton.icon(
                        onPressed: _startNewExamSimulation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                        label: const Text(
                          'Avvia Nuovo Esame (30 Quesiti)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cerca per nome candidato, centro o ID...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // List of Passed Candidates
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                          ),
                        )
                      : filteredExams.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.assignment_turned_in_rounded, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Nessuna scheda esame passata trovata',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Fai un test e ottieni 27+ risposte corrette per entrare nella lista!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadPassedExams,
                              color: const Color(0xFF22C55E),
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                                itemCount: filteredExams.length,
                                itemBuilder: (context, index) {
                                  final exam = filteredExams[index];
                                  return _buildExamCard(exam, isDark);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(PassedExamSummary exam, bool isDark) {
    final correctPercent = exam.totalCount > 0 ? ((exam.correctCount / exam.totalCount) * 100).round() : 90;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openExamQuestions(exam),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Avatar, Name, Passed Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Candidate Avatar with Green Checkmark Badge
                  Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF22C55E).withOpacity(0.12),
                          border: Border.all(
                            color: const Color(0xFF22C55E).withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: exam.avatar != null && exam.avatar!.trim().isNotEmpty
                              ? Image.network(
                                  ApiService.formatImageUrl(exam.avatar!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarFallback(exam.studentName),
                                )
                              : _buildAvatarFallback(exam.studentName),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Name and Motorizzazione
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                exam.studentName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '#${exam.id}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          exam.motorizzazione,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (exam.examDate.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Data esame: ${exam.examDate}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // IDONEO Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF22C55E)),
                        const SizedBox(width: 4),
                        Text(
                          '$correctPercent%',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Multi-color Progress Bar
              _buildScoreBar(
                correct: exam.correctCount,
                wrong: exam.wrongCount,
                unanswered: exam.unansweredCount,
                total: exam.totalCount,
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              // 4 Stat Counters: Corrette, Sbagliate, Non risposte, Totale
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatTag('Corrette', '${exam.correctCount}', const Color(0xFF22C55E)),
                  _buildStatTag('Sbagliate', '${exam.wrongCount}', const Color(0xFFEF4444)),
                  _buildStatTag('Non risposte', '${exam.unansweredCount}', const Color(0xFFF59E0B)),
                  _buildStatTag('Totale', '${exam.totalCount}', isDark ? Colors.white70 : Colors.black87),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
        : 'P';
    return Container(
      color: const Color(0xFF22C55E).withOpacity(0.15),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFF16A34A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBar({
    required int correct,
    required int wrong,
    required int unanswered,
    required int total,
    required bool isDark,
  }) {
    final totalVal = total > 0 ? total : 30;
    final cRatio = (correct / totalVal).clamp(0.0, 1.0);
    final wRatio = (wrong / totalVal).clamp(0.0, 1.0);
    final uRatio = (unanswered / totalVal).clamp(0.0, 1.0);

    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            if (cRatio > 0)
              Expanded(
                flex: (cRatio * 1000).round(),
                child: Container(color: const Color(0xFF22C55E)),
              ),
            if (wRatio > 0)
              Expanded(
                flex: (wRatio * 1000).round(),
                child: Container(color: const Color(0xFFEF4444)),
              ),
            if (uRatio > 0)
              Expanded(
                flex: (uRatio * 1000).round(),
                child: Container(color: const Color(0xFFF59E0B)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTag(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📌 DETAILED VIEW OF QUESTIONS IN A PASSED EXAM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class PassedExamQuestionItem {
  final int id;
  final int index;
  String italian;
  String bangla;
  final bool isVero;
  final String? userAnswer;
  final bool isUserCorrect;
  String? image;
  String? audio;
  List<dynamic>? vocabulary;
  bool isSelected;
  bool isRevealed;

  PassedExamQuestionItem({
    required this.id,
    required this.index,
    required this.italian,
    required this.bangla,
    required this.isVero,
    this.userAnswer,
    this.isUserCorrect = true,
    this.image,
    this.audio,
    this.vocabulary,
    this.isSelected = false,
    this.isRevealed = false,
  });
}

class PassedExamQuestionsScreen extends StatefulWidget {
  final PassedExamSummary examSummary;

  const PassedExamQuestionsScreen({
    super.key,
    required this.examSummary,
  });

  @override
  State<PassedExamQuestionsScreen> createState() => _PassedExamQuestionsScreenState();
}

class _PassedExamQuestionsScreenState extends State<PassedExamQuestionsScreen> {
  List<PassedExamQuestionItem> _questions = [];
  bool _isLoading = true;
  bool _isSelectMode = false;

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingIndex;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadQuestions();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _initAudio() {
    _flutterTts.setLanguage('it-IT');
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _playingIndex = null);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingIndex = null);
    });
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await ApiService.fetchExamSheetDetails(widget.examSummary.id);
      List rawList = [];
      if (details != null) {
        if (details['questions'] is List && (details['questions'] as List).isNotEmpty) {
          rawList = details['questions'] as List;
        } else if (details['answers'] is List && (details['answers'] as List).isNotEmpty) {
          rawList = details['answers'] as List;
        } else if (details['data'] is List && (details['data'] as List).isNotEmpty) {
          rawList = details['data'] as List;
        }
      }

      if (mounted) {
        setState(() {
          _questions = [];
          for (int i = 0; i < rawList.length; i++) {
            final q = rawList[i];
            if (q is Map) {
              final int qId = q['id'] is int ? q['id'] : int.tryParse('${q['id']}') ?? (i + 1);
              String statement = (q['italian'] ?? q['question'] ?? q['domanda'] ?? '').toString().trim();
              String bangla = (q['bangla'] ?? q['bn_question'] ?? q['translation'] ?? '').toString().trim();
              String? image = q['image']?.toString();
              String? audio = q['audio']?.toString() ?? q['voice']?.toString();
              List<dynamic>? vocab = q['vocabulary'] is List ? q['vocabulary'] : null;

              if (statement.isEmpty) {
                statement = 'Domanda n. ${i + 1} (Quiz Patente B)';
              }

              final rawIsVero = q['is_vero'] ?? q['correct_answer'];
              final isVero = (rawIsVero == 1 || rawIsVero == true || rawIsVero == '1' || strtolower(rawIsVero.toString()) == 'vero');
              final uAns = q['user_answer']?.toString();
              final isCorrect = q['is_correct'] == true || q['is_correct'] == 1 || (uAns != null && uAns.toUpperCase() == (isVero ? 'V' : 'F'));

              _questions.add(PassedExamQuestionItem(
                id: qId,
                index: i + 1,
                italian: statement,
                bangla: bangla,
                isVero: isVero,
                userAnswer: uAns,
                isUserCorrect: isCorrect,
                image: image,
                audio: audio,
                vocabulary: vocab,
              ));
            }
          }
          _isLoading = false;
        });

        // Auto-enrich any questions missing text/translations by IDs
        final missingIds = _questions
            .where((item) => item.italian.startsWith('Domanda n.') || item.bangla.isEmpty)
            .map((item) => item.id)
            .where((id) => id > 0)
            .toSet()
            .toList();

        if (missingIds.isNotEmpty) {
          try {
            final fetched = await ApiService.fetchQuestionsByIds(missingIds);
            if (fetched.isNotEmpty && mounted) {
              final Map<int, Map<String, dynamic>> enrichedMap = {};
              for (var f in fetched) {
                if (f is Map) {
                  final id = f['id'] is int ? f['id'] : int.tryParse('${f['id']}');
                  if (id != null) {
                    enrichedMap[id] = Map<String, dynamic>.from(f);
                  }
                }
              }

              setState(() {
                for (var qItem in _questions) {
                  final enriched = enrichedMap[qItem.id];
                  if (enriched != null) {
                    final it = (enriched['italian'] ?? enriched['question'] ?? '').toString().trim();
                    final bn = (enriched['bangla'] ?? enriched['bn_question'] ?? '').toString().trim();
                    if (it.isNotEmpty) qItem.italian = it;
                    if (bn.isNotEmpty) qItem.bangla = bn;
                    if (qItem.image == null && enriched['image'] != null) {
                      qItem.image = enriched['image'].toString();
                    }
                    if (qItem.audio == null && (enriched['audio'] != null || enriched['voice'] != null)) {
                      qItem.audio = (enriched['audio'] ?? enriched['voice'])?.toString();
                    }
                    if (qItem.vocabulary == null && enriched['vocabulary'] is List) {
                      qItem.vocabulary = enriched['vocabulary'] as List;
                    }
                  }
                }
              });
            }
          } catch (enrichErr) {
            debugPrint('Error enriching questions: $enrichErr');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading exam questions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String strtolower(String s) => s.toLowerCase();

  void _selectAll() {
    setState(() {
      _isSelectMode = true;
      for (var q in _questions) {
        q.isSelected = true;
      }
    });
  }

  void _unselectAll() {
    setState(() {
      _isSelectMode = false;
      for (var q in _questions) {
        q.isSelected = false;
      }
    });
  }

  void _activateSelect() {
    setState(() {
      _isSelectMode = true;
    });
  }

  Future<void> _speakItalian(String text, int index) async {
    if (_playingIndex == index) {
      await _flutterTts.stop();
      setState(() => _playingIndex = null);
      return;
    }
    setState(() => _playingIndex = index);
    final clean = HtmlTextHelper.stripHtml(text);
    await _flutterTts.speak(clean);
  }

  void _startQuizWithSelectedQuestions() {
    final selected = _questions.where((q) => q.isSelected).toList();
    final targetList = selected.isNotEmpty ? selected : _questions;

    if (targetList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun quesito disponibile per il quiz')),
      );
      return;
    }

    final customQuestions = targetList.map((q) => McqQuestion(
      id: q.id,
      chapter: 1,
      chapterName: 'Scheda Esame #${widget.examSummary.id}',
      italian: q.italian,
      bangla: q.bangla,
      isVero: q.isVero,
      image: q.image,
      audio: q.audio,
      vocabulary: q.vocabulary,
    )).toList();

    showDialog(
      context: context,
      builder: (context) => InstantCorrectionDialog(
        onSelection: (instantCorrection) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExamSimulationScreen(
                customQuestions: customQuestions,
                examTitle: 'Scheda Esame (${widget.examSummary.studentName}) - ${customQuestions.length} Quesiti',
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.examSummary.studentName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF22C55E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 8),
        child: ElevatedButton.icon(
          onPressed: _startQuizWithSelectedQuestions,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            elevation: 6,
          ),
          icon: const Icon(Icons.quiz_rounded, size: 20),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _questions.any((q) => q.isSelected)
                    ? 'QUIZ (${_questions.where((q) => q.isSelected).length})'
                    : 'QUIZ',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
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
            child: Column(
              children: [
                // Top Info & Action Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Candidate detail pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.examSummary.motorizzazione} • ${widget.examSummary.examDate}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Punteggio: ${widget.examSummary.correctCount}/30 Corrette (IDONEO)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Selection Action Buttons
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
                          if (!_isSelectMode) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _activateSelect,
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
                    ],
                  ),
                ),

                // Question Cards List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                          ),
                        )
                      : _questions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.quiz_outlined, size: 48, color: isDark ? Colors.white30 : Colors.black26),
                                  const SizedBox(height: 12),
                                  Text(
                                    'কোনো প্রশ্ন লোড করা যায়নি',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _loadQuestions,
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('পুনরায় চেষ্টা করুন'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF22C55E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                              itemCount: _questions.length,
                              itemBuilder: (context, index) {
                            final q = _questions[index];
                            return _buildQuestionCard(q, isDark);
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

  Widget _buildQuestionCard(PassedExamQuestionItem q, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: q.isSelected
              ? const Color(0xFF22C55E)
              : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
          width: q.isSelected ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Number, Selection Checkbox, and Eye Reveal Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (_isSelectMode)
                      Checkbox(
                        value: q.isSelected,
                        activeColor: const Color(0xFF22C55E),
                        onChanged: (val) {
                          setState(() {
                            q.isSelected = val ?? false;
                          });
                        },
                      ),
                    Text(
                      '${q.index}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                // "দেখুন" / Eye Reveal Button
                InkWell(
                  onTap: () {
                    setState(() {
                      q.isRevealed = !q.isRevealed;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: q.isRevealed
                          ? const Color(0xFF22C55E).withOpacity(0.12)
                          : const Color(0xFF38BDF8).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: q.isRevealed
                            ? const Color(0xFF22C55E).withOpacity(0.3)
                            : const Color(0xFF38BDF8).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          q.isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 15,
                          color: q.isRevealed ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          q.isRevealed ? 'লুকান' : 'দেখুন',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: q.isRevealed ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Question Image if present
            if (q.image != null && q.image!.trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                  child: Image.network(
                    ApiService.formatImageUrl(q.image!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Italian Statement with Underline Support (Normal weight, clean Slate color)
            RichText(
              text: TextSpan(
                children: HtmlTextHelper.buildParsedStatementSpans(
                  statement: q.italian,
                  isDark: isDark,
                  fontSize: 15.5,
                  height: 1.45,
                  textColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  underlineColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  vocabulary: q.vocabulary,
                  onTapWord: (rawWord, cleanWord) {
                    showDialog(
                      context: context,
                      builder: (context) => FullTranslateDialog(
                        italianText: q.italian,
                        banglaText: q.bangla,
                        imageUrl: q.image,
                        vocabulary: q.vocabulary,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Revealed Bangla Translation & Correct Answer
            if (q.isRevealed) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: q.isVero ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            q.isVero ? 'VERO (সত্য)' : 'FALSO (মিথ্যা)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (q.userAnswer != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Candidato: ${q.userAnswer}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: q.isUserCorrect ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (q.bangla.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        q.bangla,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Bottom Action Bar: Speaker TTS & Full Translate
            Row(
              children: [
                _buildSmallActionBtn(
                  icon: _playingIndex == q.index ? Icons.stop_rounded : Icons.volume_up_rounded,
                  label: 'ITALIANO',
                  color: const Color(0xFF22C55E),
                  onTap: () => _speakItalian(q.italian, q.index),
                ),
                const SizedBox(width: 8),
                _buildSmallActionBtn(
                  icon: Icons.g_translate_rounded,
                  label: 'অনুবাদ',
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => FullTranslateDialog(
                        italianText: q.italian,
                        banglaText: q.bangla,
                        imageUrl: q.image,
                        vocabulary: q.vocabulary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
