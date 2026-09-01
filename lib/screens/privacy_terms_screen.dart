import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum DocumentType { privacyPolicy, termsConditions }

class PrivacyTermsScreen extends StatefulWidget {
  final DocumentType type;

  const PrivacyTermsScreen({
    Key? key,
    required this.type,
  }) : super(key: key);

  @override
  State<PrivacyTermsScreen> createState() => _PrivacyTermsScreenState();
}

class _PrivacyTermsScreenState extends State<PrivacyTermsScreen> {
  bool _isLoading = true;
  String _content = '';
  String _lastUpdated = '';

  @override
  void initState() {
    super.initState();
    _loadDocumentContent();
  }

  Future<void> _loadDocumentContent() async {
    setState(() {
      _isLoading = true;
    });

    final settings = await ApiService.fetchSettings();

    if (mounted) {
      setState(() {
        if (settings != null) {
          if (widget.type == DocumentType.privacyPolicy) {
            _content = (settings['privacy_policy'] ?? '').toString();
          } else {
            _content = (settings['terms_conditions'] ?? '').toString();
          }
          if (settings['updated_at'] != null) {
            _lastUpdated = settings['updated_at'].toString().split('T').first;
          }
        }

        // Fallback default content if server returns empty or offline
        if (_content.trim().isEmpty) {
          if (widget.type == DocumentType.privacyPolicy) {
            _content = 'Privacy Policy for M Bangla Patente B\n\n'
                'Your privacy is important to us. We collect minimal information necessary to deliver Italian driving license preparation content, track quiz progress, and manage device activations.\n\n'
                '1. Information Collection: We store account details, study progress, and activation keys.\n'
                '2. Data Security: All communication between the app and server is encrypted.\n'
                '3. Changes: We may update this policy periodically.';
          } else {
            _content = 'Terms & Conditions for M Bangla Patente B\n\n'
                'Welcome to M Bangla Patente B. By using our application, you agree to comply with the following terms:\n\n'
                '1. License: App access is granted per activated device key.\n'
                '2. Usage: Content is for personal study purposes only.\n'
                '3. Content Ownership: Material presented remains proprietary to M Bangla Patente B.';
          }
        }

        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPrivacy = widget.type == DocumentType.privacyPolicy;
    final title = isPrivacy ? 'প্রাইভেসি পলিসি (Privacy Policy)' : 'টার্মস এন্ড কন্ডিশন (Terms & Conditions)';
    final icon = isPrivacy ? Icons.shield_rounded : Icons.gavel_rounded;
    final themeColor = isPrivacy ? const Color(0xFF4CAF50) : const Color(0xFF8B5CF6);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPrivacy ? 'Privacy & Policy' : 'Terms & Conditions',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDocumentContent,
            tooltip: 'রিফ্রেশ করুন',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: themeColor),
                  const SizedBox(height: 16),
                  Text(
                    'তথ্য লোড হচ্ছে...',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDocumentContent,
              color: themeColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Banner Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            themeColor,
                            themeColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _lastUpdated.isNotEmpty ? 'সর্বশেষ আপডেট: $_lastUpdated' : 'M Bangla Patente B Official Document',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Main Content Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SelectableText(
                        _content,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Footer App Branding
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_rounded, size: 16, color: themeColor),
                          const SizedBox(width: 6),
                          Text(
                            'M Bangla Patente B • Official Policy',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
