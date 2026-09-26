import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/saved_questions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/tutorials_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/dizionario_search_screen.dart';
import 'screens/eclass_screen.dart';
import 'screens/scegli_categoria_screen.dart';
import 'screens/exam_simulation_screen.dart';
import 'screens/cartelli_screen.dart';
import 'screens/sfida_screen.dart';
import 'screens/tutor_chat_screen.dart';
import 'screens/manuale_screen.dart';
import 'screens/social_screen.dart';
import 'screens/translation_screen.dart';
import 'screens/qr_scanner_dialog.dart';
import 'screens/app_navigation_drawer.dart';
import 'services/api_service.dart';
import 'models/bookmark_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.initServerConfig().then((_) {
    BookmarkManager.syncAllWithServer();
    ApiService.syncAllDataToLocalStorage();
  }).catchError((_) {});
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDark = false; // Set default light mode to match screenshot layout, but let users toggle

  void _toggleTheme(bool value) {
    setState(() {
      _isDark = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M Bangla Patente B',
      debugShowCheckedModeBanner: false,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: MainNavigationWrapper(
        isDark: _isDark,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  const MainNavigationWrapper({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  bool _soundEnabled = true;

  void _toggleSound(bool enabled) {
    setState(() {
      _soundEnabled = enabled;
    });
  }

  void _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiService.clearAllCache();
    setState(() {
      _soundEnabled = true;
      widget.onThemeChanged(false); // Default to Light Theme
    });
  }

  // --- Sub-Screen Navigation Helpers with Preloader & License Enforcement ---

  Future<void> _navigateToWithLoader(Widget targetScreen, {String title = 'পেজ লোড হচ্ছে...', bool isProtected = true}) async {
    if (isProtected) {
      final prefs = await SharedPreferences.getInstance();
      final bool? isActiveCached = prefs.getBool('app_client_is_active');
      final phone = prefs.getString('app_client_phone');
      final sessionId = prefs.getString('app_client_session_id');

      final String? expiresAtStr = prefs.getString('app_client_expires_at');
      final bool isExpired = expiresAtStr != null && DateTime.tryParse(expiresAtStr)?.isBefore(DateTime.now()) == true;

      if ((isActiveCached == null || isActiveCached == false) || isExpired) {
        // If not yet verified or expired, verify with server before opening
        final currentStatus = await ApiService.checkLicenseStatus(userPhone: phone, sessionId: sessionId);
        final bool active = (currentStatus == 'active');
        await prefs.setBool('app_client_is_active', active);
        if (!active) {
          if (mounted) _showLicenseRequiredDialog();
          return;
        }
      } else {
        // Active and unexpired: seamless instant zero-second entry
        // Background check never locks out user holding valid unexpired license
        ApiService.checkLicenseStatus(userPhone: phone, sessionId: sessionId).then((currentStatus) {
          if (currentStatus == 'active') {
            prefs.setBool('app_client_is_active', true);
          }
        }).catchError((_) {});
      }
    }

    if (!mounted) return;

    // Instant, seamless navigation
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  void _showLicenseRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('লাইসেন্স আবশ্যক', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'এই ফিচারটি ব্যবহার করতে রেজিস্ট্রেশন ও অ্যাক্টিভ লাইসেন্স আবশ্যক।\n(Please register with First Name, Last Name & Phone Number to activate your license.)',
          style: TextStyle(fontSize: 13.5, height: 1.45, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToTutorChat();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.app_registration_rounded, size: 18),
            label: const Text('রেজিস্ট্রেশন / চ্যাট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToTutorials() {
    _navigateToWithLoader(const TutorialsScreen(), title: 'LEZIONI (ক্লাস) লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToTasbih() {
    _navigateToWithLoader(const ExamSimulationScreen(), title: 'TEST (প্র্যাকটিস টেস্ট) লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToQuotes() {
    _navigateToWithLoader(const ScegliCategoriaScreen(), title: 'ARGOMENTI (টপিকস) লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToManuale() {
    _navigateToWithLoader(const ManualeScreen(), title: 'MANUALE (ম্যানুয়াল থিওরি) লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToSocial() {
    _navigateToWithLoader(const SocialScreen(), title: 'PATENTE SOCIAL (কমিউনিটি) লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToTranslation() {
    _navigateToWithLoader(const TranslationScreen(), title: 'TRANSLATION (অনুবাদ) লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToTextAnalyzer() {
    _navigateToWithLoader(const EClassScreen(), title: 'E-CLASS লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToQuiz() {
    _navigateToWithLoader(const ExamSimulationScreen(), title: 'SCHEDA ESAME লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToDictionary() {
    _navigateToWithLoader(const DizionarioSearchScreen(), title: 'DIZIONARIO (অভিধান) লোড হচ্ছে...', isProtected: false);
  }

  void _navigateToWords() {
    _navigateToWithLoader(const DictionaryScreen(), title: 'WORD (শব্দ তালিকা) লোড হচ্ছে...', isProtected: false);
  }

  void _navigateToNotedQuestions() {
    _navigateToWithLoader(
      const SavedQuestionsScreen(
        title: 'Noted MCQs',
        mode: McqScreenMode.noted,
      ),
      title: 'নোট করা এমসিকিউ (Noted) লোড হচ্ছে...',
      isProtected: true,
    );
  }

  void _navigateToSavedQuestions() {
    _navigateToWithLoader(const SavedQuestionsScreen(), title: 'সেভ করা প্রশ্ন (Saved) লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToProfile() {
    _navigateToWithLoader(
      Scaffold(
        appBar: AppBar(title: const Text('প্রোফাইল ও সেটিংস')),
        body: SafeArea(
          child: ProfileScreen(
            isDark: widget.isDark,
            onThemeChanged: widget.onThemeChanged,
            soundEnabled: _soundEnabled,
            onSoundChanged: _toggleSound,
            onClearAllData: _clearAllData,
            onTapSavedQuestions: _navigateToSavedQuestions,
          ),
        ),
      ),
      title: 'প্রোফাইল সেটিংস লোড হচ্ছে...',
      isProtected: false,
    );
  }

  void _navigateToSfida() {
    _navigateToWithLoader(const SfidaScreen(), title: 'SFIDA (চ্যালেঞ্জ) লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToCartelli() {
    _navigateToWithLoader(const CartelliScreen(), title: 'ট্রাফিক সাইন (Cartelli) লোড হচ্ছে...', isProtected: true);
  }

  void _navigateToTutorChat() {
    _navigateToWithLoader(const TutorChatScreen(), title: 'সোশ্যাল মিডিয়া ও টিউটর লোড হচ্ছে...', isProtected: false);
  }

  // --- Simulated Utility Workflows ---

  void _showQRScannerDemo() {
    showDialog(
      context: context,
      builder: (context) => const QRScannerDialog(),
    );
  }

  void _showHelpBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'কিভাবে ব্যবহার করবেন? (HOW TO?)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildHelpItem(
                      icon: Icons.play_circle_fill_rounded,
                      iconColor: Colors.red,
                      title: '১. ভিডিও টিউটোরিয়াল (Tutorials)',
                      description: 'বিভিন্ন বিষয়ের উপর ভিডিও ক্লাস দেখতে এটি ব্যবহার করুন। সহজে বিষয়গুলো শিখতে সাহায্য করবে।',
                    ),
                    _buildHelpItem(
                      icon: Icons.fingerprint,
                      iconColor: Colors.blue,
                      title: '২. ডিজিটাল তাসবীহ (Tasbih)',
                      description: 'আপনার জিকির গণনা করার জন্য এটি ব্যবহার করুন। আপনি জিকির সিলেক্ট করতে পারবেন এবং টার্গেট পরিবর্তন করতে পারবেন।',
                    ),
                    _buildHelpItem(
                      icon: Icons.auto_stories,
                      iconColor: Colors.purple,
                      title: '৩. বিখ্যাত উক্তি (Quotes)',
                      description: 'মনীষীদের বিখ্যাত উক্তি পড়তে এটি ব্যবহার করুন। রিফ্রেশ বাটনে ট্যাপ করে নতুন নতুন উক্তি পড়তে পারবেন।',
                    ),
                    _buildHelpItem(
                      icon: Icons.analytics_outlined,
                      iconColor: Colors.teal,
                      title: '৪. টেক্সট অ্যানালাইজার (Text Analyzer)',
                      description: 'যেকোনো বাংলা লেখা টাইপ বা পেস্ট করে কতটি শব্দ, বাক্য, বর্ণ এবং বাংলা অক্ষর আছে তা দেখতে বিশ্লেষণ করুন।',
                    ),
                    _buildHelpItem(
                      icon: Icons.quiz_rounded,
                      iconColor: Colors.orange,
                      title: '৫. কুইজ পরীক্ষা (Quiz Test)',
                      description: 'সাধারণ জ্ঞান এবং ইসলামিক প্রশ্নের কুইজে অংশ নিন। ভুল ও সঠিক উত্তরের ব্যাখ্যা জানতে পারবেন।',
                    ),
                    _buildHelpItem(
                      icon: Icons.menu_book_rounded,
                      iconColor: Colors.indigo,
                      title: '৬. ইংরেজি-বাংলা অভিধান (Dictionary)',
                      description: 'ইংরেজি শব্দের সঠিক বাংলা অর্থ, উচ্চারণ, সমার্থক শব্দ ও উদাহরণসহ বাক্য দেখতে সার্চ করুন।',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Custom Floating Bottom Navigation Bar ---

  // --- Bottom Navigation Bar (Docked flush at bottom of screen, 0 gap) ---

  Widget _buildDockedBottomBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Button 1: Stats / Ranking / Performance (Bar chart icon)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _navigateToProfile,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(width: 4, height: 12, decoration: BoxDecoration(color: const Color(0xFFFF7043), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 2.5),
                        Container(width: 4, height: 18, decoration: BoxDecoration(color: const Color(0xFFFFA726), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 2.5),
                        Container(width: 4, height: 14, decoration: BoxDecoration(color: const Color(0xFF42A5F5), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 2.5),
                        Container(width: 4, height: 22, decoration: BoxDecoration(color: const Color(0xFF66BB6A), borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  ),
                ),
              ),

              // Button 2: Theme Toggle (Dark circle with moon/sun)
              InkWell(
                onTap: () => widget.onThemeChanged(!widget.isDark),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E3B5E), Color(0xFF151B26)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.isDark ? Icons.light_mode_rounded : Icons.nights_stay_rounded,
                      color: widget.isDark ? const Color(0xFFFFD700) : const Color(0xFFFFF176),
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Button 3: Dictionary Search
              IconButton(
                icon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  size: 26,
                ),
                onPressed: _navigateToDictionary,
                tooltip: 'ডিকশনারি খুঁজুন',
              ),

              // Button 4: QR Scanner
              IconButton(
                icon: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  size: 24,
                ),
                onPressed: _showQRScannerDemo,
                tooltip: 'QR স্ক্যানার',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCorrectQuestions() {
    _navigateToWithLoader(
      const SavedQuestionsScreen(
        title: 'Correct MCQs',
        mode: McqScreenMode.correct,
      ),
      title: 'সঠিক উত্তরগুলো (Correct) লোড হচ্ছে...',
      isProtected: true,
    );
  }

  void _navigateToWrongQuestions() {
    _navigateToWithLoader(
      const SavedQuestionsScreen(
        title: 'Wrong MCQs',
        mode: McqScreenMode.wrong,
      ),
      title: 'ভুল উত্তরগুলো (Wrong) লোড হচ্ছে...',
      isProtected: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: null, // Hide AppBar on home screen to let sticky header go all the way up
      drawer: AppNavigationDrawer(
        onTapTutorials: _navigateToTutorials,
        onTapDictionary: _navigateToDictionary,
        onTapCartelli: _navigateToCartelli,
        onTapSavedQuestions: _navigateToSavedQuestions,
        onTapNotedQuestions: _navigateToNotedQuestions,
        onTapProfile: _navigateToProfile,
      ),
      body: Stack(
        children: [
          // Main Home View
          Positioned.fill(
            child: DashboardScreen(
              onTapTutorials: _navigateToTutorials,
              onTapTasbih: _navigateToTasbih,
              onTapQuotes: _navigateToQuotes,
              onTapTextAnalyzer: _navigateToTextAnalyzer,
              onTapQuiz: _navigateToQuiz,
              onTapDictionary: _navigateToDictionary,
              onTapWords: _navigateToWords,
              onTapProfile: _navigateToProfile,
              onTapSfida: _navigateToSfida,
              onTapCartelli: _navigateToCartelli,
              onTapSavedQuestions: _navigateToSavedQuestions,
              onTapNotedQuestions: _navigateToNotedQuestions,
              onTapCorrectQuestions: _navigateToCorrectQuestions,
              onTapWrongQuestions: _navigateToWrongQuestions,
              onTapSupport: _navigateToTutorChat,
              onTapManuale: _navigateToManuale,
              onTapSocial: _navigateToSocial,
              onTapTranslation: _navigateToTranslation,
            ),
          ),

          // Docked Bottom Navigation Bar (No gap below, sits flush at the bottom of any device)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildDockedBottomBar(isDark),
          ),
        ],
      ),
    );
  }
}

