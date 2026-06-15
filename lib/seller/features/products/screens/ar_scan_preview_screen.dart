import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../data/ar_scan_repository.dart';

/// Preview the recorded scan, then "Qaytadan olish" (discard → reopen camera)
/// or "Yuklash" (compress → presigned upload → kick off the AI pipeline).
/// Pops `true` once the upload succeeds.
class ArScanPreviewScreen extends StatefulWidget {
  const ArScanPreviewScreen({
    super.key,
    required this.productId,
    required this.videoPath,
  });

  final String productId;
  final String videoPath;

  @override
  State<ArScanPreviewScreen> createState() => _ArScanPreviewScreenState();
}

class _ArScanPreviewScreenState extends State<ArScanPreviewScreen> {
  late final VideoPlayerController _video;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.file(File(widget.videoPath))
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _video.play();
        }
      });
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Compress hard — ProRes / 4K source clips are huge; the AI engine only
      // needs a clean medium-quality pass. Falls back to the raw file if the
      // compressor returns nothing.
      final info = await VideoCompress.compressVideo(
        widget.videoPath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: false,
      );
      final file = info?.file ?? File(widget.videoPath);
      final bytes = await file.readAsBytes();

      await sl<ArScanRepository>().uploadScan(
        productId: widget.productId,
        bytes: bytes,
        contentType: 'video/mp4',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Yuklashda xatolik. Qayta urinib ko‘ring.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _video.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            Center(
              child: AspectRatio(
                aspectRatio: _video.value.aspectRatio,
                child: VideoPlayer(_video),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.terracotta),
            ),

          if (!_submitting)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontFamily: AppFonts.seller,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Qaytadan olish',
                                style: TextStyle(
                                  fontFamily: AppFonts.seller,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.terracotta,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Yuklash',
                                style: TextStyle(
                                  fontFamily: AppFonts.seller,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_submitting) const _GeneratingOverlay(),
        ],
      ),
    );
  }
}

class _GeneratingOverlay extends StatelessWidget {
  const _GeneratingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.terracotta),
          const SizedBox(height: 20),
          const Text(
            '3D model yaratilmoqda. Tasdiqdan so‘ng ilovada ko‘rinadi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
