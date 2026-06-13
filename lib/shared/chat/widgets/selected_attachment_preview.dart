import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../../customer/features/home/widgets/premium/premium_tokens.dart';

/// Telegram-style attachment chip pinned above the composer once an image is
/// picked: a thumbnail, a one-line label, and an "X" to drop it. The caption
/// is typed in the composer's text field below — so the whole thing sends as a
/// single image+caption message.
class SelectedAttachmentPreview extends StatelessWidget {
  const SelectedAttachmentPreview({
    super.key,
    required this.bytes,
    required this.onRemove,
  });

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pt.divider, width: 0.6),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('chat.image_message'),
                  style: PremiumTokens.body(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: pt.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('chat.caption_hint'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTokens.body(size: 11.5, color: pt.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: tr('chat.remove_attachment'),
            child: Material(
              color: pt.imageBg,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRemove,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(Iconsax.close_circle, size: 18, color: pt.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
