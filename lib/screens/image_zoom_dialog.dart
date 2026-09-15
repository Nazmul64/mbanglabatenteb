import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ImageZoomDialog extends StatefulWidget {
  final String imageUrl;

  const ImageZoomDialog({
    super.key,
    required this.imageUrl,
  });

  static void show(BuildContext context, String? imageUrl) {
    if (imageUrl == null ||
        imageUrl.trim().isEmpty ||
        imageUrl.trim().toLowerCase() == 'null' ||
        imageUrl.trim().toLowerCase() == 'undefined') {
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => ImageZoomDialog(imageUrl: imageUrl),
    );
  }

  @override
  State<ImageZoomDialog> createState() => _ImageZoomDialogState();
}

class _ImageZoomDialogState extends State<ImageZoomDialog> {
  final TransformationController _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      _transformationController.value = Matrix4.identity()..scale(2.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocalFile = File(widget.imageUrl).existsSync();
    final fullUrl = isLocalFile ? widget.imageUrl : ApiService.formatImageUrl(widget.imageUrl);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onDoubleTap: _handleDoubleTap,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 520),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 440),
                      color: const Color(0xFFF8FAFC),
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.8,
                        maxScale: 5.0,
                        boundaryMargin: const EdgeInsets.all(20),
                        child: isLocalFile
                            ? Image.file(
                                File(widget.imageUrl),
                                fit: BoxFit.contain,
                              )
                            : Image.network(
                                fullUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    height: 220,
                                    child: Center(
                                      child: CircularProgressIndicator(color: Color(0xFF22C55E)),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    alignment: Alignment.center,
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text('ছবি লোড করা যায়নি', style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Close button on top-right
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
