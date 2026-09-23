import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'triangle_pattern_painter.dart';
import 'google_translate_dialog.dart';
import 'full_translate_dialog.dart';
import 'image_zoom_dialog.dart';
import 'question_note_dialog.dart';
import 'quiz_practice_screen.dart';
import 'exam_simulation_screen.dart';
import '../services/api_service.dart';
import '../services/html_text_helper.dart';
import '../models/mcq_question.dart';
import '../models/bookmark_manager.dart';
import '../models/question_database.dart';

class CartelliScreen extends StatefulWidget {
  const CartelliScreen({super.key});

  @override
  State<CartelliScreen> createState() => _CartelliScreenState();
}

class _CartelliScreenState extends State<CartelliScreen> {
  // Dynamic Categories / Chapters / Pages
  List<dynamic> _apiChapters = [];
  List<dynamic> _apiPages = [];
  List<PatenteQuizItem> _quizzes = [];

  String _selectedCapitolo = 'Caricamento...';
  String _selectedPagina = 'Caricamento...';

  List<String> _capitoli = [];
  List<String> _pagine = [];

  final Map<String, int> _chapterIdMap = {};
  final Map<String, int> _pageIdMap = {};

  bool _isLoadingChapters = false;
  bool _isLoadingPages = false;
  bool _isLoadingQuizzes = false;

  bool _isSelectActive = false;
  String? _pageImage;
  String? _pageImagePosition;

  // Audio and TTS
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  PatenteQuizItem? _currentlyPlayingAudioQuiz;
  PatenteQuizItem? _currentlySpeakingQuiz;

  @override
  void initState() {
    super.initState();
    _initAudioAndTts();
    _loadChapters();
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
      if (mounted && _currentlyPlayingAudioQuiz != null && _currentlyPlayingAudioQuiz!.audioDuration != null) {
        setState(() {
          _currentlyPlayingAudioQuiz!.audioProgress = (p.inMilliseconds / _currentlyPlayingAudioQuiz!.audioDuration!.inMilliseconds).clamp(0.0, 1.0);
        });
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

  Future<void> _loadChapters() async {
    setState(() => _isLoadingChapters = true);
    final chaptersData = await ApiService.fetchCartelliChapters();
    if (mounted) {
      if (chaptersData.isNotEmpty) {
        _apiChapters = chaptersData;
        _chapterIdMap.clear();
        _capitoli = chaptersData.map((c) {
          final id = c['id'] is int ? c['id'] as int : int.tryParse('${c['id']}') ?? 1;
          final chapNum = c['chapter_number'] ?? id;
          final name = (c['name'] ?? c['bn_name'] ?? 'Capitolo $id').toString().toUpperCase();
          final key = 'Capitolo $chapNum) $name';
          _chapterIdMap[key] = id;
          return key;
        }).toList();

        _selectedCapitolo = _capitoli.first;
        await _loadPagesForSelectedChapter();
      } else {
        setState(() {
          _isLoadingChapters = false;
          _selectedCapitolo = 'Nessun Capitolo Trovato';
        });
      }
    }
  }

  Future<void> _loadPagesForSelectedChapter() async {
    final chapterId = _chapterIdMap[_selectedCapitolo] ?? 1;
    setState(() => _isLoadingPages = true);
    final pagesData = await ApiService.fetchCartelliPages(chapterId);

    if (mounted) {
      _apiPages = pagesData;
      _pageIdMap.clear();

      if (pagesData.isNotEmpty) {
        _pagine = pagesData.map((p) {
          final pId = p['id'] is int ? p['id'] as int : int.tryParse('${p['id']}') ?? 1;
          final pageNum = p['page_number'] ?? p['sort_order'] ?? pId;
          final title = (p['title'] ?? p['bn_title'] ?? 'Pagina $pageNum').toString();
          final key = 'Pagina $pageNum) $title';
          _pageIdMap[key] = pId;
          return key;
        }).toList();
        _selectedPagina = _pagine.first;
      } else {
        _pagine = ['Tutte le pagine'];
        _selectedPagina = 'Tutte le pagine';
      }

      await _loadQuizzesForSelectedPage();
    }
  }

  Future<void> _loadQuizzesForSelectedPage() async {
    setState(() => _isLoadingQuizzes = true);
    final pageId = _pageIdMap[_selectedPagina];

    List<dynamic> rawMcqs = [];
    String? pageImg;
    String? pageImgPos;

    if (pageId != null) {
      final pageData = _apiPages.firstWhere(
        (p) => (p['id'] is int ? p['id'] : int.tryParse('${p['id']}')) == pageId,
        orElse: () => null,
      );
      if (pageData != null) {
        for (final k in ['image', 'image_path', 'cover_image', 'image_url', 'img', 'photo', 'page_image', 'thumbnail']) {
          final val = pageData[k]?.toString().trim();
          if (val != null && val.isNotEmpty && val.toLowerCase() != 'null' && val.toLowerCase() != 'undefined') {
            pageImg = val;
            break;
          }
        }
        pageImgPos = (pageData['image_position'] ?? pageData['position'] ?? pageData['img_position'])?.toString();
      }
      rawMcqs = await ApiService.fetchCartelliPageMcqs(pageId);
    } else {
      for (var page in _apiPages) {
        final pId = page['id'] is int ? page['id'] as int : int.tryParse('${page['id']}') ?? 1;
        if (pageImg == null || pageImg.isEmpty) {
          for (final k in ['image', 'image_path', 'cover_image', 'image_url', 'img', 'photo', 'page_image', 'thumbnail']) {
            final val = page[k]?.toString().trim();
            if (val != null && val.isNotEmpty && val.toLowerCase() != 'null' && val.toLowerCase() != 'undefined') {
              pageImg = val;
              break;
            }
          }
          pageImgPos = (page['image_position'] ?? page['position'] ?? page['img_position'])?.toString();
        }
        final list = await ApiService.fetchCartelliPageMcqs(pId);
        rawMcqs.addAll(list);
      }
    }

    if (mounted) {
      List<PatenteQuizItem> loadedQuizzes = [];

      for (int i = 0; i < rawMcqs.length; i++) {
        final q = rawMcqs[i];
        final idStr = '${i + 1}';

        final rawIsVero = q['is_vero'] ?? q['correct_answer'] ?? q['answer'] ?? true;
        bool isVero = true;
        if (rawIsVero is bool) {
          isVero = rawIsVero;
        } else if (rawIsVero is String) {
          isVero = rawIsVero.toLowerCase() == 'vero' || rawIsVero == '1' || rawIsVero.toLowerCase() == 'true';
        } else if (rawIsVero is int) {
          isVero = rawIsVero == 1;
        }

        final vocabs = q['vocabulary'] ?? q['vocabulary_underlines'];
        String? img = (q['image'] ?? q['image_path'] ?? q['img'] ?? q['photo'])?.toString();
        if (img == null || img.trim().isEmpty || img.trim().toLowerCase() == 'null' || img.trim().toLowerCase() == 'undefined') {
          if (vocabs is List && vocabs.isNotEmpty) {
            for (var v in vocabs) {
              if (v is Map) {
                final vImg = (v['image'] ?? v['image_path'] ?? v['img'] ?? v['photo'] ?? v['image_url'])?.toString().trim();
                if (vImg != null && vImg.isNotEmpty && vImg.toLowerCase() != 'null' && vImg.toLowerCase() != 'undefined') {
                  img = vImg;
                  break;
                }
              }
            }
          }
        }
        if (img == null || img.trim().isEmpty || img.trim().toLowerCase() == 'null') {
          img = pageImg;
        }
        final rawImgPos = (q['image_position'] ?? q['position'] ?? q['img_position'] ?? q['image_location'] ?? pageImgPos ?? 'left').toString();

        final rawIdVal = q['id'] is int ? q['id'] as int : int.tryParse('${q['id']}') ?? (i + 1);
        final audioUrl = q['audio'] ?? q['voice'] ?? q['mp3'] ?? q['audio_url'];

        final quizItem = PatenteQuizItem(
          rawId: rawIdVal,
          id: idStr,
          italian: (q['italian'] ?? q['question'] ?? '').toString(),
          bangla: (q['bangla'] ?? q['bn_question'] ?? q['bn_translation'] ?? '').toString(),
          isVero: isVero,
          audioNote: '',
          image: img,
          imagePosition: rawImgPos,
          audioUrl: audioUrl?.toString(),
          vocabulary: q['vocabulary'] ?? q['vocabulary_underlines'],
        );

        final stats = await BookmarkManager.getQuestionStats(quizItem.italian);
        quizItem.isSaved = stats['saved'] as bool? ?? false;
        quizItem.giustoCount = stats['giusto'] as int? ?? (q['correct_count'] is int ? q['correct_count'] : int.tryParse('${q['correct_count']}') ?? 0);
        quizItem.sbagliatoCount = stats['sbagliato'] as int? ?? (q['wrong_count'] is int ? q['wrong_count'] : int.tryParse('${q['wrong_count']}') ?? 0);
        quizItem.studyNotes = (stats['note'] as String?) ?? '';
        loadedQuizzes.add(quizItem);
      }

      setState(() {
        _quizzes = loadedQuizzes;
        _pageImage = pageImg;
        _pageImagePosition = pageImgPos;
        _isLoadingChapters = false;
        _isLoadingPages = false;
        _isLoadingQuizzes = false;
      });
    }
  }

  void _unselectAll() {
    setState(() {
      _isSelectActive = false;
      for (var q in _quizzes) {
        q.isSelected = false;
      }
    });
  }

  void _onSelectButtonPressed() {
    setState(() {
      _isSelectActive = true;
      for (var q in _quizzes) {
        q.isSelected = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _isSelectActive = true;
      for (var q in _quizzes) {
        q.isSelected = true;
      }
    });
  }

  Future<void> _speakItalianQuestion(PatenteQuizItem quiz) async {
    if (_currentlyPlayingAudioQuiz != null) {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingAudioQuiz!.isPlaying = false;
        _currentlyPlayingAudioQuiz!.audioProgress = 0.0;
        _currentlyPlayingAudioQuiz = null;
      });
    }

    if (_currentlySpeakingQuiz == quiz && quiz.isTtsPlaying) {
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

    double rate = (quiz.playbackSpeed * 0.45).clamp(0.1, 1.0);
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

  void _startSelectedQuizPractice() {
    final selectedQuizzes = _quizzes.where((q) => q.isSelected).toList();
    final targetQuizzes = selectedQuizzes.isNotEmpty ? selectedQuizzes : _quizzes;

    if (targetQuizzes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অনুশীলনের জন্য কোনো প্রশ্ন পাওয়া যায়নি')),
      );
      return;
    }

    final mcqList = targetQuizzes.map((q) {
      return McqQuestion(
        id: int.tryParse(q.id) ?? 1,
        chapter: _chapterIdMap[_selectedCapitolo] ?? 1,
        chapterName: _selectedCapitolo,
        italian: q.italian,
        bangla: q.bangla,
        isVero: q.isVero,
        image: (q.image != null && q.image!.trim().isNotEmpty && q.image!.toLowerCase() != 'null') ? q.image : _pageImage,
        imagePosition: q.imagePosition ?? _pageImagePosition,
        audio: q.audioUrl,
        vocabulary: q.vocabulary,
      );
    }).toList();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamSimulationScreen(
          customQuestions: mcqList,
          examTitle: _selectedCapitolo,
        ),
      ),
    );

    if (mounted) {
      for (var quiz in _quizzes) {
        final stats = await BookmarkManager.getQuestionStats(quiz.italian);
        if (mounted) {
          setState(() {
            quiz.isSaved = stats['saved'] as bool? ?? false;
            quiz.giustoCount = stats['giusto'] as int? ?? quiz.giustoCount;
            quiz.sbagliatoCount = stats['sbagliato'] as int? ?? quiz.sbagliatoCount;
            if ((stats['note'] as String?)?.isNotEmpty == true) {
              quiz.studyNotes = stats['note'] as String;
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartelli'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startSelectedQuizPractice,
        backgroundColor: const Color(0xFF22C55E),
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.quiz_rounded, size: 20, color: Colors.white),
        label: const Row(
          children: [
            Text('QUIZ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5, color: Colors.white)),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: TrianglePatternPainter(
                triangleColor: isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.green.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopHeaderSection(isDark),
                Expanded(
                  child: _isLoadingQuizzes
                      ? const Center(child: CircularProgressIndicator())
                      : _quizzes.isEmpty
                          ? const Center(
                              child: Text('এই চ্যাপ্টারে কোনো প্রশ্ন পাওয়া যায়নি', style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 85),
                              itemCount: _quizzes.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final quiz = _quizzes[index];
                                return _buildQuizCard(quiz, isDark);
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

  Widget _buildTopHeaderSection(bool isDark) {
    String? bannerImg;
    final pos = (_pageImagePosition ?? '').toLowerCase().trim();
    if (pos.contains('both') ||
        pos.contains('top') ||
        pos.contains('up') ||
        pos.contains('banner') ||
        pos.contains('header') ||
        pos.contains('sopra') ||
        pos.contains('উভয়')) {
      bannerImg = _pageImage;
    }

    if (bannerImg == null || bannerImg.trim().isEmpty) {
      for (var q in _quizzes) {
        if (q.image != null && q.image!.trim().isNotEmpty) {
          final qPos = (q.imagePosition ?? '').toLowerCase().trim();
          if (qPos.contains('both') ||
              qPos.contains('top') ||
              qPos.contains('up') ||
              qPos.contains('banner') ||
              qPos.contains('header') ||
              qPos.contains('sopra') ||
              qPos.contains('উভয়')) {
            bannerImg = q.image;
            break;
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        children: [
          // Dropdown 1: Capitolo
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _capitoli.contains(_selectedCapitolo) ? _selectedCapitolo : (_capitoli.isNotEmpty ? _capitoli.first : _selectedCapitolo),
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 24),
                  items: _capitoli.map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(
                        val,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() {
                        _selectedCapitolo = val;
                      });
                      await _loadPagesForSelectedChapter();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Dropdown 2: Pagina
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _pagine.contains(_selectedPagina) ? _selectedPagina : (_pagine.isNotEmpty ? _pagine.first : _selectedPagina),
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 24),
                  items: _pagine.map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(
                        val,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() {
                        _selectedPagina = val;
                      });
                      await _loadQuizzesForSelectedPage();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Buttons Row: Select All (Left), Select (Middle, hidden when active), Unselect All (Right)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    foregroundColor: const Color(0xFF22C55E),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Select All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              if (!_isSelectActive) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onSelectButtonPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      foregroundColor: isDark ? Colors.white70 : Colors.grey.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Select', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _unselectAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    foregroundColor: isDark ? Colors.white70 : Colors.grey.shade800,
                    elevation: 0,
                    side: BorderSide(color: Colors.grey.shade300, width: 1.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Unselect All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          // Banner Image Card if image exists and position is top/both/banner/sopra
          if (bannerImg != null && bannerImg.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  ApiService.formatImageUrl(bannerImg),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.traffic_rounded, size: 50, color: Color(0xFF4CAF50)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _resolveEffectiveQuizImage(PatenteQuizItem quiz) {
    if (quiz.image != null &&
        quiz.image!.trim().isNotEmpty &&
        quiz.image!.trim().toLowerCase() != 'null' &&
        quiz.image!.trim().toLowerCase() != 'undefined' &&
        quiz.image!.trim().toLowerCase() != 'none' &&
        !quiz.image!.contains('/uploads/vocabulary/') &&
        !quiz.image!.contains('vocab_') &&
        !quiz.image!.contains('/data/user/') &&
        !quiz.image!.contains('/data/data/') &&
        !quiz.image!.contains('/storage/emulated/') &&
        !quiz.image!.contains('scaled_IMG') &&
        !quiz.image!.toLowerCase().contains('placeholder') &&
        !quiz.image!.contains('default_image')) {
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
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: quiz.isSelected ? 2.0 : 1.5,
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
              _isSelectActive = _quizzes.any((q) => q.isSelected);
            });
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Number on Left, eye button on Right
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
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
                      ],
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        quiz.showBangla = !quiz.showBangla;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: quiz.showBangla ? const Color(0xFFEFFDF4) : Colors.blue.shade50.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: quiz.showBangla ? const Color(0xFF22C55E) : Colors.blue.shade200,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            quiz.showBangla ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 14,
                            color: quiz.showBangla ? const Color(0xFF16A34A) : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            quiz.showBangla ? 'লুকান' : 'দেখুন',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: quiz.showBangla ? const Color(0xFF16A34A) : Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Main Question Content Row: Fixed 100px Left Image Slot + Right Text Column
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. FIXED 100px LEFT SLOT: Renders image if available, else remains BLANK/EMPTY!
                  Container(
                    width: 100,
                    height: 100,
                    alignment: Alignment.topCenter,
                    child: imgUrl.isNotEmpty
                        ? GestureDetector(
                            onTap: () => ImageZoomDialog.show(context, imgUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imgUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const SizedBox(width: 100, height: 100),
                              ),
                            ),
                          )
                        : const SizedBox(width: 100, height: 100), // Reserved blank empty slot!
                  ),
                  const SizedBox(width: 12),

                  // 2. RIGHT TEXT COLUMN
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Italian text parsed with HtmlTextHelper
                        RichText(
                          text: TextSpan(
                            children: HtmlTextHelper.buildParsedStatementSpans(
                              statement: quiz.italian,
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
                                    isSaved: quiz.isSaved,
                                    hasNote: quiz.studyNotes.trim().isNotEmpty,
                                    onToggleSave: () => _toggleQuizSave(quiz),
                                    onOpenNote: () => _openNoteDialog(quiz),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (quiz.showBangla && quiz.bangla.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            quiz.bangla,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Audio player toolbar
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
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

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
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_rounded, size: 16, color: Color(0xFF22C55E)),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                '$speed',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? const Color(0xFF16A34A) : Colors.black87,
                                ),
                              ),
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
                          Icon(Icons.speed_rounded, size: 18, color: Colors.green.shade600),
                          const SizedBox(height: 2),
                          Text(
                            'স্পিড',
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
                          imageUrl: (quiz.image != null && quiz.image!.trim().isNotEmpty && quiz.image!.toLowerCase() != 'null')
                              ? quiz.image
                              : _pageImage,
                          vocabulary: quiz.vocabulary,
                        ),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: quiz.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    label: 'সেভ',
                    color: quiz.isSaved ? Colors.green : Colors.grey.shade700,
                    onTap: () => _toggleQuizSave(quiz),
                  ),
                  _buildActionButton(
                    icon: Icons.edit_note_rounded,
                    label: 'নোট',
                    color: Colors.grey.shade700,
                    onTap: () => _openNoteDialog(quiz),
                  ),
                ],
              ),
              if (quiz.giustoCount > 0 || quiz.sbagliatoCount > 0) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                const SizedBox(height: 10),

                // Answer stats at bottom of card (Only shown when attempted)
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

  Future<void> _toggleQuizSave(PatenteQuizItem quiz) async {
    final mcq = McqQuestion(
      id: quiz.rawId,
      chapter: 1,
      chapterName: _selectedCapitolo,
      italian: quiz.italian,
      bangla: quiz.bangla,
      isVero: quiz.isVero,
      image: quiz.image,
      vocabulary: quiz.vocabulary,
    );
    if (quiz.isSaved) {
      await BookmarkManager.removeQuestion(quiz.italian, quiz.rawId, 'cartelli');
    } else {
      await BookmarkManager.saveQuestion(mcq, type: 'cartelli');
    }
    if (mounted) {
      setState(() => quiz.isSaved = !quiz.isSaved);
    }
  }

  void _openNoteDialog(PatenteQuizItem quiz) {
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
            chapterName: _selectedCapitolo,
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
          await BookmarkManager.saveNote(mcq, newNote, type: 'cartelli');
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
  }
}
