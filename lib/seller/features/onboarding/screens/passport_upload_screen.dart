import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';

enum _PassportSide { front, back }

class PassportUploadScreen extends StatefulWidget {
  const PassportUploadScreen({super.key, this.onSubmit});

  final VoidCallback? onSubmit;

  @override
  State<PassportUploadScreen> createState() => _PassportUploadScreenState();
}

class _PassportUploadScreenState extends State<PassportUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _frontImage;
  XFile? _backImage;
  bool _isSubmitting = false;

  bool get _canSubmit =>
      _frontImage != null && _backImage != null && !_isSubmitting;

  Future<void> _selectImage(_PassportSide side) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      setState(() {
        switch (side) {
          case _PassportSide.front:
            _frontImage = file;
            break;
          case _PassportSide.back:
            _backImage = file;
            break;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rasmni tanlab bo\'lmadi')),
      );
    }
  }

  void _removeImage(_PassportSide side) {
    setState(() {
      switch (side) {
        case _PassportSide.front:
          _frontImage = null;
          break;
        case _PassportSide.back:
          _backImage = null;
          break;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: PremiumTokens.accent,
          size: 56,
        ),
        title: const Text('Yuborildi'),
        content: const Text(
          'Pasport rasmlari tekshiruvga yuborildi. Natijani kuting.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
              widget.onSubmit?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);

    return Scaffold(
      backgroundColor: pt.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Sotuvchi onboarding'),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hujjatlarni yuklang',
                style: PremiumTokens.display(size: 26, letterSpacing: -0.3),
              ),
              const SizedBox(height: 8),
              Text(
                "Tasdiqlash uchun pasportingizning old va orqa tomon rasmlarini yuklang",
                style: PremiumTokens.body(
                  size: 14,
                  color: pt.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _UploadTile(
                label: 'Old tomonini yuklang',
                file: _frontImage,
                onPick: () => _selectImage(_PassportSide.front),
                onRemove: () => _removeImage(_PassportSide.front),
              ),
              const SizedBox(height: 16),
              _UploadTile(
                label: 'Orqa tomonini yuklang',
                file: _backImage,
                onPick: () => _selectImage(_PassportSide.back),
                onRemove: () => _removeImage(_PassportSide.back),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: pt.divider),
                    foregroundColor: pt.dark,
                  ),
                  child: const Text('Orqaga'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _canSubmit ? _handleSubmit : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Tasdiqlash va yuborish'),
                  style: FilledButton.styleFrom(
                    backgroundColor: PremiumTokens.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: PremiumTokens.accent.withValues(
                      alpha: 0.4,
                    ),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.label,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  final String label;
  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final hasFile = file != null;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: hasFile
              ? pt.surface
              : PremiumTokens.accent.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? PremiumTokens.accent
                : PremiumTokens.accent.withValues(alpha: 0.35),
            width: hasFile ? 1.5 : 1.2,
          ),
          boxShadow: hasFile ? PremiumTokens.softShadow : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _Thumbnail(file: file),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: PremiumTokens.body(
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasFile
                          ? 'Rasm tanlandi. Almashtirish uchun bosing.'
                          : 'JPG yoki PNG · ravshan suratga oling',
                      style: PremiumTokens.body(
                        size: 12,
                        color: pt.grey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasFile)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: pt.grey,
                  visualDensity: VisualDensity.compact,
                  tooltip: "O'chirish",
                )
              else
                Icon(
                  Icons.cloud_upload_outlined,
                  color: PremiumTokens.accent,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.file});

  final XFile? file;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    const double size = 64;

    if (file == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: PremiumTokens.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.add_photo_alternate_outlined,
          color: PremiumTokens.accent,
          size: 26,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(file!.path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: pt.imageBg,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, color: pt.grey),
        ),
      ),
    );
  }
}
