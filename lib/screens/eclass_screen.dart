import 'package:flutter/material.dart';
import 'triangle_pattern_painter.dart';
import '../services/api_service.dart';
import 'tutor_chat_screen.dart';

class LiveSessionItem {
  final String title;
  final String topic;
  final String time;
  final bool isLive;

  const LiveSessionItem({
    required this.title,
    required this.topic,
    required this.time,
    this.isLive = true,
  });
}

class TutorItem {
  final String initials;
  final String name;
  final String role;
  final bool isOnline;

  const TutorItem({
    required this.initials,
    required this.name,
    required this.role,
    this.isOnline = true,
  });
}

class EClassScreen extends StatefulWidget {
  const EClassScreen({super.key});

  @override
  State<EClassScreen> createState() => _EClassScreenState();
}

class _EClassScreenState extends State<EClassScreen> {
  bool _isLoading = false;
  LiveSessionItem _nextLiveSession = const LiveSessionItem(
    title: 'পরবর্তী লাইভ ক্লাস আজ রাত ৯:০০ টায়',
    topic: 'অধ্যায় ৪: অধিকার নিয়ম (Precedenza)',
    time: 'আজ রাত ৯:০০ টা',
  );

  List<TutorItem> _tutors = const [
    TutorItem(
      initials: 'MR',
      name: 'M Rahman (Senior Instructor)',
      role: 'Senior Instructor',
      isOnline: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLiveClasses();
  }

  Future<void> _loadLiveClasses() async {
    setState(() {
      _isLoading = true;
    });

    final apiData = await ApiService.fetchLiveClasses();
    if (apiData.isNotEmpty) {
      final first = apiData.first;
      if (mounted) {
        setState(() {
          _nextLiveSession = LiveSessionItem(
            title: (first['title'] ?? 'পরবর্তী লাইভ ক্লাস আজ রাত ৯:০০ টায়').toString(),
            topic: (first['topic'] ?? 'অধ্যায় ৪: অধিকার নিয়ম (Precedenza)').toString(),
            time: (first['scheduled_at'] ?? 'আজ রাত ৯:০০ টা').toString(),
          );
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _joinClassroom() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.sensors_rounded, color: Color(0xFFFF3D42)),
              SizedBox(width: 8),
              Text('ই-ক্লাস লাইভ সেশন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            '${_nextLiveSession.title}\n${_nextLiveSession.topic}\n\nভার্চুয়াল ক্লাসরুমে সংযুক্ত হওয়া হচ্ছে...',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('বন্ধ করুন', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('লাইভ ক্লাসরুমে সংযুক্ত হচ্ছে...'),
                    backgroundColor: Color(0xFFFF3D42),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3D42),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('প্রবেশ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
          // Background triangles pattern
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section 1: "ই-ক্লাস লাইভ সেশন" Header Row (Matching Screenshot 2)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ই-ক্লাস লাইভ সেশন',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'সরাসরি শিক্ষকদের ক্লাস',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Section 1 Main Live Class Card (Matching Screenshot 2)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E294B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Red Broadcast Antenna Icon
                              const Icon(Icons.sensors_rounded, color: Color(0xFFFF3B30), size: 36),
                              const SizedBox(height: 12),

                              // Live class heading
                              Text(
                                _nextLiveSession.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),

                              // Topic subtitle
                              Text(
                                _nextLiveSession.topic,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),

                              // Big Red Button: "🚪 ক্লাসরুমে প্রবেশ করুন" (Matching Screenshot 2)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _joinClassroom,
                                  icon: const Icon(Icons.door_sliding_rounded, color: Colors.white, size: 20),
                                  label: const Text(
                                    'ক্লাসরুমে প্রবেশ করুন',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF3D42), // Red button matching screenshot
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Section 2: "উপলব্ধ টিউটরগণ" (Matching Screenshot 2)
                        const Text(
                          'উপলব্ধ টিউটরগণ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),

                        // Tutor Card List
                        ..._tutors.map((tutor) => _buildTutorCard(tutor, isDark)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorCard(TutorItem tutor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E294B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Blue Avatar Circle "MR" matching Screenshot 2
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6), // Blue avatar color matching screenshot
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                tutor.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Tutor Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tutor.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // Green online indicator
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'অনলাইনে আছেন',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chat Button matching Screenshot 2
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TutorChatScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
              foregroundColor: isDark ? Colors.white70 : Colors.black87,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'চ্যাট',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
