import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/bookmark_manager.dart';
import '../models/mcq_question.dart';
import '../models/question_database.dart';
import '../services/api_service.dart';
import '../services/html_text_helper.dart';
import 'triangle_pattern_painter.dart';
import 'google_translate_dialog.dart';
import 'full_translate_dialog.dart';
import 'image_zoom_dialog.dart';
import 'question_note_dialog.dart';
import 'instant_correction_dialog.dart';
import 'exam_simulation_screen.dart';
import 'quiz_practice_screen.dart';

enum McqScreenMode {
  wrong,
  correct,
  saved,
  noted,
}

class SavedQuestionsScreen extends StatefulWidget {
  final String title;
  final McqScreenMode mode;

  const SavedQuestionsScreen({
    super.key,
    this.title = 'Saved MCQs',
    this.mode = McqScreenMode.saved,
  });

  @override
  State<SavedQuestionsScreen> createState() => _SavedQuestionsScreenState();
}

class _SavedQuestionsScreenState extends State<SavedQuestionsScreen> {
  List<PatenteQuizItem> _quizzes = [];
  bool _isLoading = true;
  bool _isSelectActive = false;

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  PatenteQuizItem? _currentlyPlayingAudioQuiz;
  PatenteQuizItem? _currentlySpeakingQuiz;

  @override
  void initState() {
    super.initState();
    _initAudioAndTts();
    _loadQuestions();
  }

  @override
  void dispose() {
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
      if (mounted && _currentlySpeakingQuiz != null) {
        setState(() {
          _currentlySpeakingQuiz!.isTtsPlaying = false;
          _currentlySpeakingQuiz = null;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted && _currentlyPlayingAudioQuiz != null) {
        setState(() {
          _currentlyPlayingAudioQuiz!.audioDuration = d;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted && _currentlyPlayingAudioQuiz != null) {
        final d = _currentlyPlayingAudioQuiz!.audioDuration;
        if (d != null && d.inMilliseconds > 0) {
          setState(() {
            _currentlyPlayingAudioQuiz!.audioProgress = (p.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
          });
        }
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && _currentlyPlayingAudioQuiz != null) {
        setState(() {
          _currentlyPlayingAudioQuiz!.isPlaying = false;
          _currentlyPlayingAudioQuiz!.audioProgress = 0.0;
          _currentlyPlayingAudioQuiz = null;
        });
      }
    });
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    List<McqQuestion> loaded = [];

    try {
      if (widget.mode == McqScreenMode.wrong) {
        loaded = await BookmarkManager.getWrongQuestions();
      } else if (widget.mode == McqScreenMode.correct) {
        loaded = await BookmarkManager.getCorrectQuestions();
      } else if (widget.mode == McqScreenMode.noted) {
        loaded = await BookmarkManager.getNotedQuestions();
      } else {
        loaded = await BookmarkManager.getSavedQuestions();
      }
    } catch (e) {
      debugPrint('Error loading questions in SavedQuestionsScreen: $e');
    }

    if (mounted) {
      setState(() {
        _quizzes = loaded.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          final int gCount = widget.mode == McqScreenMode.wrong
              ? (q.giustoCount > 0 ? q.giustoCount : 0)
              : (widget.mode == McqScreenMode.correct ? (q.giustoCount > 0 ? q.giustoCount : 1) : q.giustoCount);
          final int sCount = widget.mode == McqScreenMode.wrong
              ? (q.sbagliatoCount > 0 ? q.sbagliatoCount : 1)
              : (widget.mode == McqScreenMode.correct ? (q.sbagliatoCount > 0 ? q.sbagliatoCount : 0) : q.sbagliatoCount);

          return PatenteQuizItem(
            rawId: q.id,
            id: '${idx + 1}',
            italian: q.italian,
            bangla: q.bangla,
            isVero: q.isVero,
            audioNote: 'অডিও ব্যাখ্যা সহ বিস্তারিত প্রস্তুত পড়ুন',
            image: q.image,
            imagePosition: q.imagePosition,
            audioUrl: q.audio,
            vocabulary: q.vocabulary,
            isSaved: widget.mode == McqScreenMode.saved,
            studyNotes: q.userNote ?? '',
            giustoCount: gCount,
            sbagliatoCount: sCount,
          );
        }).toList();
        _isLoading = false;
      });
    }
  }

  void _unselectAll() {
    setState(() {
      _isSelectActive = false;
      for (var quiz in _quizzes) {
        quiz.isSelected = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _isSelectActive = true;
      for (var quiz in _quizzes) {
        quiz.isSelected = true;
      }
    });
  }

  void _activateSelectMode() {
    setState(() {
      _isSelectActive = true;
    });
  }

  Future<void> _speakItalianQuestion(PatenteQuizItem quiz) async {
    if (_currentlyPlayingAudioQuiz != null) {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingAudioQuiz!.isPlaying = false;
        _currentlyPlayingAudioQuiz = null;
      });
    }

    if (quiz.isTtsPlaying) {
      await _flutterTts.stop();
      setState(() {
        quiz.isTtsPlaying = false;
        _currentlySpeakingQuiz = null;
      });
      return;
    }

    if (_currentlySpeakingQuiz != null && _currentlySpeakingQuiz != quiz) {
      await _flutterTts.stop();
      setState(() {
        _currentlySpeakingQuiz!.isTtsPlaying = false;
      });
    }

    setState(() {
      quiz.isTtsPlaying = true;
      _currentlySpeakingQuiz = quiz;
    });

    double rate = (quiz.playbackSpeed * 0.5).clamp(0.1, 1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setLanguage('it-IT');

    final textToSpeak = quiz.italian.replaceAll(RegExp(r'<[^>]*>'), '');
    await _flutterTts.speak(textToSpeak);
  }

  Future<void> _toggleBanglaAudioPlayback(PatenteQuizItem quiz) async {
    if (quiz.audioUrl == null || quiz.audioUrl!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('এই প্রশ্নের জন্য কোনো বাংলা অডিও আপলোড করা হয়নি')),
      );
      return;
    }

    if (_currentlySpeakingQuiz != null) {
      await _flutterTts.stop();
      setState(() {
        _currentlySpeakingQuiz!.isTtsPlaying = false;
        _currentlySpeakingQuiz = null;
      });
    }

    if (quiz.isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        quiz.isPlaying = false;
        _currentlyPlayingAudioQuiz = null;
      });
    } else {
      if (_currentlyPlayingAudioQuiz != null && _currentlyPlayingAudioQuiz != quiz) {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingAudioQuiz!.isPlaying = false;
          _currentlyPlayingAudioQuiz!.audioProgress = 0.0;
        });
      }

      setState(() {
        quiz.isPlaying = true;
        _currentlyPlayingAudioQuiz = quiz;
      });

      final url = ApiService.formatImageUrl(quiz.audioUrl);
      debugPrint('Playing Bangla Audio MP3 URL: $url');
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.setSource(UrlSource(url));
        await _audioPlayer.setPlaybackRate(quiz.playbackSpeed);
        await _audioPlayer.resume();
      } catch (e) {
        debugPrint('Error playing MP3 audio: $e');
        if (mounted) {
          setState(() {
            quiz.isPlaying = false;
            _currentlyPlayingAudioQuiz = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('অডিও চালাতে সমস্যা হয়েছে: $e')),
          );
        }
      }
    }
  }

  Widget _buildTopHeaderSection(bool isDark) {
    String? bannerImg;
    for (var q in _quizzes) {
      if (q.image != null && q.image!.trim().isNotEmpty) {
        final pos = (q.imagePosition ?? '').toLowerCase();
        if (pos.contains('both') || pos.contains('top') || pos.contains('up') || pos.contains('banner') || pos.contains('header') || pos.contains('sopra') || pos.contains('উভয়')) {
          bannerImg = q.image;
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 14),

          if (bannerImg != null && bannerImg.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Image.network(
                    ApiService.formatImageUrl(bannerImg),
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF121829) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 8),
        child: ElevatedButton(
          onPressed: () {
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
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 4,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'QUIZ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20),
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
                    : Colors.blue.withOpacity(0.03),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
                : RefreshIndicator(
                    onRefresh: _loadQuestions,
                    color: const Color(0xFF22C55E),
                    child: _quizzes.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                              Center(
                                child: Text(
                                  'কোনো প্রশ্ন পাওয়া যায়নি',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 80),
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            children: [
                              _buildTopHeaderSection(isDark),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Column(
                                  children: _quizzes.map((quiz) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: _buildQuizCard(quiz, isDark),
                                    );
                                  }).toList(),
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

  Widget _buildFormattedText(PatenteQuizItem quiz, bool isDark) {
    final rawText = quiz.showBangla ? quiz.bangla : quiz.italian;
    if (quiz.showBangla) {
      return Text(
        rawText,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          height: 1.45,
          color: Colors.green.shade700,
        ),
      );
    }

    final spans = HtmlTextHelper.buildParsedStatementSpans(
      statement: rawText,
      isDark: isDark,
      fontSize: 14.5,
      height: 1.45,
      vocabulary: quiz.vocabulary,
      onTapWord: (rawWord, cleanWord) {
        String? vocabImage;
        String translation = '';

        if (quiz.vocabulary != null) {
          for (var item in quiz.vocabulary!) {
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
        } else if (translation.isEmpty && QuestionDatabase.globalGlossary.containsKey(rawWord.toLowerCase())) {
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

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  String? _resolveEffectiveQuizImage(PatenteQuizItem quiz) {
    if (quiz.image != null &&
        quiz.image!.trim().isNotEmpty &&
        quiz.image!.trim().toLowerCase() != 'null' &&
        quiz.image!.trim().toLowerCase() != 'undefined' &&
        quiz.image!.trim().toLowerCase() != 'none' &&
        !quiz.image!.contains('/data/user/') &&
        !quiz.image!.contains('/data/data/') &&
        !quiz.image!.contains('/storage/emulated/')) {
      return quiz.image!.trim();
    }
    return null;
  }

  Widget _buildQuizCard(PatenteQuizItem quiz, bool isDark) {
    final effectiveImg = _resolveEffectiveQuizImage(quiz);
    final imgUrl = ApiService.formatImageUrl(effectiveImg);

    return Container(
      decoration: BoxDecoration(
        color: quiz.isSelected
            ? (isDark ? const Color(0xFF163224) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF1E294B) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: quiz.isSelected
              ? const Color(0xFF22C55E)
              : (widget.mode == McqScreenMode.wrong
                  ? const Color(0xFFEF4444)
                  : (widget.mode == McqScreenMode.correct
                      ? const Color(0xFF22C55E)
                      : (quiz.sbagliatoCount > 0 && quiz.giustoCount == 0
                          ? const Color(0xFFEF4444)
                          : (quiz.giustoCount > 0 && quiz.sbagliatoCount == 0
                              ? const Color(0xFF22C55E)
                              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)))))),
          width: (quiz.isSelected || widget.mode == McqScreenMode.wrong || widget.mode == McqScreenMode.correct || quiz.sbagliatoCount > 0 || quiz.giustoCount > 0) ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectActive || _quizzes.any((q) => q.isSelected)) {
            setState(() {
              quiz.isSelected = !quiz.isSelected;
            });
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: Number on Left, VERO/FALSO Answer Badge & Eye button on Right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        quiz.id,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: quiz.isSelected ? const Color(0xFF16A34A) : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (quiz.isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF22C55E)),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      // Answer Pill (VERO / FALSO) when Eye button is clicked
                      if (quiz.showAnswer) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: quiz.isVero
                                ? const Color(0xFF22C55E).withOpacity(0.15)
                                : Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: quiz.isVero ? const Color(0xFF22C55E) : Colors.red,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            quiz.isVero ? 'VERO (সঠিক) ✓' : 'FALSO (মিথ্যা) ✗',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: quiz.isVero ? const Color(0xFF16A34A) : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],

                      // "দেখুন" (Eye) Toggle Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            quiz.showAnswer = !quiz.showAnswer;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: quiz.showAnswer ? Colors.blue.withOpacity(0.15) : Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: quiz.showAnswer ? Colors.blue : Colors.transparent,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                quiz.showAnswer ? Icons.visibility_off_outlined : Icons.remove_red_eye_outlined,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                quiz.showAnswer ? 'লুকান' : 'দেখুন',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Main Question Row: Image (Top or Left), Italian Text with Underline
              if (imgUrl.isNotEmpty && (quiz.imagePosition?.toLowerCase().contains('top') == true || quiz.imagePosition?.toLowerCase().contains('center') == true)) ...[
                GestureDetector(
                  onTap: () => ImageZoomDialog.show(context, effectiveImg),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imgUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                _buildFormattedText(quiz, isDark),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imgUrl.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => ImageZoomDialog.show(context, effectiveImg),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 70,
                            maxWidth: 100,
                            minHeight: 65,
                            maxHeight: 95,
                          ),
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imgUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _buildFormattedText(quiz, isDark),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // Audio Player Control Row (Only shown if Bangla MP3 audio URL is provided from admin panel)
              if (quiz.audioUrl != null && quiz.audioUrl!.trim().isNotEmpty) ...[
                Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleBanglaAudioPlayback(quiz),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              quiz.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 16,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 2),
                            const Text('বাংলা', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: const Color(0xFF22C55E),
                          inactiveTrackColor: isDark ? Colors.white10 : Colors.grey.shade200,
                          thumbColor: const Color(0xFF22C55E),
                        ),
                        child: Slider(
                          value: quiz.audioProgress,
                          onChanged: (val) {
                            setState(() {
                              quiz.audioProgress = val;
                            });
                            if (_currentlyPlayingAudioQuiz == quiz && quiz.audioDuration != null) {
                              final seekMs = (val * quiz.audioDuration!.inMilliseconds).round();
                              _audioPlayer.seek(Duration(milliseconds: seekMs));
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Study Note Box if available
              if (quiz.studyNotes.trim().isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2311) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quiz.studyNotes.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 5 Action Buttons Row: ITALIANO, স্পিড, অনুবাদ, সেভ, নোট
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: quiz.isTtsPlaying ? Icons.stop_rounded : Icons.mic_rounded,
                    label: 'ITALIANO',
                    color: quiz.isTtsPlaying ? Colors.orange.shade700 : Colors.green,
                    onTap: () => _speakItalianQuestion(quiz),
                  ),
                  PopupMenuButton<double>(
                    initialValue: quiz.playbackSpeed,
                    tooltip: 'অডিও স্পিড',
                    elevation: 6,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    offset: const Offset(0, -280),
                    onSelected: (double speed) {
                      setState(() {
                        quiz.playbackSpeed = speed;
                      });
                      if (quiz.isTtsPlaying) {
                        double rate = (speed * 0.45).clamp(0.1, 1.0);
                        _flutterTts.setSpeechRate(rate);
                      }
                      if (quiz.isPlaying) {
                        _audioPlayer.setPlaybackRate(speed);
                      }
                    },
                    itemBuilder: (context) => [
                      0.5,
                      0.75,
                      0.85,
                      1.0,
                      1.25,
                      1.5,
                      1.75,
                      2.0,
                    ].map((speed) {
                      final isSelected = (quiz.playbackSpeed == speed);
                      return PopupMenuItem<double>(
                        value: speed,
                        height: 38,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFFDF4) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${speed}x',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? const Color(0xFF22C55E) : Colors.black87,
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_rounded, size: 16, color: Color(0xFF22C55E)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, width: 0.8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed_rounded, size: 18, color: Colors.blue.shade700),
                          const SizedBox(height: 2),
                          Text(
                            '${quiz.playbackSpeed}x',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildActionButton(
                    icon: Icons.translate_rounded,
                    label: 'অনুবাদ',
                    color: Colors.green.shade600,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => FullTranslateDialog(
                          italianText: quiz.italian,
                          banglaText: quiz.bangla,
                          imageUrl: quiz.image,
                          vocabulary: quiz.vocabulary,
                        ),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: quiz.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    label: 'সেভ',
                    color: quiz.isSaved ? Colors.green : Colors.grey.shade700,
                    onTap: () async {
                      final mcq = McqQuestion(
                        id: quiz.rawId,
                        chapter: 1,
                        chapterName: 'Saved',
                        italian: quiz.italian,
                        bangla: quiz.bangla,
                        isVero: quiz.isVero,
                        image: quiz.image,
                      );
                      if (quiz.isSaved) {
                        await BookmarkManager.removeQuestion(quiz.italian, quiz.rawId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('প্রশ্নটি সেভ তালিকা থেকে সরিয়ে দেওয়া হয়েছে')),
                          );
                        }
                      } else {
                        await BookmarkManager.saveQuestion(mcq);
                      }
                      setState(() {
                        quiz.isSaved = !quiz.isSaved;
                      });
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.edit_note_rounded,
                    label: 'নোট',
                    color: (quiz.studyNotes.isNotEmpty) ? const Color(0xFF10B981) : Colors.grey.shade700,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => QuestionNoteDialog(
                          questionId: quiz.id,
                          initialNote: quiz.studyNotes,
                          onSave: (newNote) async {
                            setState(() => quiz.studyNotes = newNote);
                            final mcq = McqQuestion(
                              id: quiz.rawId != 0 ? quiz.rawId : (int.tryParse(quiz.id) ?? 0),
                              chapter: 1,
                              chapterName: 'Noted Question',
                              italian: quiz.italian,
                              bangla: quiz.bangla,
                              isVero: quiz.isVero,
                              image: quiz.image,
                              imagePosition: quiz.imagePosition,
                              audio: quiz.audioUrl,
                              vocabulary: quiz.vocabulary,
                              userNote: newNote,
                              giustoCount: quiz.giustoCount,
                              sbagliatoCount: quiz.sbagliatoCount,
                            );
                            await BookmarkManager.saveNote(mcq, newNote);
                            if (newNote.trim().isEmpty && widget.mode == McqScreenMode.noted) {
                              setState(() {
                                _quizzes.removeWhere((q) => q.italian == quiz.italian);
                              });
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(newNote.isNotEmpty ? 'নোট সফলভাবে সংরক্ষণ করা হয়েছে' : 'নোট মুছে ফেলা হয়েছে'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (quiz.giustoCount > 0 || quiz.sbagliatoCount > 0) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                const SizedBox(height: 10),

                // History stats at bottom of card
                Center(
                  child: Column(
                    children: [
                      Text(
                        '(TU) Hai risposto:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Giusto ${quiz.giustoCount} volte', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                          const SizedBox(width: 14),
                          Text('Sbagliato ${quiz.sbagliatoCount} volte', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }
}
