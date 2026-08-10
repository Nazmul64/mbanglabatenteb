import 'package:flutter/material.dart';
import 'triangle_pattern_painter.dart';

class Question {
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const Question({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  int? _selectedAnswerIndex;
  bool _answered = false;
  bool _quizFinished = false;

  final List<Question> _questions = const [
    Question(
      text: 'ইসলামের প্রথম খলিফা কে ছিলেন?',
      options: [
        'হযরত উমর (রাঃ)',
        'হযরত আবু বকর (রাঃ)',
        'হযরত আলী (রাঃ)',
        'হযরত উসমান (রাঃ)'
      ],
      correctIndex: 1,
      explanation: 'রাসূলুল্লাহ (সাঃ) এর ওফাতের পর মুসলিম উম্মাহর প্রথম খলিফা হিসেবে হযরত আবু বকর সিদ্দিক (রাঃ) দায়িত্ব গ্রহণ করেন।',
    ),
    Question(
      text: 'পবিত্র কুরআন মজিদে সর্বমোট কতটি সূরা আছে?',
      options: ['১১২টি', '১১০টি', '১১৪টি', '১১৫টি'],
      correctIndex: 2,
      explanation: 'পবিত্র কুরআনে ১১৪টি সূরা, ৩০টি পারা এবং ৬,২৩৬টি আয়াত রয়েছে।',
    ),
    Question(
      text: 'বাংলা সাহিত্যের প্রথম সার্থক মহাকাব্য কোনটি?',
      options: [
        'মেঘনাদবধ কাব্য',
        'পদ্মাবতী',
        'বীরাঙ্গনা কাব্য',
        'তিলোত্তমাসম্ভব কাব্য'
      ],
      correctIndex: 0,
      explanation: 'মাইকেল মধুসূদন দত্ত রচিত "মেঘনাদবধ কাব্য" বাংলা সাহিত্যের প্রথম সার্থক ও সর্বশ্রেষ্ঠ মহাকাব্য।',
    ),
    Question(
      text: 'সূর্য দীঘল বাড়ী উপন্যাসের রচয়িতা কে?',
      options: ['জহির রায়হান', 'শওকত ওসমান', 'আবু ইসহাক', 'সেলিনা হোসেন'],
      correctIndex: 2,
      explanation: 'আবু ইসহাক রচিত "সূর্য দীঘল বাড়ী" একটি বিখ্যাত সমাজসচেতনতামূলক ক্লাসিক্যাল উপন্যাস (প্রকাশিত ১৯৫৫)।',
    ),
    Question(
      text: 'বাংলাদেশের জাতীয় স্মৃতিসৌধের স্থপতি কে?',
      options: [
        'হামিদুর রহমান',
        'সৈয়দ মাইনুল হোসেন',
        'মোস্তফা মনোয়ার',
        'মাজহারুল ইসলাম'
      ],
      correctIndex: 1,
      explanation: 'সাভারে অবস্থিত জাতীয় স্মৃতিসৌধের মূল নকশাকার ও স্থপতি হলেন সৈয়দ মাইনুল হোসেন।',
    ),
  ];

  void _answerQuestion(int index) {
    if (_answered) return;

    setState(() {
      _selectedAnswerIndex = index;
      _answered = true;
      if (index == _questions[_currentQuestionIndex].correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _answered = false;
      } else {
        _quizFinished = true;
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _score = 0;
      _selectedAnswerIndex = null;
      _answered = false;
      _quizFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('সাধারণ জ্ঞান ও ইসলামিক কুইজ'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Triangles pattern background
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
              padding: const EdgeInsets.all(20.0),
              child: _quizFinished
                  ? _buildResultScreen(isDark)
                  : _buildQuizScreen(isDark, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizScreen(bool isDark, ThemeData theme) {
    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress Bar & Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'প্রশ্ন: ${_currentQuestionIndex + 1}/${_questions.length}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'স্কোর: $_score',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: isDark ? Colors.white10 : Colors.blue.shade50,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
        const SizedBox(height: 25),

        // Question Card
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFEEEEEE),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              question.text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 25),

        // Options List
        Expanded(
          child: ListView.separated(
            itemCount: question.options.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final optionText = question.options[index];
              return _buildOptionButton(index, optionText, question, isDark);
            },
          ),
        ),

        // Explanation & Next Button
        if (_answered) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'ব্যাখ্যা:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  question.explanation,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _nextQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentQuestionIndex == _questions.length - 1
                      ? 'কুইজ সম্পন্ন করুন'
                      : 'পরবর্তী প্রশ্ন',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionButton(
      int index, String text, Question question, bool isDark) {
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color borderColor =
        isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFEEEEEE);
    Color textColor = isDark ? Colors.white : Colors.black87;

    if (_answered) {
      if (index == question.correctIndex) {
        cardColor = Colors.green.withOpacity(0.15);
        borderColor = Colors.green;
        textColor = Colors.green.shade600;
      } else if (index == _selectedAnswerIndex) {
        cardColor = Colors.red.withOpacity(0.15);
        borderColor = Colors.red;
        textColor = Colors.red.shade600;
      } else {
        textColor = isDark ? Colors.white30 : Colors.black38;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: () => _answerQuestion(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Row(
            children: [
              // Option index prefix (A, B, C, D)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _answered && index == question.correctIndex
                      ? Colors.green
                      : (_answered && index == _selectedAnswerIndex
                          ? Colors.red
                          : (isDark ? Colors.white10 : Colors.blue.shade50)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _answered &&
                              (index == question.correctIndex ||
                                  index == _selectedAnswerIndex)
                          ? Colors.white
                          : Colors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (_answered && index == question.correctIndex)
                const Icon(Icons.check_circle_rounded, color: Colors.green)
              else if (_answered && index == _selectedAnswerIndex)
                const Icon(Icons.cancel_rounded, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen(bool isDark) {
    double percentage = (_score / _questions.length) * 100;
    String feedback = '';
    IconData feedbackIcon = Icons.emoji_events_rounded;
    Color feedbackColor = Colors.amber;

    if (percentage == 100) {
      feedback = 'অসাধারণ! আপনি সব উত্তর সঠিক দিয়েছেন। 🏆';
      feedbackIcon = Icons.workspace_premium_rounded;
      feedbackColor = Colors.amber;
    } else if (percentage >= 60) {
      feedback = 'দারুণ হয়েছে! আরেকটু চেষ্টা করলেই সব পারবেন। 🎉';
      feedbackIcon = Icons.thumb_up_alt_rounded;
      feedbackColor = Colors.blue;
    } else {
      feedback = 'পরের বার আরও ভালো হবে, আবার চেষ্টা করুন! 💪';
      feedbackIcon = Icons.refresh_rounded;
      feedbackColor = Colors.orange;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                children: [
                  Icon(
                    feedbackIcon,
                    size: 80,
                    color: feedbackColor,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'কুইজ ফলাফল',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_score / ${_questions.length}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: feedbackColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    feedback,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _restartQuiz,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('আবার খেলুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
