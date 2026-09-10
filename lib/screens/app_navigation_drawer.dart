import 'package:flutter/material.dart';
import 'privacy_terms_screen.dart';
import '../services/api_service.dart';

class AppNavigationDrawer extends StatefulWidget {
  final VoidCallback? onTapHome;
  final VoidCallback? onTapTutorials;
  final VoidCallback? onTapDictionary;
  final VoidCallback? onTapCartelli;
  final VoidCallback? onTapProfile;

  const AppNavigationDrawer({
    Key? key,
    this.onTapHome,
    this.onTapTutorials,
    this.onTapDictionary,
    this.onTapCartelli,
    this.onTapProfile,
  }) : super(key: key);

  @override
  State<AppNavigationDrawer> createState() => _AppNavigationDrawerState();
}

class _AppNavigationDrawerState extends State<AppNavigationDrawer> {
  String _activeServerMode = 'Probing...';
  String _activeBaseUrl = ApiService.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchServerStatus();
  }

  Future<void> _fetchServerStatus() async {
    final settings = await ApiService.fetchSettings();
    if (mounted) {
      setState(() {
        _activeBaseUrl = ApiService.baseUrl;
        _activeServerMode = ApiService.baseUrl.contains('mbanglapatenteb.com') ? 'LIVE PRODUCTION' : 'LOCAL DEVELOPMENT';
      });
    }
  }

  void _openDocument(BuildContext context, DocumentType type) {
    Navigator.pop(context); // Close Drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivacyTermsScreen(type: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.school_rounded, color: Color(0xFF4CAF50), size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'M Bangla Patente B',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'ইতালিয়ান ড্রাইভিং লাইসেন্স প্রস্তুতি',
                              style: TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _activeServerMode.contains('LIVE') ? Icons.public_rounded : Icons.computer_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Mode: $_activeServerMode',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Navigation Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.dashboard_rounded,
                    iconColor: const Color(0xFF4CAF50),
                    title: 'হোম ড্যাশবোর্ড (Home)',
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.onTapHome != null) widget.onTapHome!();
                    },
                  ),
                  const Divider(height: 20),

                  // Privacy Policy item
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.shield_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'প্রাইভেসি পলিসি (Privacy & Policy)',
                    subtitle: 'আমাদের গোপনীয়তা নীতি পড়ুন',
                    onTap: () => _openDocument(context, DocumentType.privacyPolicy),
                  ),

                  // Terms & Conditions item
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.gavel_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'টার্মস এন্ড কন্ডিশন (Terms & Conditions)',
                    subtitle: 'ব্যবহারের নিয়ম ও শর্তাবলী',
                    onTap: () => _openDocument(context, DocumentType.termsConditions),
                  ),

                  const Divider(height: 20),

                  if (widget.onTapTutorials != null)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.play_circle_fill_rounded,
                      iconColor: Colors.red,
                      title: 'ভিডিও টিউটোরিয়াল (Tutorials)',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTapTutorials!();
                      },
                    ),

                  if (widget.onTapDictionary != null)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.menu_book_rounded,
                      iconColor: Colors.indigo,
                      title: 'ইতালিয়ান শব্দকোষ (Dictionary)',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTapDictionary!();
                      },
                    ),

                  if (widget.onTapCartelli != null)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.traffic_rounded,
                      iconColor: Colors.orange,
                      title: 'ট্রাফিক সাইন (Cartelli)',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTapCartelli!();
                      },
                    ),

                  if (widget.onTapProfile != null)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.person_outline_rounded,
                      iconColor: Colors.teal,
                      title: 'প্রোফাইল সেটিংস (Profile)',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTapProfile!();
                      },
                    ),
                ],
              ),
            ),

            // Footer Version Info
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                'M Bangla Patente B • v1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              )
            : null,
        trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
