import 'package:flutter/material.dart';
import '../models/live_passed_exam_model.dart';
import '../services/api_service.dart';
import 'pdf_viewer_screen.dart';

class LivePassedExamsScreen extends StatefulWidget {
  const LivePassedExamsScreen({super.key});

  @override
  State<LivePassedExamsScreen> createState() => _LivePassedExamsScreenState();
}

class _LivePassedExamsScreenState extends State<LivePassedExamsScreen> {
  String _activeTab = 'nuove'; // 'nuove' or 'completato'
  List<LivePassedExamItem> _allExams = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);

    try {
      final rawList = await ApiService.fetchLivePassedExams(
        status: _activeTab,
        search: _searchQuery,
      );

      if (mounted) {
        setState(() {
          _allExams = rawList.map((item) {
            if (item is Map<String, dynamic>) {
              return LivePassedExamItem.fromJson(item);
            } else if (item is Map) {
              return LivePassedExamItem.fromJson(Map<String, dynamic>.from(item));
            }
            return LivePassedExamItem(
              id: 0,
              nome: '',
              motorizzazione: '',
              examDate: '',
            );
          }).where((e) => e.id > 0 || e.nome.isNotEmpty).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading live passed exams: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTabChanged(String tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
    });
    _loadExams();
  }

  List<LivePassedExamItem> get _filteredExams {
    if (_searchQuery.trim().isEmpty) return _allExams;
    final q = _searchQuery.toLowerCase().trim();
    return _allExams.where((e) {
      return e.nome.toLowerCase().contains(q) ||
          e.motorizzazione.toLowerCase().contains(q) ||
          e.examDate.toLowerCase().contains(q);
    }).toList();
  }

  void _openPdfViewer(LivePassedExamItem exam) {
    if (exam.pdfUrl == null || exam.pdfUrl!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('এই প্রার্থীর অফিসিয়াল PDF শিট এখনও আপলোড করা হয়নি।'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          title: 'Scheda Esame - ${exam.nome}',
          subtitle: '${exam.motorizzazione} • ${exam.examDate}',
          pdfUrl: exam.pdfUrl!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F8FA),
      body: Column(
        children: [
          // 1. Top Green Header Bar Matching Screenshot 1 & 3
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row with Back Button and Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Scheda Esame',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tabs: Nuove | Completato (Matching Screenshot 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _buildTabButton('Nuove', 'nuove'),
                        const SizedBox(width: 48),
                        _buildTabButton('Completato', 'completato'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Search Bar Matching Screenshot 1
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Search here',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    fontSize: 14.5,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                ),
              ),
            ),
          ),

          // 3. Candidates List Matching Screenshot 1 & 3
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadExams,
                    color: const Color(0xFF22C55E),
                    child: _filteredExams.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.assignment_outlined,
                                      size: 54,
                                      color: isDark ? Colors.white24 : Colors.black26,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'কোনো ফলাফল পাওয়া যায়নি'
                                          : 'এই সেকশনে কোনো এক্সাম শিট নেই',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: _loadExams,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('রিলোড করুন'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF22C55E),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                            itemCount: _filteredExams.length,
                            itemBuilder: (context, index) {
                              final ex = _filteredExams[index];
                              return _buildExamCard(ex, isDark);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String tabKey) {
    final bool isSelected = _activeTab == tabKey;

    return InkWell(
      onTap: () => _onTabChanged(tabKey),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            height: 3.5,
            width: isSelected ? 36 : 0,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(LivePassedExamItem ex, bool isDark) {
    final total = ex.totale > 0 ? ex.totale : 30;
    final double correctRatio = (ex.corrette / total).clamp(0.0, 1.0);
    final double errorRatio = (ex.errori / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF64748B).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPdfViewer(ex),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Round Teal Icon with Clipboard & Pencil (Matching Screenshot 1 & 3)
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.assignment_turned_in_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Transform.rotate(
                          angle: -0.4,
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Color(0xFFFACC15),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Middle Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome: 6731 GOFUR A
                      Text(
                        'Nome: ${ex.nome}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),

                      // Motorizzazione: MODENA
                      Text(
                        'Motorizzazione: ${ex.motorizzazione}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),

                      // Exam date: 19/10/2026
                      Text(
                        'Exam date: ${ex.examDate}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Scores text: Corrette: 29 Errori: 1 Non risposte: 0 Totale: 30
                      Text(
                        'Corrette: ${ex.corrette} Errori: ${ex.errori} Non risposte: ${ex.nonRisposte} Totale: $total',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Horizontal Progress Bar: Green (Corrette) & Red (Errori)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 7,
                          width: double.infinity,
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          child: Row(
                            children: [
                              if (correctRatio > 0)
                                Flexible(
                                  flex: (correctRatio * 100).toInt(),
                                  child: Container(color: const Color(0xFF22C55E)),
                                ),
                              if (errorRatio > 0)
                                Flexible(
                                  flex: (errorRatio * 100).toInt(),
                                  child: Container(color: const Color(0xFFEF4444)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
