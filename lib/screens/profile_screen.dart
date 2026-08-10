import 'package:flutter/material.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final bool soundEnabled;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onClearAllData;
  final VoidCallback onTapSavedQuestions;

  const ProfileScreen({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
    required this.soundEnabled,
    required this.onSoundChanged,
    required this.onClearAllData,
    required this.onTapSavedQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentCyan.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'MB',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'এমবাংলা ইউজার',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'user@mbangla.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Settings Section
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  // Dark Mode Switch
                  SwitchListTile(
                    title: const Text('ডার্ক মোড (Dark Mode)'),
                    subtitle: const Text('ডার্ক ও লাইট থিমের মধ্যে পরিবর্তন করুন'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    value: isDark,
                    onChanged: onThemeChanged,
                  ),
                  const Divider(height: 1),
                  // Sound Toggle
                  SwitchListTile(
                    title: const Text('শব্দ ও কম্পন (Sound & Vibration)'),
                    subtitle: const Text('জিকির ট্যাপ করার সময় ভাইব্রেশন ও সাউন্ড'),
                    secondary: const Icon(Icons.vibration),
                    value: soundEnabled,
                    onChanged: onSoundChanged,
                  ),
                  const Divider(height: 1),
                  // Saved Questions List Page
                  ListTile(
                    leading: const Icon(Icons.bookmark_outline_rounded, color: Colors.blueAccent),
                    title: const Text('সংরক্ষিত প্রশ্নাবলী (Saved Questions)'),
                    subtitle: const Text('আপনার সেভ করে রাখা প্রশ্নগুলো পড়ুন'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: onTapSavedQuestions,
                  ),
                  const Divider(height: 1),
                  // Clear Data Action
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                    title: const Text(
                      'সকল ডাটা মুছুন',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    subtitle: const Text('তাসবিহ হিস্ট্রি রিসেট করুন'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('ডাটা মুছে ফেলার নিশ্চিতকরণ'),
                          content: const Text('আপনি কি নিশ্চিত যে সমস্ত ডাটা ও সেটিংস ডিফল্ট করতে চান?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('বাতিল'),
                            ),
                            TextButton(
                              onPressed: () {
                                onClearAllData();
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('সকল ডাটা সফলভাবে মুছে ফেলা হয়েছে!')),
                                );
                              },
                              child: const Text(
                                'হ্যাঁ, মুছুন',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // App Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'অ্যাপ সম্পর্কে',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('অ্যাপের নাম', 'M Bangla Patente B'),
                  _buildInfoRow('সংস্করণ', '1.0.0 (Stable)'),
                  _buildInfoRow('ডেভেলপার', 'গুগল ডিপমাইন্ড পেয়ার'),
                  _buildInfoRow('তৈরি করা হয়েছে', 'জুন ২০২৬'),
                  const Divider(height: 25),
                  const Center(
                    child: Text(
                      'মেড ইন বাংলাদেশ উইথ 💖 ও ফ্ল্যাটার',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
