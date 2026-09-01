import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class QRScannerDialog extends StatefulWidget {
  const QRScannerDialog({Key? key}) : super(key: key);

  @override
  State<QRScannerDialog> createState() => _QRScannerDialogState();
}

class _QRScannerDialogState extends State<QRScannerDialog> with SingleTickerProviderStateMixin {
  // Configured high-resolution camera controller for crystal clear HD preview
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
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
    _isProcessing = true;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawVal = barcode.rawValue ?? barcode.displayValue;
      if (rawVal != null && rawVal.trim().isNotEmpty) {
        setState(() {});
        _scannerController.stop();
        await _processScanPayload(rawVal.trim());
        break;
      }
    }
    _isProcessing = false;
  }

  Future<void> _processScanPayload(String rawPayload) async {
    final nav = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final payload = rawPayload.trim();
    if (payload.isEmpty) {
      if (nav.canPop()) nav.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('অকার্যকর QR লিঙ্ক বা তথ্য। অনুগ্রহ করে সঠিক QR কোড স্ক্যান করুন।'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (nav.canPop()) nav.pop();

    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('app_client_phone');
    final sessionId = prefs.getString('app_client_session_id');
    final firstName = prefs.getString('app_client_first_name');
    final lastName = prefs.getString('app_client_last_name');
    final licenseKey = prefs.getString('app_client_license_key') ?? prefs.getString('app_client_token');

    // Secure backend QR verification & website gate unlock
    final res = await ApiService.unlockWebQrGate(
      payload,
      userPhone: userPhone,
      sessionId: sessionId,
      firstName: firstName,
      lastName: lastName,
      licenseKey: licenseKey,
    );

        final bool isSuccess = (res == true);
    final String message = isSuccess
        ? 'ওয়েবসাইট সফলভাবে আনলক করা হয়েছে!'
        : 'লাইসেন্স নিষ্ক্রিয় অথবা স্ক্যান ব্যর্থ হয়েছে। অনুগ্রহ করে সাপোর্ট টিমের সাথে যোগাযোগ করুন।';

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        backgroundColor: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 520, maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Header with Flash Toggle Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'QR কোড স্ক্যানার',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: Colors.amber),
                  onPressed: () {
                    setState(() => _isTorchOn = !_isTorchOn);
                    _scannerController.toggleTorch();
                  },
                  tooltip: 'ফ্ল্যাশ লাইট',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Crystal Clear HD Camera Scanner Preview Box
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // High-Definition Live Camera View (Fit Cover for crisp, 100% sharp preview)
                      MobileScanner(
                        controller: _scannerController,
                        fit: BoxFit.cover,
                        onDetect: _handleBarcodeDetect,
                        errorBuilder: (context, error) {
                          return Container(
                            color: Colors.black87,
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'ক্যামেরা অ্যাক্সেস করতে সমস্যা হচ্ছে। অনুগ্রহ করে ডিভাইস সেটিংসে গিয়ে ক্যামেরা অ্যাক্সেস চালু করুন।',
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
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedBuilder(
                              animation: _laserAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, constraints.maxHeight * _laserAnimation.value),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
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
            ),
            const SizedBox(height: 12),

            // Optional Manual input / Demo Scan
            TextField(
              controller: _sessionInputController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'QR লিঙ্ক পেস্ট করুন (জরুরি না হলে খালি রাখুন)...',
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
