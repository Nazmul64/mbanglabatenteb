import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'image_zoom_dialog.dart';
import '../services/api_service.dart';

class ChatMessageItem {
  final String text;
  final bool isMe; // true = sent by user (green bubble right), false = received from support (grey bubble left)
  final String time;
  final String? attachmentPath;
  final File? localFile;
  final bool isLicenseCard;
  final String? licenseKey;
  final int days;

  const ChatMessageItem({
    required this.text,
    required this.isMe,
    required this.time,
    this.attachmentPath,
    this.localFile,
    this.isLicenseCard = false,
    this.licenseKey,
    this.days = 365,
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
  final ImagePicker _picker = ImagePicker();

  String _sessionId = '';
  String _userPhone = '';
  String _userName = '';
  bool _isInitialLoading = true;
  bool _isVerified = false;
  bool _isActive = false;
  bool _isSubmittingVerification = false;
  bool _isUploadingAttachment = false;
  File? _selectedAttachmentFile;

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
    _userPhone = (prefs.getString('app_client_phone') ?? '').trim();
    String firstName = (prefs.getString('app_client_first_name') ?? '').trim();
    String lastName = (prefs.getString('app_client_last_name') ?? '').trim();
    _sessionId = prefs.getString('app_client_session_id') ?? 'app_${DateTime.now().millisecondsSinceEpoch}';
    _isActive = prefs.getBool('app_client_is_active') ?? false;
    final bool isLocallyVerified = prefs.getBool('app_client_is_verified') ?? false;

    // Clean up any legacy dummy defaults
    if (firstName.toLowerCase() == 'customer' && (lastName.toLowerCase() == 'user' || lastName.isEmpty)) {
      firstName = '';
      lastName = '';
      await prefs.remove('app_client_first_name');
      await prefs.remove('app_client_last_name');
      await prefs.remove('app_client_is_verified');
    }

    if (_sessionId.isNotEmpty) {
      await prefs.setString('app_client_session_id', _sessionId);
    }

    final savedToken = prefs.getString('app_client_token');
    if (savedToken != null && savedToken.isNotEmpty) {
      ApiService.setAuthToken(savedToken);
    }
    ApiService.setSessionContext(sessionId: _sessionId, phone: _userPhone);

    _firstNameController.text = firstName;
    _lastNameController.text = lastName;
    _phoneController.text = _userPhone;

    // Instant UI rendering (0ms delay) using local storage
    final bool hasValidLocalInfo = isLocallyVerified ||
        (_userPhone.isNotEmpty &&
            firstName.isNotEmpty &&
            lastName.isNotEmpty &&
            firstName.toLowerCase() != 'customer');

    if (hasValidLocalInfo) {
      setState(() {
        _userPhone = _userPhone;
        _userName = '$firstName $lastName'.trim();
        _isVerified = true;
        _isInitialLoading = false;
      });
      _startChatPolling();
    } else {
      setState(() {
        _isVerified = false;
        _isInitialLoading = false;
      });
    }

    // Refresh status from server asynchronously in the background without blocking UI
    ApiService.fetchClientStatus(sessionId: _sessionId, phone: _userPhone).then((statusData) async {
      if (!mounted || statusData == null) return;
      final isServerActive = statusData['is_active'] == true;
      final sFirstName = (statusData['first_name'] ?? '').toString().trim();
      final sLastName = (statusData['last_name'] ?? '').toString().trim();
      final sPhone = (statusData['phone'] ?? '').toString().trim();

      final effectivePhone = sPhone.isNotEmpty ? sPhone : _userPhone;
      final effectiveFirstName = sFirstName.isNotEmpty ? sFirstName : firstName;
      final effectiveLastName = sLastName.isNotEmpty ? sLastName : lastName;

      final bool hasFullDetails = effectiveFirstName.isNotEmpty &&
          effectiveLastName.isNotEmpty &&
          effectivePhone.isNotEmpty &&
          effectiveFirstName.toLowerCase() != 'customer';

      if (hasFullDetails) {
        await prefs.setString('app_client_first_name', effectiveFirstName);
        await prefs.setString('app_client_last_name', effectiveLastName);
        await prefs.setString('app_client_phone', effectivePhone);
        await prefs.setBool('app_client_is_active', isServerActive);
        await prefs.setBool('app_client_is_verified', true);

        if (mounted) {
          _firstNameController.text = effectiveFirstName;
          _lastNameController.text = effectiveLastName;
          _phoneController.text = effectivePhone;
          setState(() {
            _userPhone = effectivePhone;
            _userName = '$effectiveFirstName $effectiveLastName'.trim();
            _isActive = isServerActive;
            _isVerified = true;
          });
        }
      } else {
        await prefs.setBool('app_client_is_active', isServerActive);
        if (mounted) {
          setState(() {
            _isActive = isServerActive;
          });
        }
      }
    }).catchError((e) {
      debugPrint('Background client status check error: $e');
    });
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
      final sender = (item['sender'] ?? item['sender_type'] ?? 'user').toString();
      final text = (item['message'] ?? '').toString();
      final attachment = (item['attachment_path'] ?? item['attachment'] ?? item['image'] ?? item['file'] ?? item['file_path'] ?? item['attachment_url'])?.toString();
      final timeStr = item['created_at']?.toString() ?? 'Just now';

      final bool isCard = item['is_license_card'] == true ||
          text.contains('[LICENSE_CARD:') ||
          (item['license_key'] != null && item['license_key'].toString().isNotEmpty);

      String? key = item['license_key']?.toString();
      int days = 365;

      if (text.contains('[LICENSE_CARD:')) {
        final matchKey = RegExp(r'key=([0-9a-zA-Z_-]+)').firstMatch(text);
        final matchDays = RegExp(r'days=(\d+)').firstMatch(text);
        if (matchKey != null) key = matchKey.group(1);
        if (matchDays != null) days = int.tryParse(matchDays.group(1) ?? '365') ?? 365;
      }

      String formattedTime = timeStr;
      if (timeStr.contains('T')) {
        try {
          final parsed = DateTime.parse(timeStr).toLocal();
          formattedTime = '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        } catch (_) {
          formattedTime = timeStr.split('T')[1].substring(0, 5);
        }
      } else if (timeStr.length > 5) {
        formattedTime = timeStr.substring(timeStr.length - 8, timeStr.length - 3);
      }

      loaded.add(ChatMessageItem(
        text: text,
        isMe: sender == 'user' || sender == 'me',
        time: formattedTime,
        attachmentPath: attachment,
        isLicenseCard: isCard,
        licenseKey: key,
        days: days,
      ));
    }

    if (loaded.isNotEmpty || _messages.isEmpty) {
      setState(() {
        _messages = loaded;
      });
    }

    _scrollToBottom();
  }

  Future<void> _submitVerification() async {
    final fName = _firstNameController.text.trim();
    final lName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (fName.isEmpty || lName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অনুগ্রহ করে আপনার নাম ও ফোন নম্বর দিন'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmittingVerification = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_client_first_name', fName);
    await prefs.setString('app_client_last_name', lName);
    await prefs.setString('app_client_phone', phone);
    await prefs.setBool('app_client_is_verified', true);
    if (_sessionId.isEmpty) {
      _sessionId = 'app_${DateTime.now().millisecondsSinceEpoch}';
    }
    await prefs.setString('app_client_session_id', _sessionId);
    ApiService.setSessionContext(sessionId: _sessionId, phone: phone);

    Map<String, dynamic>? res;
    try {
      res = await ApiService.verifyClient(
        firstName: fName,
        lastName: lName,
        phone: phone,
        sessionId: _sessionId,
      );

      if (res != null) {
        final canonicalSessionId = res['client']?['session_id']?.toString() ??
                                   res['session_id']?.toString() ??
                                   res['user']?['uuid']?.toString() ??
                                   _sessionId;
        _sessionId = canonicalSessionId;
        await prefs.setString('app_client_session_id', canonicalSessionId);

        final token = res['token'];
        if (token != null) {
          await prefs.setString('app_client_token', token.toString());
          ApiService.setAuthToken(token.toString());
        }

        final licenseStatus = res['license_status'] ?? (res['client'] != null && res['client']['is_active'] == true ? 'active' : null);
        if (licenseStatus != null) {
          final isActive = licenseStatus == 'active';
          await prefs.setBool('app_client_is_active', isActive);
          if (mounted) setState(() => _isActive = isActive);
        }
      }

      final alreadySentKey = 'joined_msg_sent_$_sessionId';
      if (prefs.getBool(alreadySentKey) != true) {
        await ApiService.sendChatMessage(
          'হ্যালো! আমি অ্যাপ থেকে চ্যাটে যুক্ত হয়েছি',
          _sessionId,
          phone,
          fName,
          lName,
        );
        await prefs.setBool(alreadySentKey, true);
      }
    } catch (e) {
      debugPrint('Registration sync error: $e');
    }

    if (!mounted) return;
    setState(() {
      _isSubmittingVerification = false;
      _userPhone = phone;
      _userName = '$fName $lName'.trim();
      _isVerified = true;
    });

    _startChatPolling();
    _fetchMessages();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('আপনার তথ্য সার্ভারে জমা হয়েছে। লাইভ চ্যাটে স্বাগতম!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final fileToSend = _selectedAttachmentFile;

    if (text.isEmpty && fileToSend == null) return;

    final displayText = text.isNotEmpty
        ? text
        : (fileToSend != null ? 'ছবি পাঠানো হয়েছে' : '');

    final newMsg = ChatMessageItem(
      text: displayText,
      isMe: true,
      time: 'Just now',
      localFile: fileToSend,
    );

    setState(() {
      _messages.add(newMsg);
      _messageController.clear();
      _selectedAttachmentFile = null;
      if (fileToSend != null) {
        _isUploadingAttachment = true;
      }
    });
    _scrollToBottom();

    final fName = _firstNameController.text.trim();
    final lName = _lastNameController.text.trim();
    final success = await ApiService.sendChatMessage(
      displayText,
      _sessionId,
      _userPhone,
      fName,
      lName,
      fileToSend?.path,
    );

    if (mounted && fileToSend != null) {
      setState(() => _isUploadingAttachment = false);
    }

    if (success) {
      _fetchMessages();
    } else if (fileToSend != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ছবি আপলোড করতে সমস্যা হয়েছে। আবার চেষ্টা করুন।'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAttachmentPicker() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Wrap(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF4CAF50)),
                  ),
                  title: const Text('গ্যালারি / স্ক্রিনশট সিলেক্ট করুন', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('আপনার গ্যালারি থেকে স্ক্রিনশট বা ছবি পাঠান', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSetImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF3B82F6)),
                  ),
                  title: const Text('ক্যামেরা দিয়ে ছবি তুলুন', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('ক্যামেরা দিয়ে সরাসরি ছবি তুলে পাঠান', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSetImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndSetImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (pickedFile == null) return;

      setState(() {
        _selectedAttachmentFile = File(pickedFile.path);
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 লাইসেন্স সফলভাবে সক্রিয় করা হয়েছে! ($days দিন)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      _fetchMessages();
    } else {
      if (!mounted) return;
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

    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Live Support Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
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
        actions: [
          IconButton(
            icon: Icon(_isVerified ? Icons.edit_note_rounded : Icons.chat_rounded, color: Colors.white),
            tooltip: _isVerified ? 'তথ্য পরিবর্তন / ভেরিফিকেশন ফরম' : 'চ্যাটে ফিরে যান',
            onPressed: () {
              setState(() {
                _isVerified = !_isVerified;
              });
            },
          ),
        ],
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
                  labelText: 'First Name',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF4CAF50)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Field 2: Last Name
              TextField(
                controller: _lastNameController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF4CAF50)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Field 3: Phone Number
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '017XXXXXXXX / +39...',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 20, color: Color(0xFF4CAF50)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isSubmittingVerification ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _isSubmittingVerification
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('চ্যাটে প্রবেশ করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 2: Live Chat View
  Widget _buildChatBody(bool isDark) {
    return Column(
      children: [
        // Status Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            border: Border(
              bottom: BorderSide(
                color: _isActive ? const Color(0xFFC8E6C9) : const Color(0xFFFFE0B2),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isActive ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                size: 18,
                color: _isActive ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isActive
                      ? '✓ লাইসেন্স একটিভ আছে (সমস্ত ফিচার আনলক)'
                      : 'লাইভ সাপোর্ট প্রতিনিধি আপনার সাথে যুক্ত আছেন।',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isActive ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Message List
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'হ্যালো $_userName! আপনার যেকোনো প্রশ্ন বা সহায়তার জন্য নিচে বার্তা বা স্ক্রিনশট পাঠান।',
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

        // Uploading indicator
        if (_isUploadingAttachment)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.green.shade50,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50))),
                SizedBox(width: 8),
                Text('স্ক্রিনশট পাঠানো হচ্ছে...', style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32))),
              ],
            ),
          ),

        // Attachment Preview Bar if image is selected
        if (_selectedAttachmentFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedAttachmentFile!,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📎 স্ক্রিনশট / ছবি সিলেক্ট করা হয়েছে',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2E7D32)),
                      ),
                      Text(
                        'সেন্ড বাটনে চাপ দিলে সরাসরি চলে যাবে',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 22),
                  tooltip: 'ছবি বাতিল করুন',
                  onPressed: () {
                    setState(() {
                      _selectedAttachmentFile = null;
                    });
                  },
                ),
              ],
            ),
          ),

        // Bottom Chat Input Bar with Attachment Option
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Image / Screenshot Attachment Button
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF4CAF50), size: 26),
                  tooltip: 'স্ক্রিনশট বা ছবি পাঠান',
                  onPressed: _showAttachmentPicker,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _selectedAttachmentFile != null ? 'ক্যাপশন লিখুন...' : 'Type Something...',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 20),
                        tooltip: 'ক্যামেরা দিয়ে ছবি তুলুন',
                        onPressed: () => _pickAndSetImage(ImageSource.camera),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 6),
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
    if (msg.isLicenseCard || (msg.text.contains('[LICENSE_CARD:') && msg.text.contains(']'))) {
      return _buildLicenseCard(msg, isDark);
    }

    final hasImage = (msg.attachmentPath != null && msg.attachmentPath!.isNotEmpty) || msg.localFile != null;

    final String? fullImageUrl = (msg.attachmentPath != null && msg.attachmentPath!.isNotEmpty)
        ? ApiService.formatImageUrl(msg.attachmentPath)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
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
              // Display image if attachment exists
              if (hasImage) ...[
                GestureDetector(
                  onTap: () {
                    if (msg.localFile != null) {
                      ImageZoomDialog.show(context, msg.localFile!.path);
                    } else if (fullImageUrl != null) {
                      ImageZoomDialog.show(context, fullImageUrl);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: msg.localFile != null
                        ? Image.file(
                            msg.localFile!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          )
                        : (fullImageUrl != null
                            ? Image.network(
                                fullImageUrl,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const SizedBox(
                                    height: 120,
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
                                    ),
                                  );
                                },
                              )
                            : const SizedBox()),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              if (msg.text.isNotEmpty && msg.text != 'ছবি পাঠানো হয়েছে')
                Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: msg.isMe
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  msg.time,
                  style: TextStyle(
                    fontSize: 9,
                    color: msg.isMe ? (isDark ? Colors.white60 : Colors.black54) : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Render License Card inside Chat matching Admin & Web UI
  Widget _buildLicenseCard(ChatMessageItem msg, bool isDark) {
    String keyStr = msg.licenseKey ?? '';
    int days = msg.days;

    if (keyStr.isEmpty) {
      final matchKey = RegExp(r'key=([0-9a-zA-Z_-]+)').firstMatch(msg.text);
      if (matchKey != null) keyStr = matchKey.group(1) ?? '';
    }
    if (keyStr.isEmpty) {
      final matchGenericKey = RegExp(r'(\d{5,8})').firstMatch(msg.text);
      if (matchGenericKey != null) keyStr = matchGenericKey.group(1) ?? '';
    }
    if (keyStr.isEmpty) {
      keyStr = '828996';
    }

    final daysStr = days.toString();

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
                  child: const Text('Attiva Licenza (অ্যাক্টিভ করুন)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
