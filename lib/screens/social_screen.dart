import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final TextEditingController _postContentController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();
  final Map<int, TextEditingController> _commentControllers = {};

  List<dynamic> _posts = [];
  bool _isLoading = true;
  bool _isPublishing = false;
  bool _showPhotoInput = false;

  String _userName = 'ব্যবহারকারী';
  String _userPhone = '';
  String _userAvatar = '';

  @override
  void initState() {
    super.initState();
    _loadUserDataAndPosts();
  }

  @override
  void dispose() {
    _postContentController.dispose();
    _photoUrlController.dispose();
    for (var c in _commentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserDataAndPosts() async {
    final prefs = await SharedPreferences.getInstance();
    _userPhone = prefs.getString('user_phone') ?? prefs.getString('device_id') ?? 'dev_${DateTime.now().millisecondsSinceEpoch}';
    _userName = prefs.getString('user_name') ?? 'ব্যবহারকারী';
    _userAvatar = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_userName)}&background=6366F1&color=fff';

    await _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    final posts = await ApiService.fetchSocialPosts(userPhone: _userPhone);
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePublishPost() async {
    final content = _postContentController.text.trim();
    final photoUrl = _photoUrlController.text.trim();

    if (content.isEmpty && photoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অনুগ্রহ করে কিছু লিখুন অথবা একটি ছবির লিঙ্ক যুক্ত করুন।')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isPublishing = true);

    final res = await ApiService.createSocialPost(
      authorName: _userName,
      authorPhone: _userPhone,
      authorAvatar: _userAvatar,
      content: content,
      imageUrl: photoUrl.isNotEmpty ? photoUrl : null,
    );

    if (mounted) {
      setState(() => _isPublishing = false);
      if (res != null && res['status'] == 'success') {
        _postContentController.clear();
        _photoUrlController.clear();
        _showPhotoInput = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('পোস্ট সফলভাবে পাবলিশ হয়েছে!')),
        );
        _fetchPosts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'পোস্ট পাবলিশ করতে সমস্যা হয়েছে।')),
        );
      }
    }
  }

  Future<void> _handleToggleLike(int postId, int index) async {
    final res = await ApiService.likeSocialPost(postId, _userPhone);
    if (res != null && res['status'] == 'success') {
      setState(() {
        _posts[index]['likes_count'] = res['likes_count'] ?? _posts[index]['likes_count'];
        _posts[index]['is_liked'] = res['is_liked'] ?? !_posts[index]['is_liked'];
      });
    }
  }

  Future<void> _handleAddComment(int postId, int index) async {
    final controller = _commentControllers[postId];
    if (controller == null) return;
    final commentText = controller.text.trim();
    if (commentText.isEmpty) return;

    FocusScope.of(context).unfocus();

    final res = await ApiService.addSocialComment(
      postId: postId,
      authorName: _userName,
      authorPhone: _userPhone,
      authorAvatar: _userAvatar,
      comment: commentText,
    );

    if (res != null && res['status'] == 'success') {
      controller.clear();
      _fetchPosts();
    }
  }

  Future<void> _handleDeletePost(int postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('পোস্ট মুছে ফেলুন'),
        content: const Text('আপনি কি নিশ্চিত যে এই পোস্টটি মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteSocialPost(postId, _userPhone);
      if (success) {
        _fetchPosts();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patente Social'),
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchPosts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Community Title Header
                const Text(
                  'mbanglabatenteb (কমিউনিটি ফোরাম)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'অন্যান্য শিক্ষার্থীদের সাথে প্রশ্ন, অভিজ্ঞতা ও আলোচনা শেয়ার করুন',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),

                // Create Post Card Box
                _buildCreatePostCard(isDark),
                const SizedBox(height: 20),

                // Feed Posts List
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _posts.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                            alignment: Alignment.center,
                            child: Text(
                              'এখনো কোনো পোস্ট করা হয়নি। প্রথম পোস্টটি আপনিই করুন!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _posts.length,
                            itemBuilder: (context, index) {
                              return _buildPostCard(_posts[index], index, isDark);
                            },
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePostCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: (_userAvatar.isNotEmpty && (_userAvatar.startsWith('http://') || _userAvatar.startsWith('https://')))
                    ? NetworkImage(_userAvatar)
                    : null,
                child: (_userAvatar.isEmpty || (!_userAvatar.startsWith('http://') && !_userAvatar.startsWith('https://')))
                    ? const Icon(Icons.person, size: 22)
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                _userName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Post Textarea Input
          TextField(
            controller: _postContentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'পাতেন্তে ড্রাইভিং বা থিওরি সম্পর্কিত কিছু লিখুন...',
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),

          // Photo URL Input field (toggleable)
          if (_showPhotoInput) ...[
            TextField(
              controller: _photoUrlController,
              decoration: InputDecoration(
                hintText: 'ছবির লিঙ্ক (Image URL) পেস্ট করুন...',
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Buttons Row: Add Photo & Publish
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showPhotoInput = !_showPhotoInput;
                  });
                },
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18, color: Colors.blue),
                label: const Text(
                  'ফটো যুক্ত করুন',
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isPublishing ? null : _handlePublishPost,
                icon: _isPublishing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  _isPublishing ? 'পাবলিশ হচ্ছে...' : 'পাবলিশ করুন',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index, bool isDark) {
    final postId = post['id'] is int ? post['id'] : int.tryParse(post['id'].toString()) ?? 0;
    final authorName = (post['author_name'] ?? 'Anonymous User').toString();
    final authorPhone = (post['author_phone'] ?? '').toString();
    final avatar = (post['author_avatar'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(authorName)}&background=6366F1&color=fff').toString();
    final content = (post['content'] ?? '').toString();
    final rawImg = (post['image_path'] ?? post['image'] ?? '').toString();
    final imgUrl = ApiService.formatImageUrl(rawImg);
    final likesCount = post['likes_count'] is int ? post['likes_count'] : int.tryParse(post['likes_count'].toString()) ?? 0;
    final isLiked = post['is_liked'] == true;
    final createdAt = (post['created_at_formatted'] ?? 'Just now').toString();

    List<dynamic> comments = post['comments'] ?? [];

    if (!_commentControllers.containsKey(postId)) {
      _commentControllers[postId] = TextEditingController();
    }

    final isMyPost = _userPhone.isNotEmpty && authorPhone == _userPhone;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header Row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: (avatar.isNotEmpty && (avatar.startsWith('http://') || avatar.startsWith('https://')))
                    ? NetworkImage(avatar)
                    : null,
                child: (avatar.isEmpty || (!avatar.startsWith('http://') && !avatar.startsWith('https://')))
                    ? const Icon(Icons.person, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      createdAt,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isMyPost)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  onPressed: () => _handleDeletePost(postId),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Post Text Content
          if (content.isNotEmpty) ...[
            Text(
              content,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Post Attached Image
          if (imgUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imgUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 1),
          const SizedBox(height: 8),

          // Likes & Comments Action Bar
          Row(
            children: [
              InkWell(
                onTap: () => _handleToggleLike(postId, index),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? Colors.redAccent : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$likesCount Likes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isLiked ? Colors.redAccent : (isDark ? Colors.white70 : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey, size: 19),
                    const SizedBox(width: 6),
                    Text(
                      '${comments.length} Comments',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Existing Comments Section
          if (comments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comments.map((c) {
                  final cAuthor = (c['author_name'] ?? 'User').toString();
                  final cText = (c['comment'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: '$cAuthor: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: cText),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Add Comment Input Box
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentControllers[postId],
                  decoration: InputDecoration(
                    hintText: 'কমেন্ট লিখুন...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.blue, size: 20),
                onPressed: () => _handleAddComment(postId, index),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
