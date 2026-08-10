import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ChatMessageItem {
  final String text;
  final bool isMe; // true = sent by user (green bubble right), false = received from support (grey bubble left)
  final String time;
  final String? attachmentPath;

  const ChatMessageItem({
    required this.text,
    required this.isMe,
    required this.time,
    this.attachmentPath,
  });
}

class TutorChatScreen extends StatefulWidget {
  const TutorChatScreen({super.key});

  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends State<TutorChatScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _sessionId = '';
  String _userPhone = '';
  String _userName = '';
  bool _isVerified = false;
  bool _isActive = false;
  bool _isLoading = false;
  bool _isSubmittingVerification = false;

  List<ChatMessageItem> _messages = [];
  Timer? _chatPollingTimer;

  @override
  void initState() {
    super.initState();
    _loadClientSession();
  }

  @override
  void dispose() {
    _chatPollingTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadClientSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userPhone = prefs.getString('app_client_phone') ?? '';
    final firstName = prefs.getString('app_client_first_name') ?? '';
    final lastName = prefs.getString('app_client_last_name') ?? '';
    _sessionId = prefs.getString('app_client_session_id') ?? 'app_${DateTime.now().millisecondsSinceEpoch}';
    _isActive = prefs.getBool('app_client_is_active') ?? false;

    if (_sessionId.isNotEmpty) {
      await prefs.setString('app_client_session_id', _sessionId);
    }

    if (_userPhone.isNotEmpty && firstName.isNotEmpty) {
      setState(() {
        _isVerified = true;
        _userName = '$firstName $lastName'.trim();
      });
      _startChatPolling();
    } else {
      setState(() {
        _isVerified = false;
      });
    }
  }

  void _startChatPolling() {
    _fetchMessages();
    _chatPollingTimer?.cancel();
    _chatPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages();
    });
  }

  Future<void> _fetchMessages() async {
    final apiData = await ApiService.fetchChatMessages(_sessionId, _userPhone);
    if (!mounted) return;

    final List<ChatMessageItem> loaded = [];
    for (var item in apiData) {
      final sender = (item['sender'] ?? 'user').toString();
      final text = (item['message'] ?? '').toString();
      final attachment = item['attachment_path']?.toString();
      final timeStr = item['created_at']?.toString() ?? 'Just now';

      loaded.add(ChatMessageItem(
        text: text,
        isMe: sender == 'user' || sender == 'me',
        time: timeStr.length > 5 ? timeStr.substring(timeStr.length - 8, timeStr.length - 3) : timeStr,
        attachmentPath: attachment,
      ));
    }

    setState(() {
      _messages = loaded;
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _submitVerification() async {
    final fName = _firstNameController.text.trim();
    final lName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (fName.isEmpty || lName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সকল ক্ষেত্র (নাম, পদবী ও মোবাইল নাম্বার) পূরণ করুন।'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmittingVerification = true);

    final res = await ApiService.verifyClient(
      firstName: fName,
      lastName: lName,
      phone: phone,
      sessionId: _sessionId,
    );

    if (!mounted) return;
    setState(() => _isSubmittingVerification = false);

    if (res != null && (res['success'] == true || res['status'] == 'success')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_client_first_name', fName);
      await prefs.setString('app_client_last_name', lName);
      await prefs.setString('app_client_phone', phone);
      await prefs.setString('app_client_session_id', _sessionId);

      final client = res['client'];
      if (client != null && client['is_active'] == true) {
        await prefs.setBool('app_client_is_active', true);
        _isActive = true;
      }

      setState(() {
        _userPhone = phone;
        _userName = '$fName $lName';
        _isVerified = true;
      });

      _startChatPolling();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ ভেরিফিকেশন সম্পন্ন হয়েছে! চ্যাট শুরু করতে পারেন।'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ ভেরিফিকেশন সম্পন্ন করা যায়নি। ইন্টারনেট সংযোগ চেক করুন।'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final newMsg = ChatMessageItem(text: text, isMe: true, time: 'Just now');
    setState(() {
      _messages.add(newMsg);
      _messageController.clear();
    });
    _scrollToBottom();

    await ApiService.sendChatMessage(text, _sessionId, _userPhone);
    _fetchMessages();
  }

  Future<void> _activateLicenseFromCard(int days) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⏳ লাইসেন্স সক্রিয় করা হচ্ছে...'), backgroundColor: Colors.blue),
    );

    final success = await ApiService.activateClientLicense(
      sessionId: _sessionId,
      phone: _userPhone,
      days: days,
    );

    if (!mounted) return;

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_client_is_active', true);
      setState(() {
        _isActive = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 লাইসেন্স সফলভাবে সক্রিয় করা হয়েছে! ($days দিন)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      _fetchMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ লাইসেন্স সক্রিয় করতে সমস্যা হয়েছে।'), backgroundColor: Colors.red),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        // FIXED Overflow: Wrapped title in Expanded widget to prevent RenderFlex 23px overflow
        title: Row(
          children: [
            const Icon(Icons.support_agent_rounded, size: 22, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _userName.isNotEmpty ? '$_userName (Online Support)' : 'admin (Online Support)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !_isVerified ? _buildVerificationForm(isDark) : _buildChatBody(isDark),
    );
  }

  /// Step 1: Verification Form matching Screenshot 1
  Widget _buildVerificationForm(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.green.shade400, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, size: 40, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(height: 12),
              const Text(
                'ভেরিফিকেশন ফরম',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(height: 4),
              Text(
                'লাইভ সাপোর্ট পেতে আপনার নাম ও মোবাইল নাম্বার দিন',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Field 1: First Name
              TextField(
                controller: _firstNameController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'নাম (First Name)',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Field 2: Last Name
              TextField(
                controller: _lastNameController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'পদবী (Last Name)',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Field 3: Phone
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'মোবাইল নাম্বার',
                  prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 18, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isSubmittingVerification ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmittingVerification
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('ভেরিফাই করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 2: Active Chat Body matching Screenshot 2
  Widget _buildChatBody(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'আপনার বার্তা লিখে চ্যাট শুরু করুন। রহমান স্যার খুব শীঘ্রই উত্তর দেবেন!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg, isDark);
                  },
                ),
        ),

        // Bottom Chat Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Type Something...',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessageItem msg, bool isDark) {
    // Check if message is a License Card
    if (msg.text.startsWith('[LICENSE_CARD:') && msg.text.contains(']')) {
      return _buildLicenseCard(msg.text, isDark);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: msg.isMe
                ? (isDark ? const Color(0xFF15803D) : const Color(0xFFDCF8C6))
                : (isDark ? const Color(0xFF334155) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
              bottomRight: Radius.circular(msg.isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.text,
                style: TextStyle(
                  fontSize: 13,
                  color: msg.isMe
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Render License Card inside Chat matching Admin & Web UI
  Widget _buildLicenseCard(String cardText, bool isDark) {
    final matchKey = RegExp(r'key=(\d+)').firstMatch(cardText);
    final matchDays = RegExp(r'days=(\d+)').firstMatch(cardText);
    final keyStr = matchKey != null ? matchKey.group(1) : '365';
    final daysStr = matchDays != null ? matchDays.group(1) : '365';
    final days = int.tryParse(daysStr ?? '365') ?? 365;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF4CAF50), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chiave Licenza $keyStr',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2E7D32)),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 16),
              _buildFeatureRow('Traduzione Testi'),
              _buildFeatureRow('Audio'),
              _buildFeatureRow('Lezioni Video'),
              _buildFeatureRow('Live class video registarti'),
              _buildFeatureRow('Web App'),
              _buildFeatureRow('SUPPORTO'),
              _buildFeatureRow('Giorni $daysStr'),
              const SizedBox(height: 14),

              if (_isActive)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4CAF50)),
                  ),
                  child: const Text(
                    'Licenza Attivata ✓',
                    style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => _activateLicenseFromCard(days),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Attiva Licenza (এক্টিভ করুন)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
