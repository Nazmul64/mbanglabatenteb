import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'triangle_pattern_painter.dart';
import 'google_translate_dialog.dart';
import 'full_translate_dialog.dart';
import 'question_note_dialog.dart';
import 'tutor_chat_screen.dart';
import '../models/bookmark_manager.dart';
import '../models/mcq_question.dart';
import '../services/api_service.dart';
import '../services/html_text_helper.dart';
import '../models/question_database.dart';

class ExamResultItem {
  final int index;
  final String italian;
  final String bangla;
  final bool isVero;
  final bool? userSelectedVero;
  final String chapterName;
  final int chapter;
  final String? image;
  final String? audio;
  final List<dynamic>? vocabulary;
  final Map<String, String> vocabularyHelp;

  ExamResultItem({
    required this.index,
    required this.italian,
    required this.bangla,
    required this.isVero,
    required this.userSelectedVero,
    required this.chapterName,
    this.chapter = 1,
    this.image,
    this.audio,
    this.vocabulary,
    this.vocabularyHelp = const {},
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

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  int? _activeAudioIndex;
  bool _isPlayingAudio = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  int? _activeTtsIndex;
  bool _isTtsPlaying = false;

  @override
  void initState() {
    super.initState();
    _initAudioHandlers();
  }

  void _initAudioHandlers() {
    _flutterTts.setLanguage('it-IT');
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.45);
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isTtsPlaying = false;
          _activeTtsIndex = null;
        });
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = (state == PlayerState.playing);
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _audioPosition = pos;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _audioDuration = dur;
        });
      }
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _speakItalian(int itemIndex, String text) async {
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingAudio = false);
    }

    if (_isTtsPlaying && _activeTtsIndex == itemIndex) {
      await _flutterTts.stop();
      setState(() {
        _isTtsPlaying = false;
        _activeTtsIndex = null;
      });
      return;
    }

    setState(() {
      _isTtsPlaying = true;
      _activeTtsIndex = itemIndex;
    });

    final clean = text.replaceAll(RegExp(r'<[^>]*>'), '');
    await _flutterTts.speak(clean);
  }

  Future<void> _toggleAudioPlayback(int itemIndex, String? audioUrl) async {
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
        _activeTtsIndex = null;
      });
    }

    if (_isPlayingAudio && _activeAudioIndex == itemIndex) {
      await _audioPlayer.pause();
      setState(() => _isPlayingAudio = false);
    } else {
      setState(() {
        _activeAudioIndex = itemIndex;
        _isPlayingAudio = true;
      });

      final url = ApiService.formatImageUrl(audioUrl);
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.setSource(UrlSource(url));
        await _audioPlayer.resume();
      } catch (e) {
        debugPrint('Error playing MP3 audio in results: $e');
        if (mounted) {
          setState(() => _isPlayingAudio = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final total = widget.results.length;
    final correct = widget.results.where((r) => r.isAttempted && r.isCorrect).length;
    final incorrect = widget.results.where((r) => r.isAttempted && !r.isCorrect).length;
    final noResponse = widget.results.where((r) => !r.isAttempted).length;

    final bool isPassed = total >= 30
        ? (incorrect <= 3)
        : (total > 0 && correct > incorrect && incorrect == 0);
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tmm Patente',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF81C784), // Light green top bar
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // 1. Top Face & Status Section (Matching Screenshot 1)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Expressive Circular Face Drawing
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: CustomPaint(
                            painter: ResultFacePainter(isPassed: isPassed),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bocciato / Promosso Text
                        Text(
                          isPassed ? 'Promosso' : 'Bocciato',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isPassed ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Tempo: 0 minuti 21 secondi
                        Text(
                          'Tempo: $minutes minuti $seconds secondi',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Summary Metric Badges Row (Corrette, Errori, Non risposte with Eye Icons)
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricPill(
                          label: 'Corrette: $correct',
                          color: const Color(0xFF2E7D32),
                          borderColor: const Color(0xFF4CAF50),
                          mode: 'correct',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricPill(
                          label: 'Errori: $incorrect',
                          color: const Color(0xFFC62828),
                          borderColor: const Color(0xFFEF5350),
                          mode: 'error',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricPill(
                          label: 'Non risposte: $noResponse',
                          color: const Color(0xFFEF6C00),
                          borderColor: const Color(0xFFFFA000),
                          mode: 'no_response',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Tri-Color Segmented Horizontal Bar (Matching Screenshot 1)
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        if (correct > 0)
                          Expanded(
                            flex: correct,
                            child: Container(color: const Color(0xFF4CAF50)),
                          ),
                        if (incorrect > 0)
                          Expanded(
                            flex: incorrect,
                            child: Container(color: const Color(0xFFEF5350)),
                          ),
                        if (noResponse > 0)
                          Expanded(
                            flex: noResponse,
                            child: Container(color: const Color(0xFFFFA000)),
                          ),
                        if (total == 0)
                          Expanded(
                            child: Container(color: Colors.grey.shade300),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Questions Detailed Cards List
                  Column(
                    children: filteredList.map((item) => _buildQuestionResultCard(item, isDark)).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required Color color,
    required Color borderColor,
    required String mode,
    required bool isDark,
  }) {
    final bool isSelected = _filterMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _filterMode = (_filterMode == mode) ? 'all' : mode;
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? borderColor.withOpacity(0.18)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.2 : 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.visibility_rounded,
                size: 14,
                color: isDark ? Colors.white70 : color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionResultCard(ExamResultItem item, bool isDark) {
    Color cardBorderColor;

    if (!item.isAttempted) {
      cardBorderColor = const Color(0xFFFFA000); // Orange
    } else if (item.isCorrect) {
      cardBorderColor = const Color(0xFF4CAF50); // Green
    } else {
      cardBorderColor = const Color(0xFFEF5350); // Red
    }

    final hasImage = item.image != null &&
        item.image!.trim().isNotEmpty &&
        item.image!.toLowerCase() != 'null' &&
        item.image!.toLowerCase() != 'undefined';

    final isThisAudioPlaying = _isPlayingAudio && _activeAudioIndex == item.index;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cardBorderColor,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Number at top left
            Text(
              '${item.index}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),

            // Middle Section: Left Image (if present) + Right Italian Statement
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.network(
                        ApiService.formatImageUrl(item.image),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_rounded, size: 28, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: _buildUnderlinedStatement(item, isDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons Row (Speaker, Bookmark, Notes, Tutor, MCQ List, Translate, Book Info)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. Blue Speaker Button (Italian TTS)
                _buildActionIcon(
                  icon: Icons.volume_up_rounded,
                  color: Colors.white,
                  bgColor: const Color(0xFF3F51B5),
                  onTap: () => _speakItalian(item.index, item.italian),
                ),

                // 2. Green Bookmark Button
                _buildActionIcon(
                  icon: Icons.bookmark_border_rounded,
                  color: const Color(0xFF2E7D32),
                  bgColor: Colors.transparent,
                  onTap: () async {
                    final mcq = McqQuestion(
                      id: item.index,
                      chapter: item.chapter,
                      chapterName: item.chapterName,
                      italian: item.italian,
                      bangla: item.bangla,
                      isVero: item.isVero,
                      image: item.image,
                      audio: item.audio,
                      vocabulary: item.vocabulary,
                    );
                    await BookmarkManager.saveQuestion(mcq);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('প্রশ্নটি সেভ করা হয়েছে')),
                      );
                    }
                  },
                ),

                // 3. Blue Note Button
                _buildActionIcon(
                  icon: Icons.note_alt_outlined,
                  color: const Color(0xFF1976D2),
                  bgColor: Colors.transparent,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => QuestionNoteDialog(
                        questionId: '${item.index}',
                        initialNote: '',
                        onSave: (note) {},
                      ),
                    );
                  },
                ),

                // 4. Tutor Agent with Badge "1"
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TutorChatScreen()));
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
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
                          constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                          child: const Center(
                            child: Text(
                              '1',
                              style: TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. MCQ List Button
                _buildActionIcon(
                  icon: Icons.format_list_bulleted_rounded,
                  color: const Color(0xFF0288D1),
                  bgColor: Colors.transparent,
                  onTap: () {},
                ),

                // 6. Purple Translate Button (অ আ / A)
                _buildActionIcon(
                  icon: Icons.translate_rounded,
                  color: const Color(0xFF7B1FA2),
                  bgColor: Colors.transparent,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => FullTranslateDialog(
                        italianText: item.italian,
                        banglaText: item.bangla,
                        imageUrl: item.image,
                        vocabulary: item.vocabulary,
                      ),
                    );
                  },
                ),

                // 7. Info Book Button
                _buildActionIcon(
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF00838F),
                  bgColor: Colors.transparent,
                  onTap: () {
                    _showTheoryDialog(item);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Audio Player Bar with Slider
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isThisAudioPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      size: 28,
                      color: const Color(0xFF4CAF50),
                    ),
                    onPressed: () => _toggleAudioPlayback(item.index, item.audio),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                        activeTrackColor: const Color(0xFF4CAF50),
                        inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade300,
                        thumbColor: const Color(0xFF4CAF50),
                      ),
                      child: Slider(
                        value: isThisAudioPlaying && _audioDuration.inMilliseconds > 0
                            ? (_audioPosition.inMilliseconds / _audioDuration.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: (val) {
                          if (isThisAudioPlaying && _audioDuration.inMilliseconds > 0) {
                            final seekTo = Duration(milliseconds: (val * _audioDuration.inMilliseconds).toInt());
                            _audioPlayer.seek(seekTo);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Footer: Risposta Corretta & Hai risposto
            Center(
              child: Column(
                children: [
                  Text(
                    'Risposta Corretta: ${item.isVero ? "V" : "F"}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '(TU) Hai risposto: ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text(
                        !item.isAttempted
                            ? 'Non risposto'
                            : (item.userSelectedVero! ? 'V' : 'F'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: !item.isAttempted
                              ? const Color(0xFFFFA000)
                              : (item.isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFEF5350)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  List<InlineSpan> _buildUnderlinedStatement(ExamResultItem item, bool isDark) {
    return HtmlTextHelper.buildParsedStatementSpans(
      statement: item.italian,
      isDark: isDark,
      fontSize: 14.5,
      vocabulary: item.vocabulary,
      onTapWord: (rawWord, cleanWord) {
        String? vocabImage;
        String translation = item.vocabularyHelp[cleanWord] ?? '';

        if (item.vocabulary != null && item.vocabulary!.isNotEmpty) {
          for (var v in item.vocabulary!) {
            if (v is Map) {
              final word = (v['italian'] ?? v['word'] ?? v['italian_word'] ?? '').toString().trim().toLowerCase();
              final rawLower = rawWord.toLowerCase().trim();
              final cleanLower = cleanWord.toLowerCase().trim();
              if (word.isNotEmpty && (word == cleanLower || word == rawLower || rawLower == word || cleanLower == word)) {
                final bn = (v['bangla'] ?? v['meaning'] ?? v['bangla_meaning'] ?? v['translation'] ?? '').toString().trim();
                if (bn.isNotEmpty) translation = bn;
                final img = (v['image'] ?? v['image_path'] ?? v['img'] ?? v['photo'] ?? v['image_url'])?.toString().trim();
                if (img != null && img.isNotEmpty && img.toLowerCase() != 'null' && img.toLowerCase() != 'undefined') {
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

  void _showTheoryDialog(ExamResultItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFF00838F), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.chapterName,
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
                'Capitolo ${item.chapter}',
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                item.italian,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
              ),
              if (item.bangla.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.bangla,
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
}

/// Custom Vector Face Painter matching Screenshot 1 exactly
class ResultFacePainter extends CustomPainter {
  final bool isPassed;

  ResultFacePainter({required this.isPassed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // 1. Head outline
    final headPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, headPaint);

    if (isPassed) {
      // Happy smiling face
      // Left eye
      final eyePaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      // Smiling eyes (arcs)
      canvas.drawArc(
        Rect.fromCircle(center: Offset(center.dx - 16, center.dy - 6), radius: 10),
        3.14,
        3.14,
        false,
        eyePaint,
      );
      // Right eye
      canvas.drawArc(
        Rect.fromCircle(center: Offset(center.dx + 16, center.dy - 6), radius: 10),
        3.14,
        3.14,
        false,
        eyePaint,
      );

      // Smiling mouth
      canvas.drawArc(
        Rect.fromCircle(center: Offset(center.dx, center.dy + 8), radius: 18),
        0.2,
        3.14 - 0.4,
        false,
        eyePaint,
      );
    } else {
      // Bocciato face matching Screenshot 1
      // 1. Big Eyes Circles
      final eyeStroke = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      final eyeFill = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final leftEyeCenter = Offset(center.dx - 16, center.dy - 8);
      final rightEyeCenter = Offset(center.dx + 16, center.dy - 8);
      const eyeRadius = 12.0;

      canvas.drawCircle(leftEyeCenter, eyeRadius, eyeFill);
      canvas.drawCircle(leftEyeCenter, eyeRadius, eyeStroke);
      canvas.drawCircle(rightEyeCenter, eyeRadius, eyeFill);
      canvas.drawCircle(rightEyeCenter, eyeRadius, eyeStroke);

      // 2. Cyan / Blue Pupils looking upward (rolling eyes)
      final pupilStroke = Paint()
        ..color = const Color(0xFF00BCD4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final pupilFill = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final leftPupilCenter = Offset(leftEyeCenter.dx + 1.5, leftEyeCenter.dy - 4.5);
      final rightPupilCenter = Offset(rightEyeCenter.dx + 1.5, rightEyeCenter.dy - 4.5);
      const pupilRadius = 5.0;

      canvas.drawCircle(leftPupilCenter, pupilRadius, pupilFill);
      canvas.drawCircle(leftPupilCenter, pupilRadius, pupilStroke);
      canvas.drawCircle(rightPupilCenter, pupilRadius, pupilFill);
      canvas.drawCircle(rightPupilCenter, pupilRadius, pupilStroke);

      // 3. Eyebrows
      final browPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      // Left eyebrow
      canvas.drawLine(
        Offset(center.dx - 26, center.dy - 24),
        Offset(center.dx - 6, center.dy - 25),
        browPaint,
      );
      // Right eyebrow
      canvas.drawLine(
        Offset(center.dx + 6, center.dy - 25),
        Offset(center.dx + 26, center.dy - 24),
        browPaint,
      );

      // 4. Straight / slightly wavy flat mouth
      final mouthPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(center.dx - 14, center.dy + 16),
        Offset(center.dx + 14, center.dy + 16),
        mouthPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ResultFacePainter oldDelegate) => oldDelegate.isPassed != isPassed;
}
