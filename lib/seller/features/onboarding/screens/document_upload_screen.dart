import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../../../../shared/models/business_type.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({
    super.key,
    required this.shopId,
    required this.businessType,
    this.onSubmit,
  });

  final String shopId;
  final BusinessType businessType;
  final VoidCallback? onSubmit;

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, XFile?> _selectedFiles = {};
  bool _isSubmitting = false;

  // Document requirements per business type
  List<DocumentRequirement> _getRequiredDocuments() {
    return switch (widget.businessType) {
      BusinessType.individual => [
        const DocumentRequirement(
          id: 'passport',
          title: 'Pasport yoki ID karta',
          subtitle: 'JSHSHIR bilan',
          emoji: '🪪',
        ),
      ],
      BusinessType.selfEmployed => [
        const DocumentRequirement(
          id: 'passport',
          title: 'Pasport',
          subtitle: 'JSHSHIR bilan',
          emoji: '🪪',
        ),
        const DocumentRequirement(
          id: 'certificate',
          title: "O'z-o'zini band qilgan guvohnomasi",
          subtitle: 'Davlat ro\'yxati',
          emoji: '📜',
        ),
      ],
      BusinessType.llc || BusinessType.corporation => [
        const DocumentRequirement(
          id: 'passport',
          title: 'Direktori pasporti',
          subtitle: 'JSHSHIR bilan',
          emoji: '🪪',
        ),
        const DocumentRequirement(
          id: 'guvohnoma',
          title: 'Tashkilot guvohnomasi',
          subtitle: "O'zMirror yoki Davlat ro'yxati",
          emoji: '📋',
        ),
        const DocumentRequirement(
          id: 'inn',
          title: 'INN (Vergilash shaxsi raqami)',
          subtitle: 'IJM raqami',
          emoji: '🏷️',
        ),
      ],
    };
  }

  Future<void> _pickFile(String documentId) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (file != null && mounted) {
        setState(() {
          _selectedFiles[documentId] = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Faylni tanlash xatosi: $e')));
      }
    }
  }

  Future<void> _pickFileFromGallery(String documentId) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (file != null && mounted) {
        setState(() {
          _selectedFiles[documentId] = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Faylni tanlash xatosi: $e')));
      }
    }
  }

  void _removeFile(String documentId) {
    setState(() {
      _selectedFiles.remove(documentId);
    });
  }

  bool _allFilesSelected() {
    final docs = _getRequiredDocuments();
    return docs.every((doc) => _selectedFiles.containsKey(doc.id));
  }

  Future<void> _handleSubmit() async {
    if (!_allFilesSelected()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, barcha hujjatlarni yuklang')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // TODO: Implement Supabase Storage upload
      // For now, just show success dialog
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          title: const Text('Muvaffaqiyatli yuborildi!'),
          content: const Text(
            'Hujjatlar tekshiruvga yuborildi. Tekshiruv natijalari uchun kuting.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to dashboard
                widget.onSubmit?.call();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Yuborish xatosi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final requiredDocs = _getRequiredDocuments();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hujjatlarni yuklang'),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hujjatlarni yuklang',
                  style: PremiumTokens.display(size: 26, letterSpacing: -0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'KYC tekshiruvi uchun quyidagi hujjatlarni yuklang.',
                  style: PremiumTokens.body(
                    size: 14,
                    color: pt.grey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                for (int i = 0; i < requiredDocs.length; i++) ...[
                  _DocumentUploadCard(
                    requirement: requiredDocs[i],
                    selectedFile: _selectedFiles[requiredDocs[i].id],
                    onPickCamera: () => _pickFile(requiredDocs[i].id),
                    onPickGallery: () =>
                        _pickFileFromGallery(requiredDocs[i].id),
                    onRemove: () => _removeFile(requiredDocs[i].id),
                  ),
                  if (i < requiredDocs.length - 1) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          // Bottom submit button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _isSubmitting || !_allFilesSelected()
                      ? null
                      : _handleSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Hujjatlarni yuborish'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentUploadCard extends StatelessWidget {
  const _DocumentUploadCard({
    required this.requirement,
    required this.selectedFile,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });

  final DocumentRequirement requirement;
  final XFile? selectedFile;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final fileName = selectedFile?.name ?? '';
    final hasFile = selectedFile != null;

    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile ? PremiumTokens.accent : pt.divider,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          // Header with emoji and title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      requirement.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requirement.title,
                            style: PremiumTokens.body(
                              size: 14,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            requirement.subtitle,
                            style: PremiumTokens.body(size: 12, color: pt.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: pt.divider),
          // File picker section
          if (!hasFile)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickCamera,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Surati oling'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickGallery,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Galereyadan'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: PremiumTokens.accent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fayl tanlandi',
                                style: PremiumTokens.body(
                                  size: 12,
                                  color: Colors.green,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                fileName.length > 30
                                    ? '${fileName.substring(0, 27)}...'
                                    : fileName,
                                style: PremiumTokens.body(
                                  size: 12,
                                  color: pt.grey,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onRemove,
                          icon: const Icon(Icons.close, size: 18),
                          color: Colors.red,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickCamera,
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('Yangi surati oling'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class DocumentRequirement {
  const DocumentRequirement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
  });

  final String id;
  final String title;
  final String subtitle;
  final String emoji;
}
