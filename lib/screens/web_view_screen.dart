import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String? title;

  const WebViewScreen({
    Key? key,
    required this.url,
    this.title,
  }) : super(key: key);

  /// Helper to sanitize local URLs so Android devices/emulators can access local server
  static String sanitizeUrl(String rawUrl) {
    final baseOrigin = ApiService.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    var cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty) return baseOrigin;

    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://';
    }

    // Resolve localhost/127.0.0.1 for mobile app accessibility
    cleanUrl = cleanUrl
        .replaceAll('http://127.0.0.1:8000', baseOrigin)
        .replaceAll('http://localhost:8000', baseOrigin)
        .replaceAll('https://127.0.0.1:8000', baseOrigin)
        .replaceAll('https://localhost:8000', baseOrigin);

    return cleanUrl;
  }

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasError = false;
  String _errorMessage = '';
  late String _finalUrl;

  @override
  void initState() {
    super.initState();
    _finalUrl = WebViewScreen.sanitizeUrl(widget.url);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _hasError = false;
                _loadingProgress = 10;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.errorCode} - ${error.description}');
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error.description;
                });
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_finalUrl));
  }

  Future<void> _launchInExternalBrowser() async {
    final uri = Uri.parse(_finalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 1,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title ?? 'ইতালি বাংলা পাতেন্তে ওয়েব',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _finalUrl.contains('mbanglapatenteb.com') || _finalUrl.contains('mbanglabatenteb.com')
                  ? 'https://mbanglapatenteb.com/'
                  : _finalUrl,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _hasError = false;
              });
              _controller.reload();
            },
            tooltip: 'রিফ্রেশ',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: _launchInExternalBrowser,
            tooltip: 'ব্রাউজারে খুলুন',
          ),
        ],
        bottom: _loadingProgress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  backgroundColor: Colors.transparent,
                  color: const Color(0xFF2563EB),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_hasError)
            Container(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.orange, size: 54),
                    const SizedBox(height: 16),
                    const Text(
                      'ওয়েবসাইট লোড করতে সমস্যা হয়েছে',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage.isNotEmpty
                          ? _errorMessage
                          : 'ইন্টারনেট কানেকশন বা সার্ভার আইপি টি যাচাই করে পুনরায় চেষ্টা করুন।',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                        });
                        _controller.reload();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('আবার চেষ্টা করুন'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
