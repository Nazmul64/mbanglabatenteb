import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import 'web_view_screen.dart';

class QRScannerDialog extends StatefulWidget {
  const QRScannerDialog({Key? key}) : super(key: key);

  @override
  State<QRScannerDialog> createState() => _QRScannerDialogState();
}

class _QRScannerDialogState extends State<QRScannerDialog> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _sessionInputController = TextEditingController();

  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.88).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    _sessionInputController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawVal = barcode.rawValue ?? barcode.displayValue;
      if (rawVal != null && rawVal.trim().isNotEmpty) {
        setState(() => _isProcessing = true);
        _scannerController.stop();
        await _processScanPayload(rawVal.trim());
        break;
      }
    }
  }

  Future<void> _processScanPayload(String rawPayload) async {
    final parentContext = context;
    final nav = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final payload = rawPayload.trim();
    if (payload.isEmpty) {
      if (nav.canPop()) nav.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('❌ কিউআর কোডের কোনো তথ্য পাওয়া যায়নি।'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Close scanner dialog immediately
    if (nav.canPop()) nav.pop();

    // 1. Unlock backend session
    final unlockSuccess = await ApiService.unlockWebQrGate(payload);

    // 2. Resolve target URL to Home Page of website
    final baseOrigin = ApiService.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    String targetUrl = '$baseOrigin/';

    if (payload.startsWith('http://') || payload.startsWith('https://')) {
      if (!payload.contains('/qr-unlock')) {
        targetUrl = payload;
      }
    }

    targetUrl = WebViewScreen.sanitizeUrl(targetUrl);

    debugPrint('🚀 Opening Home Page WebView for URL: $targetUrl (Unlock success: $unlockSuccess)');

    // 3. Automatically navigate to in-app WebView
    if (parentContext.mounted) {
      Navigator.of(parentContext).push(
        MaterialPageRoute(
          builder: (context) => WebViewScreen(
            url: targetUrl,
            title: 'পাতেন্তে ওয়েবসাইট',
          ),
        ),
      );
    }

    if (!unlockSuccess) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('ℹ️ কিউআর আনলক রেসপন্স পাওয়া যায়নি, কিন্তু ওয়েবসাইট লোড করা হচ্ছে।'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: 460,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'QR কোড স্ক্যানার',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: Colors.amber),
                  onPressed: () {
                    setState(() => _isTorchOn = !_isTorchOn);
                    _scannerController.toggleTorch();
                  },
                  tooltip: 'টর্চ অন/অফ',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Real Camera Scanner Container with Animated Laser Line
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Live Camera View
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _handleBarcodeDetect,
                      errorBuilder: (context, error) {
                        return Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'ক্যামেরা চালু করতে সমস্যা হচ্ছে বা পারমিশন দেওয়া নেই। নিচে ম্যানুয়ালি পেস্ট করতে পারেন।',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Corner Viewfinder Overlays
                    Positioned(
                      top: 15, left: 15,
                      child: Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFF22C55E), width: 4),
                            left: BorderSide(color: Color(0xFF22C55E), width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 15, right: 15,
                      child: Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFF22C55E), width: 4),
                            right: BorderSide(color: Color(0xFF22C55E), width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 15, left: 15,
                      child: Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFF22C55E), width: 4),
                            left: BorderSide(color: Color(0xFF22C55E), width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 15, right: 15,
                      child: Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFF22C55E), width: 4),
                            right: BorderSide(color: Color(0xFF22C55E), width: 4),
                          ),
                        ),
                      ),
                    ),

                    // Animated Green Laser Scanner Line
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedBuilder(
                          animation: _laserAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: constraints.maxHeight * _laserAnimation.value,
                              left: 20,
                              right: 20,
                              child: Container(
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF22C55E).withOpacity(0.9),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    if (_isProcessing)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF22C55E)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Optional Manual input / Demo Scan
            TextField(
              controller: _sessionInputController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'QR লিঙ্ক পেস্ট করুন (জরুরি না হলে শুধু স্ক্যান করুন)...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('বাতিল', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final inputVal = _sessionInputController.text.trim();
                    final payload = inputVal.isNotEmpty ? inputVal : 'web_qr_scan_demo';
                    _scannerController.stop();
                    _processScanPayload(payload);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('ডেমো স্ক্যান করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
