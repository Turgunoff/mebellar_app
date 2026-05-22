import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/review.dart';
import '../../../../shared/repositories/customer_reviews_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../home/widgets/premium/premium_tokens.dart';

/// Opens the review composer bottom sheet. Resolves to the saved [Review]
/// when the customer submits, or `null` if the sheet is dismissed.
Future<Review?> showReviewComposer(
  BuildContext context, {
  required String orderItemId,
  required String orderId,
  required String productId,
  required String productName,
  required String thumbnail,
  Review? existing,
}) {
  return showModalBottomSheet<Review>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReviewComposerSheet(
      orderItemId: orderItemId,
      orderId: orderId,
      productId: productId,
      productName: productName,
      thumbnail: thumbnail,
      existing: existing,
    ),
  );
}

class ReviewComposerSheet extends StatefulWidget {
  const ReviewComposerSheet({
    super.key,
    required this.orderItemId,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.thumbnail,
    this.existing,
  });

  final String orderItemId;
  final String orderId;
  final String productId;
  final String productName;
  final String thumbnail;

  /// Non-null when editing an already-submitted review.
  final Review? existing;

  @override
  State<ReviewComposerSheet> createState() => _ReviewComposerSheetState();
}

class _ReviewComposerSheetState extends State<ReviewComposerSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final TextEditingController _comment =
      TextEditingController(text: widget.existing?.comment ?? '');
  bool _busy = false;

  static const _labels = {
    0: 'Yulduzlarga bosib baho bering',
    1: 'Juda yomon',
    2: 'Yomon',
    3: "O'rtacha",
    4: 'Yaxshi',
    5: 'Ajoyib!',
  };

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _busy) return;
    setState(() => _busy = true);
    final repo = sl<CustomerReviewsRepository>();
    final existing = widget.existing;
    final result = existing != null
        ? await repo.updateReview(
            reviewId: existing.id,
            rating: _rating,
            comment: _comment.text,
          )
        : await repo.submitReview(
            orderItemId: widget.orderItemId,
            orderId: widget.orderId,
            productId: widget.productId,
            rating: _rating,
            comment: _comment.text,
          );
    if (!mounted) return;
    result.fold(
      ok: (review) => Navigator.of(context).pop(review),
      err: (failure) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: pt.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Product row.
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: widget.thumbnail.isEmpty
                      ? ColoredBox(color: pt.imageBg)
                      : CachedNetworkImage(
                          imageUrl: widget.thumbnail,
                          fit: BoxFit.cover,
                          memCacheWidth: 156,
                          placeholder: (_, _) => ColoredBox(color: pt.imageBg),
                          errorWidget: (_, _, _) =>
                              ColoredBox(color: pt.imageBg),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.productName,
                  style: PremiumTokens.body(
                    size: 14.5,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stars.
          Center(
            child: StarRating(
              rating: _rating.toDouble(),
              size: 42,
              spacing: 8,
              onChanged: (v) => setState(() => _rating = v),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _labels[_rating]!,
              style: PremiumTokens.body(
                size: 13.5,
                weight: FontWeight.w600,
                color: _rating == 0 ? pt.grey : PremiumTokens.accent,
              ),
            ),
          ),
          const SizedBox(height: 22),
          // Comment.
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: PremiumTokens.body(size: 14, height: 1.4),
            decoration: InputDecoration(
              hintText: 'Fikringizni yozing (ixtiyoriy)',
              hintStyle: PremiumTokens.body(size: 14, color: pt.greyLight),
              counterText: '',
              filled: true,
              fillColor: pt.background,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: pt.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: pt.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PremiumTokens.accent),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _rating == 0 || _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: PremiumTokens.accent,
                disabledBackgroundColor: pt.imageBg,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _busy
                  ? const BrandLoadingIndicator(
                      color: Colors.white, radius: 10)
                  : Text(
                      widget.existing != null
                          ? "Sharhni yangilash"
                          : 'Yuborish',
                      style: PremiumTokens.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
