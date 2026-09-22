import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'triangle_pattern_painter.dart';
import '../models/mcq_question.dart';
import '../models/question_database.dart';
import '../models/bookmark_manager.dart';
import '../services/api_service.dart';
import '../services/html_text_helper.dart';
import 'google_translate_dialog.dart';
import 'full_translate_dialog.dart';
import 'question_note_dialog.dart';
import 'image_zoom_dialog.dart';
import 'exam_simulation_screen.dart';

class PatenteQuizItem {
  final int rawId;
  final String id;
  final String italian;
  final String bangla;
  final bool isVero;
  final String audioNote;
  final String? image;
  final String? imagePosition;
  final String? audioUrl;
  final List<dynamic>? vocabulary;
  bool? userSelectedVero;
  bool isSaved;
  bool isSelected;
  bool showAnswer;
  bool isAudioPlayerVisible;
  bool isPlaying; // Bangla MP3 audio playing state
  bool isTtsPlaying; // Italian TTS speaking state
  Duration? audioDuration;
  double audioProgress;
  double playbackSpeed;
  String studyNotes;
  int giustoCount;
  int sbagliatoCount;
  bool showBangla;

  PatenteQuizItem({
    required this.rawId,
    required this.id,
    required this.italian,
    required this.bangla,
    required this.isVero,
    required this.audioNote,
    this.image,
    this.imagePosition,
    this.audioUrl,
    this.vocabulary,
    this.userSelectedVero,
    this.isSaved = false,
    this.isSelected = false,
    this.showAnswer = false,
    this.isAudioPlayerVisible = false,
    this.isPlaying = false,
    this.isTtsPlaying = false,
    this.audioDuration,
    this.audioProgress = 0.0,
    this.playbackSpeed = 1.0,
    this.studyNotes = '',
    this.giustoCount = 1,
    this.sbagliatoCount = 0,
    this.showBangla = false,
  });
}

class QuizPracticeScreen extends StatefulWidget {
  final int? initialChapterId;
  final int? initialPage;
  final List<McqQuestion>? questions;
  final String? quizTitle;
  final String? initialPageImage;
  final String? initialPageImagePosition;

  const QuizPracticeScreen({
    super.key,
    this.initialChapterId,
    this.initialPage,
    this.questions,
    this.quizTitle,
    this.initialPageImage,
    this.initialPageImagePosition,
  });

  @override
  State<QuizPracticeScreen> createState() => _QuizPracticeScreenState();
}

class _QuizPracticeScreenState extends State<QuizPracticeScreen> {
  late List<PatenteQuizItem> _quizzes;
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  PatenteQuizItem? _currentlySpeakingQuiz;
  PatenteQuizItem? _currentlyPlayingAudioQuiz;
  bool _isSelectActive = false;

  void _unselectAll() {
    setState(() {
      _isSelectActive = false;
      for (var quiz in _quizzes) {
        quiz.isSelected = false;
      }
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectActive = !_isSelectActive;
      if (!_isSelectActive) {
        for (var quiz in _quizzes) {
          quiz.isSelected = false;
        }
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

  late String _selectedCapitolo;
  late String _selectedPagina;
  String? _pageImage;
  String? _pageImagePosition;

  List<String> _capitoli = [];
  List<String> _pagine = [];
  List<dynamic> _apiChapters = [];

  @override
  void initState() {
    super.initState();
    _selectedCapitolo = 'Caricamento...';
    _selectedPagina = 'Pagina 1';
    _quizzes = [];
    _initAudioAndTts();
    _initChaptersAndQuizzes();
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

  Future<void> _initChaptersAndQuizzes() async {
    _apiChapters = await ApiService.fetchChapters();
    if (mounted) {
      if (_apiChapters.isNotEmpty) {
        int? targetChapId = widget.initialChapterId;
        if (targetChapId == null && widget.questions != null && widget.questions!.isNotEmpty) {
          targetChapId = widget.questions!.first.chapter;
        }
        if (targetChapId == null && widget.quizTitle != null) {
          final match = RegExp(r'Capitolo (\d+)', caseSensitive: false).firstMatch(widget.quizTitle!);
          if (match != null) {
            targetChapId = int.tryParse(match.group(1)!);
          }
        }

        setState(() {
          _capitoli = _apiChapters.map((ch) {
            final id = ch['id'] is int ? ch['id'] as int : int.tryParse('${ch['id']}') ?? 1;
            final chapNum = ch['chapter_number'] ?? id;
            final name = (ch['name'] ?? ch['title'] ?? 'Capitolo $id').toString().toUpperCase();
            return 'Capitolo $chapNum) $name';
          }).toList();

          if (targetChapId != null) {
            final found = _apiChapters.firstWhere(
              (c) {
                final cId = c['id'] is int ? c['id'] as int : int.tryParse('${c['id']}');
                final cNum = c['chapter_number'] is int ? c['chapter_number'] as int : int.tryParse('${c['chapter_number']}');
                return cId == targetChapId || cNum == targetChapId;
              },
              orElse: () => _apiChapters.first,
            );
            final id = found['id'] is int ? found['id'] as int : int.tryParse('${found['id']}') ?? 1;
            final chapNum = found['chapter_number'] ?? id;
            final name = (found['name'] ?? found['title'] ?? 'Capitolo $id').toString().toUpperCase();
            _selectedCapitolo = 'Capitolo $chapNum) $name';
          } else {
            _selectedCapitolo = _capitoli.first;
          }
        });
      } else {
        setState(() {
          _capitoli = [];
          _selectedCapitolo = 'Nessun Capitolo';
        });
      }
    }
    await _loadQuizzes(isInitial: true);
  }

  int _getSelectedChapterId() {
    for (var ch in _apiChapters) {
      final id = ch['id'] is int ? ch['id'] as int : int.tryParse('${ch['id']}') ?? 1;
      final chapNum = ch['chapter_number'] ?? id;
      final name = (ch['name'] ?? ch['title'] ?? 'Capitolo $id').toString().toUpperCase();
      final key = 'Capitolo $chapNum) $name';
      if (key == _selectedCapitolo) {
        return id;
      }
    }
    final RegExp regExp = RegExp(r'Capitolo (\d+)\)');
    final match = regExp.firstMatch(_selectedCapitolo);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return widget.initialChapterId ?? 1;
  }

  Future<void> _loadPagesForChapter() async {
    final chapterId = _getSelectedChapterId();
    final apiPages = await ApiService.fetchChapterPages(chapterId);

    if (apiPages.isNotEmpty && mounted) {
      setState(() {
        _pagine = apiPages.map((p) {
          final pageNum = p['sort_order'] ?? p['id'];
          final title = p['title'] ?? 'Pagina $pageNum';
          return 'Pagina $pageNum) $title';
        }).toList();
        _selectedPagina = _pagine.first;
      });
      await _loadQuizzesForCurrentPage(apiPages);
    }
  }

  Future<void> _loadQuizzesForCurrentPage(List<dynamic> apiPages) async {
    final selectedPageIndex = _pagine.indexOf(_selectedPagina);
    final activePageMap = (selectedPageIndex != -1 && selectedPageIndex < apiPages.length)
        ? apiPages[selectedPageIndex]
        : apiPages.first;
    final pId = activePageMap['id'] is int ? activePageMap['id'] as int : int.tryParse('${activePageMap['id']}') ?? 1;

    final details = await ApiService.fetchPageDetails(pId);
    if (details != null && mounted) {
      String? pageImg;
      if (details['page'] is Map) {
        final pMap = details['page'] as Map;
        pageImg = (pMap['image'] ?? pMap['image_path'] ?? pMap['cover_image'] ?? pMap['image_url'] ?? pMap['img'])?.toString();
      }
      if (pageImg == null || pageImg.trim().isEmpty || pageImg.trim().toLowerCase() == 'null') {
        pageImg = (details['image'] ?? details['image_path'] ?? details['cover_image'] ?? details['image_url'] ?? details['img'] ?? details['photo'] ?? details['page_image'])?.toString();
      }
      if (pageImg == null || pageImg.trim().isEmpty || pageImg.trim().toLowerCase() == 'null') {
        pageImg = (activePageMap['image'] ?? activePageMap['image_path'] ?? activePageMap['cover_image'] ?? activePageMap['image_url'] ?? activePageMap['img'] ?? activePageMap['photo'] ?? activePageMap['thumbnail'])?.toString();
      }
      if (pageImg == null || pageImg.trim().isEmpty || pageImg.trim().toLowerCase() == 'null') {
        pageImg = widget.initialPageImage;
      }
      final pos = (details['image_position'] ?? details['position'] ?? details['img_position'] ?? details['image_location'] ?? activePageMap['image_position'] ?? widget.initialPageImagePosition ?? 'left')?.toString();

      setState(() {
        _pageImage = pageImg != null && pageImg.isNotEmpty ? ApiService.formatImageUrl(pageImg) : null;
        _pageImagePosition = pos;
      });
      List<dynamic> rawQuestions = [];
      if (details['questions'] is List && (details['questions'] as List).isNotEmpty) {
        rawQuestions = details['questions'] as List;
      } else {
        rawQuestions = await ApiService.fetchCartelliPageMcqs(pId);
      }

      if (rawQuestions.isNotEmpty && mounted) {
        final apiQuestions = rawQuestions.map((q) => q is McqQuestion ? q : McqQuestion.fromJson(q)).toList();
        setState(() {
          _quizzes = List.generate(apiQuestions.length, (index) {
            final q = apiQuestions[index];
            return PatenteQuizItem(
              rawId: q.id,
              id: '${index + 1}',
              italian: q.italian,
              bangla: q.bangla,
              isVero: q.isVero,
              image: q.image,
              imagePosition: q.imagePosition ?? pos,
              audioUrl: q.audio,
              vocabulary: q.vocabulary,
              audioNote: q.isVero
                  ? 'এটি সত্য (Vero)। কারণ ট্রাফিক নিয়ম অনুযায়ী এই বিবরণটি সঠিক।'
                  : 'এটি মিথ্যা (Falso)। কারণ ট্রাফিক নিয়ম অনুযায়ী এই বিবরণটি ভুল।',
              giustoCount: 0,
              sbagliatoCount: 0,
            );
          });
        });
        _syncSavedStatus();
      }
    }
  }

  Future<void> _loadQuizzes({bool isInitial = false}) async {
    final chapterId = _getSelectedChapterId();
    final apiPages = await ApiService.fetchChapterPages(chapterId);

    if (apiPages.isNotEmpty && mounted) {
      setState(() {
        _pagine = apiPages.map((p) {
          final pageNum = p['sort_order'] ?? p['id'];
          final title = p['title'] ?? 'Pagina $pageNum';
          return 'Pagina $pageNum) $title';
        }).toList();

        if (isInitial && widget.initialPage != null) {
          final foundPage = apiPages.firstWhere(
            (p) {
              final pId = p['id'] is int ? p['id'] as int : int.tryParse('${p['id']}');
              final pNum = p['page_number'] is int ? p['page_number'] as int : int.tryParse('${p['page_number']}');
              final pSort = p['sort_order'] is int ? p['sort_order'] as int : int.tryParse('${p['sort_order']}');
              return pId == widget.initialPage || pNum == widget.initialPage || pSort == widget.initialPage;
            },
            orElse: () => apiPages.first,
          );
          final pageNum = foundPage['sort_order'] ?? foundPage['id'];
          final title = foundPage['title'] ?? 'Pagina $pageNum';
          _selectedPagina = 'Pagina $pageNum) $title';
        } else if (isInitial && widget.quizTitle != null) {
          final foundPage = apiPages.firstWhere(
            (p) => p['title'] != null && widget.quizTitle!.toLowerCase().contains(p['title'].toString().toLowerCase()),
            orElse: () => apiPages.first,
          );
          final pageNum = foundPage['sort_order'] ?? foundPage['id'];
          final title = foundPage['title'] ?? 'Pagina $pageNum';
          _selectedPagina = 'Pagina $pageNum) $title';
        } else {
          if (!_pagine.contains(_selectedPagina)) {
            _selectedPagina = _pagine.first;
          }
        }
      });

      if (isInitial && widget.questions != null && widget.questions!.isNotEmpty) {
        setState(() {
          _pageImage = widget.initialPageImage ?? widget.questions!.first.image;
          _pageImagePosition = widget.initialPageImagePosition ?? widget.questions!.first.imagePosition;
          _quizzes = List.generate(widget.questions!.length, (index) {
            final q = widget.questions![index];
            return PatenteQuizItem(
              rawId: q.id,
              id: '${index + 1}',
              italian: q.italian,
              bangla: q.bangla,
              isVero: q.isVero,
              image: q.image,
              imagePosition: q.imagePosition,
              audioUrl: q.audio,
              vocabulary: q.vocabulary,
              audioNote: q.isVero
                  ? 'এটি সত্য (Vero)। কারণ ট্রাফিক নিয়ম অনুযায়ী এই বিবরণটি সঠিক।'
                  : 'এটি মিথ্যা (Falso)। কারণ ট্রাফিক নিয়ম অনুযায়ী এই বিবরণটি ভুল।',
              giustoCount: 0,
              sbagliatoCount: 0,
            );
          });
        });
        _syncSavedStatus();
        return;
      }

      await _loadQuizzesForCurrentPage(apiPages);
      return;
    }

    if (widget.questions != null && widget.questions!.isNotEmpty) {
      setState(() {
        _quizzes = List.generate(widget.questions!.length, (index) {
          final q = widget.questions![index];
          return PatenteQuizItem(
            rawId: q.id,
            id: '${index + 1}',
            italian: q.italian,
            bangla: q.bangla,
            isVero: q.isVero,
            image: q.image,
            imagePosition: q.imagePosition,
            audioUrl: q.audio,
            vocabulary: q.vocabulary,
            audioNote: q.isVero
                ? 'এটি সত্য (Vero)। কারণ ট্রাফিক নিয়ম অনুযায়ী এই বিবরণটি সঠিক।'
                : 'এটি মিথ্যা (Falso)। কারণ ট্রাফিক নিয়ম অনুযায়ী এই বিবরণটি ভুল।',
            giustoCount: 0,
            sbagliatoCount: 0,
          );
        });
      });
      _syncSavedStatus();
    }
  }

  Future<void> _syncSavedStatus() async {
    for (var quiz in _quizzes) {
      final saved = await BookmarkManager.isSaved(quiz.italian);
      if (mounted) {
        setState(() {
          quiz.isSaved = saved;
        });
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
    super.dispose();
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
                  onChanged: (val) {
                    if (val != null && val != _selectedCapitolo) {
                      setState(() {
                        _selectedCapitolo = val;
                      });
                      _loadPagesForChapter();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

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
                    if (val != null && val != _selectedPagina) {
                      setState(() {
                        _selectedPagina = val;
                      });
                      final chapterId = _getSelectedChapterId();
                      final apiPages = await ApiService.fetchChapterPages(chapterId);
                      await _loadQuizzesForCurrentPage(apiPages);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Select All (Left), Select (Middle, hidden when active), Unselect All (Right)
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
                    onPressed: _toggleSelectMode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      foregroundColor: isDark ? Colors.white70 : Colors.grey.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
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
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Unselect All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        title: const Text('mbanglabatenteb', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            final selectedList = _quizzes.where((q) => q.isSelected).toList();
            final targetQuizzes = selectedList.isNotEmpty ? selectedList : _quizzes;

            if (targetQuizzes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('কোনো প্রশ্ন পাওয়া যায়নি')),
              );
              return;
            }

            final mcqList = targetQuizzes.map((q) {
              return McqQuestion(
                id: q.rawId,
                chapter: _getSelectedChapterId(),
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

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExamSimulationScreen(
                  customQuestions: mcqList,
                  examTitle: _selectedPagina,
                ),
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
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              physics: const BouncingScrollPhysics(),
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
        quiz.image!.trim().toLowerCase() != 'none') {
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
                          maxWidth: 100,
                          maxHeight: 95,
                          minWidth: 70,
                          minHeight: 65,
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
                      chapterName: _selectedCapitolo,
                      italian: quiz.italian,
                      bangla: quiz.bangla,
                      isVero: quiz.isVero,
                      image: quiz.image,
                      vocabulary: quiz.vocabulary,
                    );
                    if (quiz.isSaved) {
                      await BookmarkManager.removeQuestion(quiz.italian, quiz.rawId, 'argomenti');
                    } else {
                      await BookmarkManager.saveQuestion(mcq, type: 'argomenti');
                    }
                    setState(() => quiz.isSaved = !quiz.isSaved);
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
                            chapter: widget.initialChapterId ?? 1,
                            chapterName: widget.quizTitle ?? 'Argomenti',
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
                          await BookmarkManager.saveNote(mcq, newNote, type: 'argomenti');
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

              // History stats at bottom of card (Only shown when attempted)
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
