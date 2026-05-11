import 'dart:io';

import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/models/verification_document.dart';
import '../../../../shared/utils/image_upload.dart';

class DocumentUploadTile extends StatelessWidget {
  const DocumentUploadTile({
    super.key,
    required this.type,
    required this.document,
    required this.onPicked,
    required this.onRemove,
    this.locked = false,
  });

  final VerificationDocumentType type;
  final VerificationDocument? document;
  final void Function(File file, String extension) onPicked;
  final VoidCallback onRemove;
  final bool locked;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImageUploadHelper().pick(source: source);
      if (picked == null) return;
      onPicked(picked.file, picked.extension);
    } on ImagePickError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showPickerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr('verification.pick_camera')),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pick(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('verification.pick_gallery')),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pick(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasContent = document?.localPath != null;
    final isUploading = document?.uploading ?? false;
    final isUploaded = document?.isUploaded ?? false;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isUploaded ? scheme.primary : scheme.outlineVariant,
          width: isUploaded ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: locked || isUploading ? null : () => _showPickerSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: hasContent
                      ? Image.file(
                          File(document!.localPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(type.icon, color: scheme.outline),
                          ),
                        )
                      : Container(
                          color: scheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(type.icon, color: scheme.outline),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('verification.doc.${type.code}_title'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('verification.doc.${type.code}_hint'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (document?.error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        document!.error!,
                        style: TextStyle(color: scheme.error, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUploading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isUploaded) ...[
                Icon(Icons.check_circle, color: scheme.primary),
                if (!locked)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: scheme.outline),
                    onPressed: onRemove,
                  ),
              ] else
                const Icon(Icons.upload_outlined),
            ],
          ),
        ),
      ),
    );
  }
}
