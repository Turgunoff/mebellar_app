import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/models/seller_product.dart';
import '../../../../shared/utils/image_upload.dart';
import '../bloc/product_form_bloc.dart';

/// Reorderable thumbnail grid with primary toggle, delete confirm, and
/// per-tile upload progress overlay. Caps at 10 images (`maxImages`) вЂ” the
/// "+" tile vanishes once full.
class ImageGalleryEditor extends StatelessWidget {
  const ImageGalleryEditor({
    super.key,
    required this.images,
    required this.primaryId,
    this.maxImages = 10,
  });

  final List<SellerProductImage> images;
  final String? primaryId;
  final int maxImages;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImageUploadHelper().pick(source: source);
      if (picked == null || !context.mounted) return;
      context.read<ProductFormBloc>().add(ProductFormImagePicked(
            file: picked.file,
            fileExtension: picked.extension,
          ));
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

  Future<void> _confirmDelete(BuildContext context, String imageId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('seller.image_delete_title')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(tr('cart.remove')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context
          .read<ProductFormBloc>()
          .add(ProductFormImageRemoved(imageId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canAdd = images.length < maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('seller.images_title', args: ['${images.length}', '$maxImages']),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          tr('seller.images_hint'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (images.isEmpty)
          Container(
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: scheme.outline, size: 48),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _showPickerSheet(context),
                  icon: const Icon(Icons.add),
                  label: Text(tr('seller.add_image')),
                ),
              ],
            ),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIdx, newIdx) {
              final reordered = List<SellerProductImage>.from(images);
              final adjusted = newIdx > oldIdx ? newIdx - 1 : newIdx;
              final item = reordered.removeAt(oldIdx);
              reordered.insert(adjusted, item);
              context
                  .read<ProductFormBloc>()
                  .add(ProductFormImagesReordered(
                    reordered.map((i) => i.id).toList(),
                  ));
            },
            children: [
              for (var i = 0; i < images.length; i++)
                Padding(
                  key: ValueKey('img-${images[i].id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _GalleryRow(
                    index: i,
                    image: images[i],
                    isPrimary: images[i].id == primaryId,
                    onTogglePrimary: () => context
                        .read<ProductFormBloc>()
                        .add(ProductFormPrimaryImageChanged(images[i].id)),
                    onDelete: () => _confirmDelete(context, images[i].id),
                  ),
                ),
            ],
          ),
        if (canAdd) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showPickerSheet(context),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(tr('seller.add_image')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ],
    );
  }
}

class _GalleryRow extends StatelessWidget {
  const _GalleryRow({
    required this.index,
    required this.image,
    required this.isPrimary,
    required this.onTogglePrimary,
    required this.onDelete,
  });

  final int index;
  final SellerProductImage image;
  final bool isPrimary;
  final VoidCallback onTogglePrimary;
  final VoidCallback onDelete;

  Widget _thumb(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = image.displayUrl;
    if (url == null) {
      return Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: scheme.outline),
      );
    }
    if (image.localPath != null && image.remoteUrl == null) {
      return Image.file(
        File(image.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Container(color: scheme.surfaceContainerHighest),
      );
    }
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image_outlined, color: scheme.outline),
        ),
      );
    }
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          Container(color: scheme.surfaceContainerHighest),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? scheme.primary : scheme.outlineVariant,
          width: isPrimary ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Container(
              width: 32,
              height: 88,
              color: scheme.surfaceContainerHighest,
              child: Icon(Icons.drag_indicator, color: scheme.outline),
            ),
          ),
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumb(context),
                if (image.uploading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: image.uploadProgress,
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (isPrimary)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tr('seller.primary_chip'),
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tr('seller.image_n', args: ['${index + 1}']),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (image.uploading)
                    Text(
                      tr('seller.image_uploading'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (image.error != null)
                    Text(
                      image.error!,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: tr('seller.set_primary'),
            icon: Icon(
              isPrimary ? Icons.star : Icons.star_border,
              color: isPrimary ? scheme.primary : null,
            ),
            onPressed: image.uploading || isPrimary ? null : onTogglePrimary,
          ),
          IconButton(
            tooltip: tr('cart.remove'),
            icon: Icon(Icons.delete_outline, color: scheme.outline),
            onPressed: image.uploading ? null : onDelete,
          ),
        ],
      ),
    );
  }
}
