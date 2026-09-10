import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/slider_model.dart';
import 'triangle_pattern_painter.dart';
import 'card_illustrations.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onTapTutorials;
  final VoidCallback onTapTasbih;
  final VoidCallback onTapQuotes;
  final VoidCallback onTapTextAnalyzer;
  final VoidCallback onTapQuiz;
  final VoidCallback onTapDictionary;
  final VoidCallback? onTapWords;
  final VoidCallback onTapProfile;
  final VoidCallback onTapSfida;
  final VoidCallback onTapCartelli;
  final VoidCallback onTapSavedQuestions;
  final VoidCallback? onTapNotedQuestions;
  final VoidCallback? onTapCorrectQuestions;
  final VoidCallback? onTapWrongQuestions;
  final VoidCallback? onTapSupport;
  final VoidCallback? onTapManuale;
  final VoidCallback onTapSocial;
  final VoidCallback onTapTranslation;

  const DashboardScreen({
    super.key,
    required this.onTapTutorials,
    required this.onTapTasbih,
    required this.onTapQuotes,
    required this.onTapTextAnalyzer,
    required this.onTapQuiz,
    required this.onTapDictionary,
    this.onTapWords,
    required this.onTapProfile,
    required this.onTapSfida,
    required this.onTapCartelli,
    required this.onTapSavedQuestions,
    this.onTapNotedQuestions,
    required this.onTapSocial,
    required this.onTapTranslation,
    this.onTapCorrectQuestions,
    this.onTapWrongQuestions,
    this.onTapSupport,
    this.onTapManuale,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _apiCards = [];
  bool _isLoadingCards = true;

  @override
  void initState() {
    super.initState();
    _fetchCards();
  }

  Future<void> _fetchCards() async {
    final cards = await ApiService.fetchDashboardCards();
    if (mounted) {
      setState(() {
        _apiCards = cards;
        _isLoadingCards = false;
      });
    }
    // Silently pre-warm Argomenti, Cartelli and Exam caches for instantaneous 100% fast response
    ApiService.fetchChapters().catchError((_) => <dynamic>[]);
    ApiService.fetchCartelliChapters().catchError((_) => <dynamic>[]);
    ApiService.generateSchedaEsame().catchError((_) => <dynamic>[]);
  }

  VoidCallback _getCallbackForScreenKey(String screenKey) {
    final key = screenKey.toLowerCase().replaceAll('-', '_');
    if (key.contains('social') || key.contains('community') || key.contains('feed')) return widget.onTapSocial;
    if (key.contains('translation') || key.contains('translate') || key.contains('pronunciation')) return widget.onTapTranslation;
    if (key.contains('tutorial') || key.contains('lezioni')) return widget.onTapTutorials;
    if (key.contains('tasbih') || key.contains('test')) return widget.onTapTasbih;
    if (key.contains('manuale')) return widget.onTapManuale ?? widget.onTapQuotes;
    if (key.contains('quote') || key.contains('argomenti')) return widget.onTapQuotes;
    if (key.contains('text') || key.contains('eclass') || key.contains('e_class')) return widget.onTapTextAnalyzer;
    if (key.contains('sfida')) return widget.onTapSfida;
    if (key.contains('quiz') || key.contains('scheda')) return widget.onTapQuiz;
    
    // Card 7 vs Card 18
    if (key == 'word' || key == 'words' || key == 'word_list' || key == 'vocab') return widget.onTapWords ?? widget.onTapDictionary;
    if (key == 'dictionary' || key == 'dizionario_search' || key == 'dict_search') return widget.onTapDictionary;
    if (key.contains('dizionario') || key.contains('dictionary')) return widget.onTapWords ?? widget.onTapDictionary;

    if (key.contains('cartelli')) return widget.onTapCartelli;
    if (key.contains('noted')) return widget.onTapNotedQuestions ?? widget.onTapSavedQuestions;
    if (key.contains('saved')) return widget.onTapSavedQuestions;
    if (key.contains('correct')) return widget.onTapCorrectQuestions ?? widget.onTapSavedQuestions;
    if (key.contains('wrong')) return widget.onTapWrongQuestions ?? widget.onTapSavedQuestions;
    if (key.contains('support')) return widget.onTapSupport ?? widget.onTapProfile;
    if (key.contains('performer') || key.contains('top') || key.contains('ranking')) return widget.onTapProfile;
    return widget.onTapTutorials;
  }

  Widget _getIllustrationForCard(String screenKey, String iconClass, String? iconUrl, String title) {
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return CardIllustration(
        child: Image.network(
          iconUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.star_rounded, size: 40, color: Colors.blue),
        ),
      );
    }
    final key = (screenKey + ' ' + iconClass + ' ' + title).toLowerCase();
    if (key.contains('tutorial') || key.contains('lezioni')) return const TutorialsIllustration();
    if (key.contains('tasbih') || key.contains('test')) return const TasbihIllustration();
    if (key.contains('quote') || key.contains('argomenti')) return const QuotesIllustration();
    if (key.contains('text') || key.contains('eclass') || key.contains('e-class')) return const TextAnalyzerIllustration();
    if (key.contains('sfida') || key.contains('challenge')) return const SfidaIllustration();
    if (key.contains('quiz') || key.contains('scheda') || key.contains('exam')) return const QuizIllustration();
    if (key.contains('noted')) return const NotedMcqsIllustration();
    if (key.contains('word')) return const WordIllustration();
    if (key.contains('dizionario') || key.contains('dictionary')) return const DictionaryIllustration();
    if (key.contains('cartelli') || key.contains('traffic') || key.contains('sign')) return const CartelliIllustration();
    if (key.contains('saved') || key.contains('bookmark')) return const SavedMcqsIllustration();
    if (key.contains('correct') || key.contains('check')) return const CorrectMcqsIllustration();
    if (key.contains('wrong') || key.contains('xmark') || key.contains('cancel')) return const WrongMcqsIllustration();
    if (key.contains('support') || key.contains('chat') || key.contains('headset')) return const SupportIllustration();
    if (key.contains('performer') || key.contains('top') || key.contains('ranking')) return const TopPerformersIllustration();
    if (key.contains('manuale') || key.contains('theory') || key.contains('book')) return const ManualeIllustration();
    if (key.contains('social') || key.contains('community') || key.contains('feed')) return const PatenteSocialIllustration();
    if (key.contains('translation') || key.contains('translate') || key.contains('language')) return const TranslationIllustration();
    return const CardIllustration(child: Icon(Icons.star_rounded, size: 40, color: Colors.blue));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // 1. Staggered Background Pattern
        Positioned.fill(
          child: CustomPaint(
            painter: TrianglePatternPainter(
              triangleColor: isDark
                  ? Colors.white.withOpacity(0.015)
                  : Colors.blue.withOpacity(0.02),
            ),
          ),
        ),

        // 2. Scrollable Body
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3. Premium Flat Green Header Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFF4CAF50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: true,
                  bottom: false,
                  left: true,
                  right: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Navigation Drawer Hamburger Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Scaffold.of(context).openDrawer();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white24,
                                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.2),
                              ),
                              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                        // Center: App Title
                        const Expanded(
                          child: Text(
                            'M Bangla Patente B',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Right: Profile Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onTapProfile,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white24,
                                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.2),
                              ),
                              child: const Center(
                                child: Icon(Icons.person_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Custom Auto-Sliding Image Banner (Slider)
              const ImageSlider(),

              // 5. Dynamic Grid of Services from API
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                child: _buildDynamicCardsGrid(isDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static final Map<String, String> _banglaSubtitlesLookup = {
    'lezioni': 'ক্লাস ভিডিও',
    'tutorials': 'ক্লাস ভিডিও',
    'test': 'অনুশীলন টেস্ট',
    'tasbih': 'অনুশীলন টেস্ট',
    'argomenti': 'অধ্যায়সমূহ',
    'quotes': 'অধ্যায়সমূহ',
    'eclass': 'অনলাইন ক্লাস',
    'e-class': 'অনলাইন ক্লাস',
    'text_analyzer': 'অনলাইন ক্লাস',
    'sfida': 'চ্যালেঞ্জ',
    'challenge': 'চ্যালেঞ্জ',
    'scheda': 'পরীক্ষার শিট',
    'scheda-esame': 'পরীক্ষার শিট',
    'scheda_esame': 'পরীক্ষার শিট',
    'quiz': 'পরীক্ষার শিট',
    'word': 'শব্দ তালিকা',
    'words': 'শব্দ তালিকা',
    'dizionario': 'অভিধান',
    'dictionary': 'অভিধান',
    'cartelli': 'ট্রাফিক সাইন',
    'saved': 'সেভ করা এমসিকিউ',
    'saved_questions': 'সেভ করা এমসিকিউ',
    'saved-mcqs': 'সেভ করা এমসিকিউ',
    'noted': 'নোট করা এমসিকিউ',
    'noted_questions': 'নোট করা এমসিকিউ',
    'noted-mcqs': 'নোট করা এমসিকিউ',
    'correct': 'সঠিক এমসিকিউ',
    'correct_questions': 'সঠিক এমসিকিউ',
    'correct-mcqs': 'সঠিক এমসিকিউ',
    'wrong': 'ভুল এমসিকিউ',
    'wrong_questions': 'ভুল এমসিকিউ',
    'wrong-mcqs': 'ভুল এমসিকিউ',
    'support': 'লাইভ চ্যাট',
    'top_performers': 'সেরা শিক্ষার্থী র‍্যাংকিং',
    'top-performers': 'সেরা শিক্ষার্থী র‍্যাংকিং',
    'manuale': 'ম্যানুয়াল থিওরি বই',
    'patente_social': 'কমিউনিটি সোশ্যাল ফিড',
    'patente-social': 'কমিউনিটি সোশ্যাল ফিড',
    'translation': 'অনুবাদ ও সঠিক উচ্চারণ',
  };

  String _resolveSubtitle(String rawSubtitle, String screenKey, String title) {
    if (rawSubtitle.trim().isNotEmpty && RegExp(r'[\u0980-\u09FF]').hasMatch(rawSubtitle)) {
      return rawSubtitle;
    }
    final key = screenKey.toLowerCase().replaceAll('-', '_');
    for (final entry in _banglaSubtitlesLookup.entries) {
      if (key.contains(entry.key) || title.toLowerCase().contains(entry.key)) {
        return entry.value;
      }
    }
    return rawSubtitle.isNotEmpty ? rawSubtitle : 'বিস্তারিত';
  }

  Widget _buildDynamicCardsGrid(bool isDark) {
    final List<Map<String, dynamic>> defaultCards = [
      {'title': 'LEZIONI', 'subtitle': 'ক্লাস ভিডিও', 'screen_key': 'lezioni', 'icon_class': 'fa-solid fa-video'},
      {'title': 'TEST', 'subtitle': 'অনুশীলন টেস্ট', 'screen_key': 'test', 'icon_class': 'fa-solid fa-laptop-code'},
      {'title': 'ARGOMENTI', 'subtitle': 'অধ্যায়সমূহ', 'screen_key': 'argomenti', 'icon_class': 'fa-solid fa-graduation-cap'},
      {'title': 'E-CLASS', 'subtitle': 'অনলাইন ক্লাস', 'screen_key': 'eclass', 'icon_class': 'fa-solid fa-chalkboard-user'},
      {'title': 'SFIDA', 'subtitle': 'চ্যালেঞ্জ', 'screen_key': 'sfida', 'icon_class': 'fa-solid fa-trophy'},
      {'title': 'SCHEDA ESAME', 'subtitle': 'পরীক্ষার শিট', 'screen_key': 'scheda-esame', 'icon_class': 'fa-solid fa-file-signature'},
      {'title': 'WORD', 'subtitle': 'শব্দ তালিকা', 'screen_key': 'word', 'icon_class': 'fa-solid fa-book-open'},
      {'title': 'CARTELLI', 'subtitle': 'ট্রাফিক সাইন', 'screen_key': 'cartelli', 'icon_class': 'fa-solid fa-map-signs'},
      {'title': 'SAVED MCQS', 'subtitle': 'সেভ করা এমসিকিউ', 'screen_key': 'saved-mcqs', 'icon_class': 'fa-solid fa-bookmark'},
      {'title': 'NOTED MCQS', 'subtitle': 'নোট করা এমসিকিউ', 'screen_key': 'noted-mcqs', 'icon_class': 'fa-regular fa-note-sticky'},
      {'title': 'CORRECT MCQS', 'subtitle': 'সঠিক এমসিকিউ', 'screen_key': 'correct-mcqs', 'icon_class': 'fa-solid fa-circle-check'},
      {'title': 'WRONG MCQS', 'subtitle': 'ভুল এমসিকিউ', 'screen_key': 'wrong-mcqs', 'icon_class': 'fa-solid fa-circle-xmark'},
      {'title': 'SUPPORT', 'subtitle': 'লাইভ চ্যাট', 'screen_key': 'support', 'icon_class': 'fa-solid fa-headset'},
      {'title': 'TOP PERFORMERS', 'subtitle': 'সেরা শিক্ষার্থী র‍্যাংকিং', 'screen_key': 'top-performers', 'icon_class': 'fa-solid fa-ranking-star'},
      {'title': 'MANUALE', 'subtitle': 'ম্যানুয়াল থিওরি বই', 'screen_key': 'manuale', 'icon_class': 'fa-solid fa-book-bookmark'},
      {'title': 'PATENTE SOCIAL', 'subtitle': 'কমিউনিটি সোশ্যাল ফিড', 'screen_key': 'patente-social', 'icon_class': 'fa-solid fa-users'},
      {'title': 'TRANSLATION', 'subtitle': 'অনুবাদ ও সঠিক উচ্চারণ', 'screen_key': 'translation', 'icon_class': 'fa-solid fa-language'},
      {'title': 'DIZIONARIO', 'subtitle': 'অভিধান', 'screen_key': 'dictionary', 'icon_class': 'fa-solid fa-book-bookmark'},
    ];

    final List<Map<String, dynamic>> cardList = _apiCards.isNotEmpty
        ? _apiCards.cast<Map<String, dynamic>>()
        : defaultCards;

    final List<Widget> rows = [];
    for (int i = 0; i < cardList.length; i += 2) {
      final item1 = cardList[i];
      final item2 = (i + 1 < cardList.length) ? cardList[i + 1] : null;

      final title1 = (item1['title']?.toString() ?? '').toUpperCase();
      final screenKey1 = item1['screen_key']?.toString() ?? '';
      final rawSubtitle1 = item1['subtitle']?.toString() ?? '';
      final subtitle1 = _resolveSubtitle(rawSubtitle1, screenKey1, title1);

      final String? title2 = item2 != null ? (item2['title']?.toString() ?? '').toUpperCase() : null;
      final String screenKey2 = item2 != null ? (item2['screen_key']?.toString() ?? '') : '';
      final String rawSubtitle2 = item2 != null ? (item2['subtitle']?.toString() ?? '') : '';
      final String? subtitle2 = item2 != null ? _resolveSubtitle(rawSubtitle2, screenKey2, title2 ?? '') : null;

      rows.add(
        Row(
          children: [
            Expanded(
              child: _buildNavigationCard(
                illustration: _getIllustrationForCard(
                  screenKey1,
                  item1['icon_class']?.toString() ?? '',
                  item1['icon_url']?.toString(),
                  title1,
                ),
                title: title1,
                subtitle: subtitle1,
                onTap: _getCallbackForScreenKey(screenKey1),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: (item2 != null && title2 != null && subtitle2 != null)
                  ? _buildNavigationCard(
                      illustration: _getIllustrationForCard(
                        screenKey2,
                        item2['icon_class']?.toString() ?? '',
                        item2['icon_url']?.toString(),
                        title2,
                      ),
                      title: title2,
                      subtitle: subtitle2,
                      onTap: _getCallbackForScreenKey(screenKey2),
                      isDark: isDark,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < cardList.length) {
        rows.add(const SizedBox(height: 16));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildNavigationCard({
    required Widget illustration,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF64748B).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: Colors.blue.withOpacity(0.05),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                illustration,
                const SizedBox(height: 14),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Custom Auto-Sliding Image Banner Carousel Widget
// ─────────────────────────────────────────────────────
class ImageSlider extends StatefulWidget {
  const ImageSlider({super.key});

  @override
  State<ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  List<SliderModel> _sliders = [];

  @override
  void initState() {
    super.initState();
    _fetchBanners();
    _startTimer();
  }

  Future<void> _fetchBanners() async {
    try {
      final sliders = await ApiService.fetchSliders();
      if (mounted) {
        setState(() {
          _sliders = sliders;
        });
      }
    } catch (e) {
      debugPrint('Error fetching banners in dashboard: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_sliders.isEmpty) return;
      final nextPage = (_currentPage + 1) % _sliders.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sliders.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 155,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Auto-sliding Banner Images
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _sliders.length,
              itemBuilder: (context, index) {
                final item = _sliders[index];
                final formattedUrl = ApiService.formatImageUrl(item.imageUrl);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: formattedUrl.isNotEmpty
                          ? Image.network(
                              formattedUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.directions_car_rounded, size: 48, color: Color(0xFF4CAF50)),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_outlined, size: 48, color: Colors.grey),
                            ),
                    ),
                    if ((item.title.isNotEmpty && item.title.toLowerCase() != 'banner slider') || (item.subtitle != null && item.subtitle!.isNotEmpty))
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.60),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.title.isNotEmpty && item.title.toLowerCase() != 'banner slider')
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // Overlaid White Pill Dots Indicator at Bottom Center
            Positioned(
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_sliders.length, (index) {
                    final isActive = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isActive ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

