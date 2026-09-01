import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
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
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _firstName = '';
  String _lastName = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstName = (prefs.getString('app_client_first_name') ?? prefs.getString('first_name') ?? '').trim();
      _lastName = (prefs.getString('app_client_last_name') ?? prefs.getString('last_name') ?? '').trim();
      _phone = (prefs.getString('app_client_phone') ?? prefs.getString('user_phone') ?? prefs.getString('phone') ?? '').trim();
    });
  }

  void _showEditProfileDialog() {
    final firstController = TextEditingController(text: _firstName);
    final lastController = TextEditingController(text: _lastName);
    final phoneController = TextEditingController(text: _phone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_pin_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('প্রোফাইল তথ্য (User Profile)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ওয়েবসাইট ও অ্যাপের মধ্যে সেভ করা প্রশ্ন এবং রেজাল্ট সিঙ্ক করার জন্য আপনার নাম ও ফোন নাম্বার সেট করুন:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: firstController,
                decoration: InputDecoration(
                  labelText: 'ফার্স্ট নেম (First Name)',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lastController,
                decoration: InputDecoration(
                  labelText: 'লাস্ট নেম (Last Name)',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'ফোন নাম্বার (Phone Number)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final fName = firstController.text.trim();
              final lName = lastController.text.trim();
              final ph = phoneController.text.trim();

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('app_client_first_name', fName);
              await prefs.setString('app_client_last_name', lName);
              await prefs.setString('app_client_phone', ph);
              await prefs.setString('user_phone', ph);

              final sessionId = prefs.getString('app_client_session_id') ?? '';
              if (fName.isNotEmpty && ph.isNotEmpty) {
                ApiService.verifyClient(
                  firstName: fName,
                  lastName: lName,
                  phone: ph,
                  sessionId: sessionId,
                );
              }

              setState(() {
                _firstName = fName;
                _lastName = lName;
                _phone = ph;
              });

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('প্রোফাইল সফলভাবে আপডেট ও সিঙ্ক হয়েছে!')),
                );
              }
            },
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final fullName = (_firstName.isEmpty && _lastName.isEmpty) ? 'এমবাংলা ইউজার' : '$_firstName $_lastName'.trim();
    final displayPhone = _phone.isEmpty ? 'ফোন নাম্বার সেট করা হয়নি' : _phone;
    final initials = (_firstName.isNotEmpty ? _firstName[0] : 'M') + (_lastName.isNotEmpty ? _lastName[0] : 'B');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
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
                  child: Center(
                    child: Text(
                      initials.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayPhone,
                  style: TextStyle(
                    fontSize: 13,
                    color: _phone.isEmpty ? Colors.orange : Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('নাম ও ফোন নাম্বার এডিট করুন', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

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
                    onChanged: widget.onThemeChanged,
                  ),
                  const Divider(height: 1),
                  // Sound Toggle
                  SwitchListTile(
                    title: const Text('শব্দ ও কম্পন (Sound & Vibration)'),
                    subtitle: const Text('জিকির ট্যাপ করার সময় ভাইব্রেশন ও সাউন্ড'),
                    secondary: const Icon(Icons.vibration),
                    value: widget.soundEnabled,
                    onChanged: widget.onSoundChanged,
                  ),
                  const Divider(height: 1),
                  // Saved Questions List Page
                  ListTile(
                    leading: const Icon(Icons.bookmark_outline_rounded, color: Colors.blueAccent),
                    title: const Text('সংরক্ষিত প্রশ্নাবলী (Saved Questions)'),
                    subtitle: const Text('আপনার সেভ করে রাখা প্রশ্নগুলো পড়ুন'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: widget.onTapSavedQuestions,
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
                                widget.onClearAllData();
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
