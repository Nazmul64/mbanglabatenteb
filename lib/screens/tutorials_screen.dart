import 'package:flutter/material.dart';
import 'triangle_pattern_painter.dart';
import 'in_app_video_player_screen.dart';
import '../services/api_service.dart';

class LessonItem {
  final int id;
  final String title;
  final String duration;
  final String language;
  final String imageUrl;
  final String videoUrl;

  const LessonItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.language,
    required this.imageUrl,
    required this.videoUrl,
  });
}

class TutorialsScreen extends StatefulWidget {
  const TutorialsScreen({super.key});

  @override
  State<TutorialsScreen> createState() => _TutorialsScreenState();
}

class _TutorialsScreenState extends State<TutorialsScreen> {
  List<LessonItem> _lessons = [];
  bool _isLoading = false;

  String _getYouTubeThumbnail(String url) {
    final regExp = RegExp(r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=|shorts\/)|youtu\.be\/)([^"&?\/\s]{11})');
    final match = regExp.firstMatch(url);
    final id = match?.group(1) ?? '';
    return id.isNotEmpty ? 'https://img.youtube.com/vi/$id/hqdefault.jpg' : '';
  }

  @override
  void initState() {
    super.initState();
    _loadLectureClasses();
  }

  Future<void> _loadLectureClasses() async {
    setState(() {
      _isLoading = true;
    });

    final apiData = await ApiService.fetchClasses();
    final List<LessonItem> loaded = [];
    if (apiData.isNotEmpty) {
      for (int i = 0; i < apiData.length; i++) {
        final item = apiData[i];
        final vUrl = (item['video_url'] ?? item['youtube_url'] ?? item['url'] ?? item['link'] ?? '').toString();
        final ytThumb = _getYouTubeThumbnail(vUrl);
        final title = (item['title'] ?? item['name'] ?? item['lesson_name'] ?? item['titolo'] ?? 'লেকচার ভিডিও ${i + 1}').toString();
        final duration = (item['duration'] ?? item['durata'] ?? item['time'] ?? '').toString();
        final language = (item['language'] ?? item['lingua'] ?? 'ভিডিও ক্লাস').toString();

        loaded.add(LessonItem(
          id: item['id'] is int ? item['id'] : (int.tryParse(item['id']?.toString() ?? '') ?? (i + 1)),
          title: title,
          duration: duration,
          language: language,
          imageUrl: ytThumb.isNotEmpty ? ytThumb : (item['image'] ?? item['thumbnail'] ?? item['image_url'] ?? '').toString(),
          videoUrl: vUrl,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _lessons = loaded;
        _isLoading = false;
      });
    }
  }

  void _openLesson(LessonItem lesson, int index) {
    if (lesson.videoUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ভিডিও লিংক পাওয়া যায়নি'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppVideoPlayerScreen(
          lesson: lesson,
          allLessons: _lessons,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lezioni Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            child: _buildLessonsList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsList(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Heading Row: "ভিডিও লেকচার" & badge count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ভিডিও লেকচার',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  '${_lessons.length}টি ভিডিও',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Video list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : _lessons.isEmpty
                    ? Center(
                        child: Text(
                          'কোনো লেকচার ভিডিও পাওয়া যায়নি',
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 14),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _lessons.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final lesson = _lessons[index];
                          return _buildLessonCard(lesson, index, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(LessonItem lesson, int index, bool isDark) {
    return InkWell(
      onTap: () => _openLesson(lesson, index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
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
            // Thumbnail with Play Icon Overlay
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 100,
                    height: 60,
                    color: isDark ? Colors.white10 : Colors.blue.shade50,
                    child: lesson.imageUrl.isNotEmpty
                        ? Image.network(
                            lesson.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFEF4444), size: 32),
                          )
                        : const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFEF4444), size: 32),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Video Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.play_circle_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lesson.videoUrl.isNotEmpty ? lesson.videoUrl : 'Watch YouTube Video',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
}
