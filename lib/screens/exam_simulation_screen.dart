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
  bool _examCompleted = false;

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
    _startExamTimer();
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
      for (int index = 0; index < widget.customQuestions!.length; index++) {
        final q = widget.customQuestions![index];
        final statement = q.italian;
        final Map<String, String> help = {};
        final words = statement.toLowerCase().split(RegExp(r"[^a-zA-Z']"));
        for (var word in words) {
          if (word.isNotEmpty && QuestionDatabase.globalGlossary.containsKey(word)) {
            help[word] = QuestionDatabase.globalGlossary[word]!;
          }
        }

        customLoaded.add(ExamQuestion(
          id: '${index + 1}',
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
      }
      return;
    }

    List<ExamQuestion> loaded = [];

    try {
      // Fetch questions generated for 30-question official exam simulation (combines Argomenti + Cartelli)
      final apiData = await ApiService.generateSchedaEsame();
      if (apiData.isNotEmpty) {
        for (int index = 0; index < apiData.length; index++) {
          final q = apiData[index];
          final statement = (q['italian'] ?? '').toString();
          final Map<String, String> help = {};
          final words = statement.toLowerCase().split(RegExp(r"[^a-zA-Z']"));
          for (var word in words) {
            if (word.isNotEmpty && QuestionDatabase.globalGlossary.containsKey(word)) {
              help[word] = QuestionDatabase.globalGlossary[word]!;
            }
          }

          loaded.add(ExamQuestion(
            id: '${index + 1}',
            statement: statement,
            isVero: q['is_vero'] == true || q['is_vero'] == 1 || q['is_vero'] == '1',
            translation: (q['bangla'] ?? '').toString(),
            vocabularyHelp: help,
            vocabulary: q['vocabulary'] ?? q['vocabulary_underlines'],
            chapter: q['chapter'] ?? 1,
            chapterName: 'General Exam',
            image: q['image']?.toString(),
            audio: q['audio']?.toString(),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error generating scheda esame: $e');
    }

    if (loaded.isEmpty) {
      // Fallback: load 30 questions from local database combining Argomenti & Cartelli
      final localMcqs = QuestionDatabase.getExamQuestions();
      for (int index = 0; index < localMcqs.length && index < 30; index++) {
        final q = localMcqs[index];
        final Map<String, String> help = {};
        final words = q.italian.toLowerCase().split(RegExp(r"[^a-zA-Z']"));
        for (var word in words) {
          if (word.isNotEmpty && QuestionDatabase.globalGlossary.containsKey(word)) {
            help[word] = QuestionDatabase.globalGlossary[word]!;
          }
        }
        loaded.add(ExamQuestion(
          id: '${index + 1}',
          statement: q.italian,
          isVero: q.isVero,
          translation: q.bangla,
          vocabularyHelp: help,
          chapter: q.chapter,
          chapterName: q.chapterName,
          image: q.image,
          audio: q.audio,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _questions = loaded;
        _isLoading = false;
      });
    }
  }

  void _startExamTimer() {
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
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      results.add(ExamResultItem(
        index: i + 1,
        italian: q.statement,
        bangla: q.translation,
        isVero: q.isVero,
        userSelectedVero: q.userSelectedVero,
        chapterName: q.chapterName,
      ));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamResultScreen(
          results: results,
          durationSeconds: 1200 - _secondsRemaining,
        ),
      ),
    );
  }

  void _showOpzioniModal(ExamQuestion currentQuestion) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Opzioni / অপশনসমূহ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF22C55E)),
                title: const Text('Live Tutor Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('টিউটরের সাথে সরাসরি কথা বলুন'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TutorChatScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate_rounded, color: Colors.blue),
                title: const Text('Translate / অনুবাদ', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('সম্পূর্ণ বাংলা অনুবাদ দেখুন'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => FullTranslateDialog(
                      italianText: currentQuestion.statement,
                      banglaText: currentQuestion.translation,
                      imageUrl: currentQuestion.image,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border_rounded, color: Colors.orange),
                title: const Text('Save Question / সেভ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context);
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
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded, color: Colors.purple),
                title: const Text('Add Note / নোট যোগ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => QuestionNoteDialog(
                      questionId: currentQuestion.id,
                      initialNote: '',
                      onSave: (note) {},
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<InlineSpan> _buildUnderlinedStatement(ExamQuestion question, bool isDark) {
    return HtmlTextHelper.buildParsedStatementSpans(
      statement: question.statement,
      isDark: isDark,
      onTapWord: (rawWord, cleanWord) {
        String? vocabImage;
        String translation = question.vocabularyHelp[cleanWord] ?? 'ইতালিয়ান প্যাটেন্টে বি সংক্রান্ত শব্দ: $rawWord';

        if (question.vocabulary != null) {
          for (var item in question.vocabulary!) {
            if (item is Map) {
              final word = (item['italian'] ?? item['word'] ?? item['italian_word'] ?? '').toString().trim().toLowerCase();
              if (word == cleanWord.toLowerCase() || word == rawWord.toLowerCase()) {
                final bn = (item['bangla'] ?? item['meaning'] ?? item['bangla_meaning'] ?? item['translation'] ?? '').toString().trim();
                if (bn.isNotEmpty) {
                  translation = bn;
                }
                final img = (item['image'] ?? item['image_path'] ?? item['img'] ?? '').toString().trim();
                if (img.isNotEmpty) {
                  vocabImage = img;
                }
                break;
              }
            }
          }
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

    if (_isLoading || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Test', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF121829) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0.5,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
        ),
      );
    }

    final currentQuestion = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedGroupIndex = index;
                              _currentIndex = (start - 1).clamp(0, _questions.length - 1);
                            });
                          },
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
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
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
                        '${_currentIndex + 1}',
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
                          final isCurrent = qIndex == _currentIndex;
                          final isAnswered = qIndex < _questions.length && _questions[qIndex].userSelectedVero != null;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _currentIndex = qIndex;
                                _selectedGroupIndex = qIndex ~/ 10;
                              });
                            },
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
                                    color: (isCurrent || isAnswered) ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
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
                          final isCurrent = qIndex == _currentIndex;
                          final isAnswered = qIndex < _questions.length && _questions[qIndex].userSelectedVero != null;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _currentIndex = qIndex;
                                _selectedGroupIndex = qIndex ~/ 10;
                              });
                            },
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
                                    color: (isCurrent || isAnswered) ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
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
                          if (currentQuestion.image != null && currentQuestion.image!.trim().isNotEmpty) ...[
                            Container(
                              height: 130,
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Image.network(
                                ApiService.formatImageUrl(currentQuestion.image!),
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 14),
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
                const SizedBox(height: 10),

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
                            onTap: () => _showOpzioniModal(currentQuestion),
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
                              onPressed: _currentIndex < _questions.length - 1
                                  ? () {
                                      setState(() {
                                        _currentIndex++;
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

        // Log user MCQ result to Laravel database
        final rawId = int.tryParse(currentQuestion.id) ?? 1;
        ApiService.logUserMcqResult(
          rawId,
          isCorrect,
          isVeroButton ? 'V' : 'F',
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
