import 'dart:async';
import 'package:flutter/material.dart';
import 'triangle_pattern_painter.dart';
import '../services/html_text_helper.dart';

class ChallengeQuestion {
  final String italian;
  final bool isVero;
  final String bangla;

  const ChallengeQuestion({
    required this.italian,
    required this.isVero,
    required this.bangla,
  });
}

class SfidaScreen extends StatefulWidget {
  const SfidaScreen({super.key});

  @override
  State<SfidaScreen> createState() => _SfidaScreenState();
}

class _SfidaScreenState extends State<SfidaScreen> {
  final List<ChallengeQuestion> _questions = const [
    ChallengeQuestion(
      italian: 'La strada può essere suddivisa in carreggiate',
      isVero: true,
      bangla: 'রাস্তাটি কয়েকটি ক্যারেজওয়েতে বিভক্ত হতে পারে।',
    ),
    ChallengeQuestion(
      italian: 'La corsia può essere a doppio senso di circolazione',
      isVero: false,
      bangla: 'একটি লেন উভয়মুখী যান চলাচলের জন্য হতে পারে।',
    ),
    ChallengeQuestion(
      italian: 'Il marciapiede è destinato alla circolazione dei veicoli',
      isVero: false,
      bangla: 'ফুটপাথ যানবাহন চলাচলের জন্য তৈরি।',
    ),
    ChallengeQuestion(
      italian: 'La pista ciclabile fa parte della carreggiata',
      isVero: false,
      bangla: 'বাইসাইকেল লেন ক্যারেজওয়ের অংশ।',
    ),
    ChallengeQuestion(
      italian: 'La sosta è vietata in corrispondenza dei passaggi a livello',
      isVero: true,
      bangla: 'রেলক্রসিংয়ের উপরে বা আশেপাশে পার্কিং করা আইনত নিষিদ্ধ।',
    ),
  ];

  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  bool _answered = false;
  bool? _isUserCorrect;
  int _timerCount = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startQuestionTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startQuestionTimer() {
    _timerCount = 10;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerCount <= 1) {
        timer.cancel();
        _handleAnswer(null); // Time out counts as wrong
      } else {
        setState(() {
          _timerCount--;
        });
      }
    });
  }

  void _handleAnswer(bool? userChoice) {
    _timer?.cancel();
    if (_answered) return;

    final correctChoice = _questions[_currentIndex].isVero;
    final correct = userChoice == correctChoice;

    setState(() {
      _answered = true;
      _isUserCorrect = correct;
      if (correct) {
        _score += 10 + _streak * 2; // base score + streak multiplier
        _streak++;
      } else {
        _streak = 0;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _isUserCorrect = null;
      });
      _startQuestionTimer();
    } else {
      _showChallengeResults();
    }
  }

  void _showChallengeResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('চ্যালেঞ্জ সম্পন্ন! ⚡', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              Text(
                'আপনার স্কোর: $_score',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 8),
              Text(
                'সঠিক উত্তর: ${_score ~/ 10} / ${_questions.length}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('বন্ধ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentQ = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sfida Challenge'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background triangles pattern
          Positioned.fill(
            child: CustomPaint(
              painter: TrianglePatternPainter(
                triangleColor: isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.blue.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timer progress and Streak header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text('Streak: $_streak', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                          ],
                        ),
                      ),
                      Text('Score: $_score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Timer Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _timerCount / 10.0,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timerCount <= 3 ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Question Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Question ${_currentIndex + 1} / ${_questions.length}',
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: HtmlTextHelper.buildParsedStatementSpans(
                                statement: currentQ.italian,
                                isDark: isDark,
                                fontSize: 18.0,
                                height: 1.4,
                                onTapWord: (rawWord, cleanWord) {},
                              ),
                            ),
                          ),
                          if (_answered) ...[
                            const SizedBox(height: 16),
                            Text(
                              _isUserCorrect == true ? 'সঠিক উত্তর! 🎉' : 'ভুল উত্তর! ❌',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _isUserCorrect == true ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 10),
                            Text(
                              'অনুবাদ: ${currentQ.bangla}',
                              style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Choice buttons
                  if (!_answered)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleAnswer(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('VERO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleAnswer(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('FALSO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _currentIndex < _questions.length - 1 ? 'পরবর্তী প্রশ্ন' : 'ফলাফল দেখুন',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
}
