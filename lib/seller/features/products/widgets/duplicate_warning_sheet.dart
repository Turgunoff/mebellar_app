import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../data/add_product_repository.dart';

/// Soft duplicate warning shown when `POST/PATCH /seller/products` returns 409
/// DUPLICATE_DETECTED: the seller's catalogue already holds a very similar
/// product. Never a hard block — returns `true` when the seller taps "Baribir
/// qo'shish" (re-submit with force_create), `false`/null on cancel.
///
/// Uzbek-only with seller-local tokens, matching the rest of the add-product
/// form (no tr() / PremiumTokens here — see CLAUDE.md §AI product authoring).
Future<bool> showDuplicateWarningSheet({
  required BuildContext context,
  required DuplicateProductMatch match,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DuplicateWarningSheet(match: match),
  );
  return result ?? false;
}

class _DuplicateWarningSheet extends StatelessWidget {
  const _DuplicateWarningSheet({required this.match});

  final DuplicateProductMatch match;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final percent = (match.similarity * 100).clamp(0, 100).round();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.info_circle,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  "O'xshash mahsulot topildi",
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Siz ushbu mahsulotni avval qo‘shganga o‘xshaysiz. '
            'Baribir qo‘shmoqchimisiz?',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              height: 1.4,
              color: c.grey,
            ),
          ),
          const SizedBox(height: 16),
          _MatchCard(match: match, percent: percent, colors: c),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.ink,
                      side: BorderSide(color: c.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Bekor qilish',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Baribir qo‘shish",
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.percent,
    required this.colors,
  });

  final DuplicateProductMatch match;
  final int percent;
  final SellerColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.fillSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: (match.image != null && match.image!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: match.image!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          ColoredBox(color: colors.imageBg),
                      errorWidget: (context, url, error) => _imageFallback(),
                    )
                  : _imageFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  match.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$percent% o‘xshash",
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() => ColoredBox(
    color: colors.imageBg,
    child: Icon(Iconsax.box, color: colors.grey, size: 22),
  );
}
