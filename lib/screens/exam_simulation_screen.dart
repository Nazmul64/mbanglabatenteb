import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/question_database.dart';
import '../models/bookmark_manager.dart';
import '../models/mcq_question.dart';
import '../services/api_service.dart';
import '../services/html_text_helper.dart';
import 'triangle_pattern_painter.dart';
import 'google_translate_dialog.dart';
import 'full_translate_dialog.dart';
import 'tutor_chat_screen.dart';
import 'question_note_dialog.dart';
import 'image_zoom_dialog.dart';
import 'exam_result_screen.dart';

class ExamQuestion {
  final String id;
  final String statement;
  final bool isVero;
  final String translation;
  final Map<String, String> vocabularyHelp; // Word -> Bangla meaning
  final List<dynamic>? vocabulary;
  final int chapter;
  final String chapterName;
  final String? image;
  final String? audio;
  bool? userSelectedVero;
  String? userNote;

  ExamQuestion({
    required this.id,
    required this.statement,
    required this.isVero,
    required this.translation,
    required this.vocabularyHelp,
    this.vocabulary,
    required this.chapter,
    required this.chapterName,
    this.image,
    this.audio,
    this.userSelectedVero,
    this.userNote,
  });
}

class ExamSimulationScreen extends StatefulWidget {
  final List<McqQuestion>? customQuestions;
  final String? examTitle;

  const ExamSimulationScreen({
    super.key,
    this.customQuestions,
    this.examTitle,
  });

  @override
  State<ExamSimulationScreen> createState() => _ExamSimulationScreenState();
}

class _ExamSimulationScreenState extends State<ExamSimulationScreen> {
  // 30 questions list for full exam simulation (combining Argomenti & Cartelli)
  List<ExamQuestion> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _selectedGroupIndex = 0; // 0: 1-10, 1: 11-20, 2: 21-30
  double _playbackSpeed = 1.0;

  // Timer variables
  Timer? _examTimer;
  int _secondsRemaining = 1200; // 20 minutes

  // Audio and TTS player
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  bool _isTtsPlaying = false;
  double _audioProgress = 0.0;
  Duration? _audioDuration;

  @override
  void initState() {
    super.initState();
    _initAudioAndTts();
    _initializeQuestions();
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _flutterTts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _initAudioAndTts() {
    _flutterTts.setLanguage('it-IT');
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
    _audioPlayer.setVolume(1.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isTtsPlaying = false;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _audioDuration = d;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted && _audioDuration != null && _audioDuration!.inMilliseconds > 0) {
        setState(() {
          _audioProgress = (p.inMilliseconds / _audioDuration!.inMilliseconds).clamp(0.0, 1.0);
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _audioProgress = 0.0;
        });
      }
    });
  }

  Future<void> _initializeQuestions() async {
    setState(() {
      _isLoading = true;
    });

    if (widget.customQuestions != null && widget.customQuestions!.isNotEmpty) {
      List<ExamQuestion> customLoaded = [];
      final questionsList = widget.customQuestions!.length > 30
          ? (List<McqQuestion>.from(widget.customQuestions!)..shuffle()).take(30).toList()
          : widget.customQuestions!;

      for (int index = 0; index < questionsList.length; index++) {
        final q = questionsList[index];
        final statement = q.italian;
        final Map<String, String> help = {};
        final words = statement.toLowerCase().split(RegExp(r"[^a-zA-Z']"));
        for (var word in words) {
          if (word.isNotEmpty && QuestionDatabase.globalGlossary.containsKey(word)) {
            help[word] = QuestionDatabase.globalGlossary[word]!;
          }
        }

        customLoaded.add(ExamQuestion(
          id: (q.id != 0 ? q.id : (index + 1)).toString(),
          statement: statement,
          isVero: q.isVero,
          translation: q.bangla,
          vocabularyHelp: help,
          vocabulary: q.vocabulary,
          chapter: q.chapter,
          chapterName: q.chapterName,
          image: q.image,
          audio: q.audio,
        ));
      }

      if (mounted) {
        setState(() {
          _questions = customLoaded;
          _isLoading = false;
        });
        _startExamTimer();
      }
      return;
    }

    List<ExamQuestion> loaded = [];

    try {
      // Fetch live random questions combining Argomenti & Cartelli
      final apiData = await ApiService.generateSchedaEsame();
      if (apiData.isNotEmpty) {
        for (int index = 0; index < apiData.length; index++) {
          final q = apiData[index];
          final statement = (q['italian'] ?? q['domanda'] ?? q['question'] ?? q['text'] ?? '').toString();
          if (statement.trim().isEmpty) continue;

          final rawIsVero = q['is_vero'] ?? q['correct_answer'] ?? q['answer'] ?? q['isVero'];
          bool isVero = true;
          if (rawIsVero is bool) {
            isVero = rawIsVero;
          } else if (rawIsVero is String) {
            isVero = rawIsVero.toLowerCase() == 'vero' || rawIsVero == '1' || rawIsVero.toLowerCase() == 'true';
          } else if (rawIsVero is int) {
            isVero = rawIsVero == 1;
          }

          final Map<String, String> help = {};
          final words = statement.toLowerCase().split(RegExp(r"[^a-zA-Z']"));
          for (var word in words) {
            if (word.isNotEmpty && QuestionDatabase.globalGlossary.containsKey(word)) {
              help[word] = QuestionDatabase.globalGlossary[word]!;
            }
          }

          final rawVocab = q['vocabulary'] ?? q['vocabulary_underlines'];
          List<dynamic>? parsedVocab;
          if (rawVocab is List) {
            parsedVocab = rawVocab;
          }

          // Strictly only explicit question image (NO cover_image, NO page_image, NO vocabulary underlines fallback)
          String? img;
          final rawImg = (q['image'] ?? q['image_path'] ?? q['img'] ?? q['photo'] ?? q['image_url'])?.toString().trim();
          if (rawImg != null &&
              rawImg.isNotEmpty &&
              rawImg.toLowerCase() != 'null' &&
              rawImg.toLowerCase() != 'undefined' &&
              rawImg.toLowerCase() != 'none' &&
              !rawImg.contains('/uploads/vocabulary/') &&
              !rawImg.contains('vocab_') &&
              !rawImg.contains('/data/user/') &&
              !rawImg.contains('/data/data/') &&
              !rawImg.contains('/storage/emulated/')) {
            final formatted = ApiService.formatImageUrl(rawImg);
            if (formatted.isNotEmpty) {
              img = formatted;
            }
          }

          final audio = (q['audio'] ?? q['voice'] ?? q['mp3'] ?? q['audio_url'])?.toString();
          final translation = (q['bangla'] ?? q['translation'] ?? q['traduzione'] ?? q['bn_question'] ?? q['bn_translation'] ?? '').toString();
          final rawQId = q['id'] ?? (index + 1);

          loaded.add(ExamQuestion(
            id: '$rawQId',
            statement: statement,
            isVero: isVero,
            translation: translation,
            vocabularyHelp: help,
            vocabulary: parsedVocab,
            chapter: q['chapter'] is int ? q['chapter'] : int.tryParse(q['chapter']?.toString() ?? '1') ?? 1,
            chapterName: q['chapter_name']?.toString() ?? 'Argomenti & Cartelli',
            image: img,
            audio: audio,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error generating live scheda esame: $e');
    }

    if (mounted) {
      setState(() {
        _questions = loaded;
        _isLoading = false;
      });
      if (_questions.isNotEmpty) {
        _startExamTimer();
      }
    }
  }

  void _startExamTimer() {
    _examTimer?.cancel();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        _examTimer?.cancel();
        _finishExam();
      }
    });
  }

  String _formatTimerText() {
    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _speakItalian(String text) async {
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingAudio = false;
      });
    }

    if (_isTtsPlaying) {
      await _flutterTts.stop();
      setState(() {
        _isTtsPlaying = false;
      });
      return;
    }

    setState(() {
      _isTtsPlaying = true;
    });

    double rate = (_playbackSpeed * 0.5).clamp(0.1, 1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setLanguage('it-IT');

    final clean = text.replaceAll(RegExp(r'<[^>]*>'), '');
    await _flutterTts.speak(clean);
  }

  Future<void> _toggleAudioPlayback(String? audioUrl) async {
    if (audioUrl == null || audioUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('এই প্রশ্নের জন্য বাংলা অডিও উপলব্ধ নেই')),
      );
      return;
    }

    if (_isTtsPlaying) {
      await _flutterTts.stop();
      setState(() {
        _isTtsPlaying = false;
      });
    }

    if (_isPlayingAudio) {
      await _audioPlayer.pause();
      setState(() {
        _isPlayingAudio = false;
      });
    } else {
      setState(() {
        _isPlayingAudio = true;
      });

      final url = ApiService.formatImageUrl(audioUrl);
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.setSource(UrlSource(url));
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.resume();
      } catch (e) {
        debugPrint('Error playing MP3 audio: $e');
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
        }
      }
    }
  }

  void _finishExam() {
    _examTimer?.cancel();
    final List<ExamResultItem> results = [];
    int giustoCount = 0;
    int sbagliatoCount = 0;
    int nonDateCount = 0;

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final item = ExamResultItem(
        id: int.tryParse(q.id) ?? (i + 1),
        index: i + 1,
        italian: q.statement,
        bangla: q.translation,
        isVero: q.isVero,
        userSelectedVero: q.userSelectedVero,
        chapterName: q.chapterName,
        chapter: q.chapter,
        image: q.image,
        audio: q.audio,
        vocabulary: q.vocabulary,
        vocabularyHelp: q.vocabularyHelp,
      );
      results.add(item);
      if (item.isAttempted) {
        if (item.isCorrect) {
          giustoCount++;
        } else {
          sbagliatoCount++;
        }
      } else {
        nonDateCount++;
      }
    }

    // Persist all attempted questions into Correct & Wrong MCQs and sync with server
    BookmarkManager.recordExamResults(results, timeSpentSeconds: (1200 - _secondsRemaining).clamp(0, 1200));

    _showExamResultModal(results, giustoCount, sbagliatoCount, nonDateCount);
  }

  void _showExamResultModal(List<ExamResultItem> results, int giustoCount, int sbagliatoCount, int nonDateCount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = results.length > 0 ? results.length : 30;
    final isPassed = sbagliatoCount <= 3 && nonDateCount == 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Title: Risultato
              Text(
                'Risultato',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF3B82F6),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 18),

              // 2. Large Circular Face Icon (Red for fail, Green for pass)
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPassed ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    width: 5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isPassed ? Icons.sentiment_very_satisfied_rounded : Icons.sentiment_very_dissatisfied_rounded,
                    size: 56,
                    color: isPassed ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 3. Giusto Capsule Progress Bar (Green)
              _buildCapsuleResultBar(
                label: 'Giusto',
                count: giustoCount,
                total: total,
                fillColor: const Color(0xFF4CAF50),
                isDark: isDark,
              ),
              const SizedBox(height: 12),

              // 4. Sbagliato Capsule Progress Bar (Red)
              _buildCapsuleResultBar(
                label: 'Sbagliato',
                count: sbagliatoCount,
                total: total,
                fillColor: const Color(0xFFEF5350),
                isDark: isDark,
              ),
              const SizedBox(height: 12),

              // 5. Risposte non date Capsule Progress Bar (Orange)
              _buildCapsuleResultBar(
                label: 'Risposte non date',
                count: nonDateCount,
                total: total,
                fillColor: const Color(0xFFFFA000),
                isDark: isDark,
              ),
              const SizedBox(height: 22),

              // 6. Mostra Risultato Button (Capsule Grey/Light Theme)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExamResultScreen(
                          results: results,
                          durationSeconds: 1200 - _secondsRemaining,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Mostra Risultato',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 7. Ricomincia & Home Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _restartExam();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Ricomincia',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                        side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text(
                        'Home',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
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

  Widget _buildCapsuleResultBar({
    required String label,
    required int count,
    required int total,
    required Color fillColor,
    required bool isDark,
  }) {
    final double ratio = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      height: 38,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            if (count > 0)
              FractionallySizedBox(
                widthFactor: ratio < 0.1 ? 0.1 : ratio,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
              ),
            Center(
              child: Text(
                '$label:$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _restartExam() {
    _examTimer?.cancel();
    setState(() {
      _currentIndex = 0;
      _selectedGroupIndex = 0;
      _secondsRemaining = 1200;
      for (var q in _questions) {
        q.userSelectedVero = null;
      }
    });
    _startExamTimer();
  }

  bool _showOpzioniToolbar = false;

  void _toggleOpzioniToolbar() {
    setState(() {
      _showOpzioniToolbar = !_showOpzioniToolbar;
    });
  }

  void _confirmExitExam() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Chiudi Esame', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Sei sicuro di voler uscire dall\'esame?\n(আপনি কি পরীক্ষা বন্ধ করে বের হতে চান?)',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla (না)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Chiudi (হ্যাঁ, বের হন)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showQuestionOverviewGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riepilogo Domande (১-৩০)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_questions.length, (i) {
                  final isAnswered = _questions[i].userSelectedVero != null;
                  final isCurrent = i == _currentIndex;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _currentIndex = i;
                        _selectedGroupIndex = i ~/ 10;
                      });
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFFE53935)
                            : (isAnswered ? const Color(0xFF4CAF50) : (isDark ? Colors.white10 : Colors.grey.shade100)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFFE53935)
                              : (isAnswered ? const Color(0xFF4CAF50) : Colors.grey.shade300),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: (isCurrent || isAnswered) ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showChapterTheoryDialog(ExamQuestion currentQuestion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                currentQuestion.chapterName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Capitolo ${currentQuestion.chapter}',
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                currentQuestion.statement,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
              ),
              if (currentQuestion.translation.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currentQuestion.translation,
                    style: TextStyle(fontSize: 14, color: Colors.green.shade900, height: 1.3),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi / বন্ধ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingOpzioniBar(ExamQuestion currentQuestion, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Live Tutor Chat Avatar with Red Badge '1'
          InkWell(
            onTap: () {
              setState(() => _showOpzioniToolbar = false);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TutorChatScreen()));
            },
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue.shade200, width: 1.2),
                  ),
                  child: const Center(
                    child: Icon(Icons.support_agent_rounded, size: 22, color: Color(0xFF1E40AF)),
                  ),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Translate Icon
          InkWell(
            onTap: () {
              setState(() => _showOpzioniToolbar = false);
              showDialog(
                context: context,
                builder: (context) => FullTranslateDialog(
                  italianText: currentQuestion.statement,
                  banglaText: currentQuestion.translation,
                  imageUrl: currentQuestion.image,
                  vocabulary: currentQuestion.vocabulary,
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.translate_rounded, color: Colors.purple.shade700, size: 20),
              ),
            ),
          ),

          // 3. Bookmark / Save Icon
          InkWell(
            onTap: () async {
              setState(() => _showOpzioniToolbar = false);
              final mcq = McqQuestion(
                id: int.tryParse(currentQuestion.id) ?? 1,
                chapter: currentQuestion.chapter,
                chapterName: currentQuestion.chapterName,
                italian: currentQuestion.statement,
                bangla: currentQuestion.translation,
                isVero: currentQuestion.isVero,
                image: currentQuestion.image,
                audio: currentQuestion.audio,
              );
              await BookmarkManager.saveQuestion(mcq);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('প্রশ্নটি সেভ করা হয়েছে')),
                );
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.bookmark_outline_rounded, color: Colors.orange.shade800, size: 20),
              ),
            ),
          ),

          // 4. Note Icon (Sticky notes)
          InkWell(
            onTap: () async {
              setState(() => _showOpzioniToolbar = false);
              final existingNote = currentQuestion.userNote ?? (await BookmarkManager.getNoteForQuestion(currentQuestion.statement, int.tryParse(currentQuestion.id)) ?? '');
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (context) => QuestionNoteDialog(
                  questionId: currentQuestion.id,
                  initialNote: existingNote,
                  onSave: (note) async {
                    setState(() => currentQuestion.userNote = note);
                    final mcq = McqQuestion(
                      id: int.tryParse(currentQuestion.id) ?? 0,
                      chapter: currentQuestion.chapter,
                      chapterName: currentQuestion.chapterName,
                      italian: currentQuestion.statement,
                      bangla: currentQuestion.translation,
                      isVero: currentQuestion.isVero,
                      image: currentQuestion.image,
                      audio: currentQuestion.audio,
                      vocabulary: currentQuestion.vocabulary,
                      userNote: note,
                    );
                    await BookmarkManager.saveNote(mcq, note, type: 'exam');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(note.isNotEmpty ? 'নোট সফলভাবে সংরক্ষণ করা হয়েছে' : 'নোট মুছে ফেলা হয়েছে'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (currentQuestion.userNote != null && currentQuestion.userNote!.isNotEmpty)
                    ? const Color(0xFF10B981).withOpacity(0.15)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.note_alt_outlined,
                  color: (currentQuestion.userNote != null && currentQuestion.userNote!.isNotEmpty)
                      ? const Color(0xFF10B981)
                      : Colors.blue.shade700,
                  size: 20,
                ),
              ),
            ),
          ),

          // 5. Info Book Icon
          InkWell(
            onTap: () {
              setState(() => _showOpzioniToolbar = false);
              _showChapterTheoryDialog(currentQuestion);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.menu_book_rounded, color: Colors.teal.shade700, size: 20),
              ),
            ),
          ),

          // 6. List / Scheda Question Overview Icon
          InkWell(
            onTap: () {
              setState(() => _showOpzioniToolbar = false);
              _showQuestionOverviewGrid();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.format_list_bulleted_rounded, color: Colors.indigo.shade700, size: 20),
              ),
            ),
          ),

          // 7. Chiudi Esame Button
          InkWell(
            onTap: () {
              setState(() => _showOpzioniToolbar = false);
              _confirmExitExam();
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chiudi',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'Esame',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildUnderlinedStatement(ExamQuestion question, bool isDark) {
    return HtmlTextHelper.buildParsedStatementSpans(
      statement: question.statement,
      isDark: isDark,
      vocabulary: question.vocabulary,
      onTapWord: (rawWord, cleanWord) {
        String? vocabImage;
        String translation = question.vocabularyHelp[cleanWord] ?? '';

        if (question.vocabulary != null && question.vocabulary!.isNotEmpty) {
          for (var item in question.vocabulary!) {
            if (item is Map) {
              final word = (item['italian'] ?? item['word'] ?? item['italian_word'] ?? '').toString().trim().toLowerCase();
              final rawLower = rawWord.toLowerCase().trim();
              final cleanLower = cleanWord.toLowerCase().trim();
              if (word.isNotEmpty && (word == cleanLower || word == rawLower || rawLower == word || cleanLower == word)) {
                final bn = (item['bangla'] ?? item['meaning'] ?? item['bangla_meaning'] ?? item['translation'] ?? '').toString().trim();
                if (bn.isNotEmpty) {
                  translation = bn;
                }
                final img = (item['image'] ?? item['image_path'] ?? item['img'] ?? item['photo'] ?? item['image_url'] ?? '').toString().trim();
                if (img.isNotEmpty && img.toLowerCase() != 'null' && img.toLowerCase() != 'undefined' && img.toLowerCase() != 'none') {
                  vocabImage = img;
                }
                break;
              }
            }
          }
        }

        if (translation.isEmpty && QuestionDatabase.globalGlossary.containsKey(cleanWord.toLowerCase())) {
          translation = QuestionDatabase.globalGlossary[cleanWord.toLowerCase()]!;
        }
        if (translation.isEmpty && QuestionDatabase.globalGlossary.containsKey(rawWord.toLowerCase())) {
          translation = QuestionDatabase.globalGlossary[rawWord.toLowerCase()]!;
        }

        showDialog(
          context: context,
          builder: (context) => GoogleTranslateDialog(
            italianText: cleanWord.isNotEmpty ? cleanWord : rawWord,
            localTranslation: translation,
            imageUrl: vocabImage,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('mbanglabatenteb', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF121829) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0.5,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF4CAF50)),
              const SizedBox(height: 16),
              Text(
                'টেস্ট লোড হচ্ছে...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('mbanglabatenteb', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF121829) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0.5,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_outlined, size: 64, color: isDark ? Colors.amber.shade300 : const Color(0xFFEAB308)),
                const SizedBox(height: 16),
                Text(
                  'প্রশ্ন লোড করা যায়নি',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ইন্টারনেট সংযোগ চেক করুন অথবা পুনরায় চেষ্টা করুন।',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initializeQuestions,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('পুনরায় চেষ্টা করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'ফিরে যান',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final safeIndex = _currentIndex.clamp(0, _questions.length - 1);
    final currentQuestion = _questions[safeIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('mbanglabatenteb', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF121829) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_rounded, color: Color(0xFF4CAF50)),
            tooltip: 'Tutor Chat',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TutorChatScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.dark_mode_outlined),
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () {},
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
                const SizedBox(height: 6),

                // 1. Group Selector Row (Domande da 1 a 10, Domande da 11 a 20, Domande da 21 a 30)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: List.generate(3, (index) {
                      final start = index * 10 + 1;
                      final end = start + 9;
                      final isSelected = _selectedGroupIndex == index;
                      final isAvailable = (start - 1) < _questions.length;
                      return Expanded(
                        child: InkWell(
                          onTap: isAvailable
                              ? () {
                                  setState(() {
                                    _selectedGroupIndex = index;
                                    _currentIndex = (start - 1).clamp(0, _questions.length - 1);
                                  });
                                }
                              : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4CAF50)
                                  : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Domande da $start a $end',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isAvailable
                                          ? (isDark ? Colors.white70 : Colors.black54)
                                          : Colors.grey.shade400),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),

                // 2. Active Red Question Circle Badge Indicator
                Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935), // Red filled active badge circle
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${safeIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Questions Grid Bar (1 to 30) - 2 rows of 15 buttons (Matching Web Screenshot)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(15, (i) {
                          final qIndex = i;
                          final isAvailable = qIndex < _questions.length;
                          final isCurrent = qIndex == safeIndex;
                          final isAnswered = isAvailable && _questions[qIndex].userSelectedVero != null;

                          return InkWell(
                            onTap: isAvailable
                                ? () {
                                    setState(() {
                                      _currentIndex = qIndex;
                                      _selectedGroupIndex = qIndex ~/ 10;
                                    });
                                  }
                                : null,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFFE53935)
                                    : (isAnswered ? const Color(0xFF4CAF50) : (isDark ? Colors.white10 : Colors.white)),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isCurrent
                                      ? const Color(0xFFE53935)
                                      : (isAnswered ? const Color(0xFF4CAF50) : (isDark ? Colors.white24 : Colors.grey.shade300)),
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${qIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: (isCurrent || isAnswered)
                                        ? Colors.white
                                        : (isAvailable ? (isDark ? Colors.white70 : Colors.black87) : Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(15, (i) {
                          final qIndex = i + 15;
                          final isAvailable = qIndex < _questions.length;
                          final isCurrent = qIndex == safeIndex;
                          final isAnswered = isAvailable && _questions[qIndex].userSelectedVero != null;

                          return InkWell(
                            onTap: isAvailable
                                ? () {
                                    setState(() {
                                      _currentIndex = qIndex;
                                      _selectedGroupIndex = qIndex ~/ 10;
                                    });
                                  }
                                : null,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFFE53935)
                                    : (isAnswered ? const Color(0xFF4CAF50) : (isDark ? Colors.white10 : Colors.white)),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isCurrent
                                      ? const Color(0xFFE53935)
                                      : (isAnswered ? const Color(0xFF4CAF50) : (isDark ? Colors.white24 : Colors.grey.shade300)),
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${qIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: (isCurrent || isAnswered)
                                        ? Colors.white
                                        : (isAvailable ? (isDark ? Colors.white70 : Colors.black87) : Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 4. Main Active Question Card Container
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E294B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (currentQuestion.image != null &&
                              currentQuestion.image!.trim().isNotEmpty &&
                              currentQuestion.image!.toLowerCase() != 'null' &&
                              currentQuestion.image!.toLowerCase() != 'undefined' &&
                              currentQuestion.image!.toLowerCase() != 'none' &&
                              !currentQuestion.image!.contains('/uploads/vocabulary/') &&
                              !currentQuestion.image!.contains('vocab_') &&
                              !currentQuestion.image!.contains('/data/user/') &&
                              !currentQuestion.image!.contains('/data/data/') &&
                              !currentQuestion.image!.contains('/storage/emulated/') &&
                              !currentQuestion.image!.contains('scaled_IMG') &&
                              !currentQuestion.image!.toLowerCase().contains('placeholder') &&
                              !currentQuestion.image!.contains('default_image')) ...[
                            GestureDetector(
                              onTap: () => ImageZoomDialog.show(context, currentQuestion.image!),
                              child: Container(
                                height: 140,
                                width: double.infinity,
                                padding: const EdgeInsets.all(6),
                                margin: const EdgeInsets.only(bottom: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Image.network(
                                  ApiService.formatImageUrl(currentQuestion.image!),
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
                              ),
                            ),
                          ],
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: _buildUnderlinedStatement(currentQuestion, isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Floating Opzioni Toolbar (Appears right above bottom bar when Opzioni is tapped)
                if (_showOpzioniToolbar) ...[
                  _buildFloatingOpzioniBar(currentQuestion, isDark),
                ],

                // 5. Bottom Light-Green Control Bar (#E8F5E9 Theme matching Web Screenshot)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFC8E6C9),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Audio Controls (Opzioni, ITALIANO, Play, Slider, Speed)
                      Row(
                        children: [
                          InkWell(
                            onTap: _toggleOpzioniToolbar,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.grid_view_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                                const SizedBox(height: 2),
                                Text(
                                  'Opzioni',
                                  style: TextStyle(fontSize: 8, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          InkWell(
                            onTap: () => _speakItalian(currentQuestion.statement),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isTtsPlaying ? Colors.orange.shade700 : const Color(0xFF2962FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(_isTtsPlaying ? Icons.stop_rounded : Icons.volume_up_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 2),
                                  const Text(
                                    'ITALIANO',
                                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          IconButton(
                            icon: Icon(
                              _isPlayingAudio ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: isDark ? Colors.white70 : Colors.black87,
                              size: 26,
                            ),
                            onPressed: () => _toggleAudioPlayback(currentQuestion.audio),
                          ),

                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                activeTrackColor: const Color(0xFF4CAF50),
                                inactiveTrackColor: isDark ? Colors.white10 : Colors.grey.shade300,
                                thumbColor: const Color(0xFF4CAF50),
                              ),
                              child: Slider(
                                value: _audioProgress.clamp(0.0, 1.0),
                                onChanged: (val) {
                                  setState(() {
                                    _audioProgress = val;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          PopupMenuButton<double>(
                            initialValue: _playbackSpeed,
                            tooltip: 'Speed',
                            onSelected: (val) {
                              setState(() {
                                _playbackSpeed = val;
                              });
                            },
                            itemBuilder: (ctx) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                              return PopupMenuItem<double>(
                                value: s,
                                child: Text('${s}x'),
                              );
                            }).toList(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.speed_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 18),
                                const SizedBox(height: 2),
                                Text(
                                  'Speed',
                                  style: TextStyle(fontSize: 8, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Row 2: VERO (V) Green Card & FALSO (F) Blue Card Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildVFButton('V', 'VERO', true, currentQuestion, isDark, const Color(0xFF4CAF50)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildVFButton('F', 'FALSO', false, currentQuestion, isDark, const Color(0xFF2962FF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Row 3: Navigation (< Indietro & Avanti >) Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _currentIndex > 0
                                  ? () {
                                      setState(() {
                                        _currentIndex--;
                                        _selectedGroupIndex = _currentIndex ~/ 10;
                                      });
                                    }
                                  : null,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chevron_left_rounded, size: 18),
                                  Text('Indietro', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                if (_currentIndex < _questions.length - 1) {
                                  setState(() {
                                    _currentIndex++;
                                    _selectedGroupIndex = _currentIndex ~/ 10;
                                  });
                                } else {
                                  _finishExam();
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Avanti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Icon(Icons.chevron_right_rounded, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Row 4: Timer Card (19:45 & Tempo a Disposizione)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E294B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatTimerText(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Text(
                                'Tempo a Disposizione',
                                style: TextStyle(fontSize: 7.5, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVFButton(String shortLabel, String fullLabel, bool isVeroButton, ExamQuestion currentQuestion, bool isDark, Color brandColor) {
    bool isSelected = currentQuestion.userSelectedVero == isVeroButton;

    return InkWell(
      onTap: () {
        final bool isCorrect = isVeroButton == currentQuestion.isVero;
        setState(() {
          currentQuestion.userSelectedVero = isVeroButton;
        });

        final rawId = int.tryParse(currentQuestion.id) ?? 1;
        final mcq = McqQuestion(
          id: rawId,
          chapter: currentQuestion.chapter,
          chapterName: currentQuestion.chapterName,
          italian: currentQuestion.statement,
          bangla: currentQuestion.translation,
          isVero: currentQuestion.isVero,
          image: currentQuestion.image,
          audio: currentQuestion.audio,
          vocabulary: currentQuestion.vocabulary,
        );
        BookmarkManager.recordQuestionResult(
          mcq,
          isCorrect,
          userAnswer: isVeroButton ? 'V' : 'F',
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? brandColor : (isDark ? const Color(0xFF1E294B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? brandColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              shortLabel,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: isSelected ? Colors.white : brandColor,
              ),
            ),
            Text(
              fullLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 9,
                color: isSelected ? Colors.white : brandColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
