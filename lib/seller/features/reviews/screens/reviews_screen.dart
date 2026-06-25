import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/review.dart';
import '../cubit/reviews_cubit.dart';

// =============================================================================
// Fixed (brightness-independent) local tokens. Adaptive ink/grey/surface/
// divider/fill colours are read from `SellerColors.of(context)` per build so
// the screen flips with the seller theme; the brand accent disc uses
// `c.primarySoft` / `c.onPrimarySoft` (soft tint in light, low-luminance wash in
// dark). Only the star amber stays constant — it reads on both backgrounds.
// =============================================================================
const _amber = Color(0xFFF5A623);

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<ReviewsCubit>()) {
      return Scaffold(
        backgroundColor: SellerColors.of(context).background,
        appBar: const _ReviewsAppBar(),
        body: const _NoBackendState(),
      );
    }
    return BlocProvider<ReviewsCubit>(
      create: (_) => sl<ReviewsCubit>()..load(),
      child: const _ReviewsView(),
    );
  }
}

class _ReviewsView extends StatelessWidget {
  const _ReviewsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellerColors.of(context).background,
      appBar: const _ReviewsAppBar(),
      body: BlocBuilder<ReviewsCubit, ReviewsState>(
        builder: (context, state) {
          return Column(
            children: [
              _FilterTabs(
                current: state.filter,
                pendingCount: state.pendingCount,
                onChanged: (f) => context.read<ReviewsCubit>().setFilter(f),
              ),
              Expanded(child: _Body(state: state)),
            ],
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final ReviewsState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.reviews.isEmpty) {
      return const _ReviewsSkeleton();
    }
    if (state.error != null && state.reviews.isEmpty) {
      return _ErrorState(
        message: state.error!,
        onRetry: () => context.read<ReviewsCubit>().load(),
      );
    }
    final visible = state.visible;
    if (visible.isEmpty) {
      return _EmptyState(
        filter: state.filter,
        hasAnyReview: state.reviews.isNotEmpty,
      );
    }
    return RefreshIndicator(
      color: AppColors.sellerPrimary,
      onRefresh: () => context.read<ReviewsCubit>().load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ReviewCard(
          review: visible[i],
          onReply: () => _openReplySheet(context, visible[i]),
        ),
      ),
    );
  }

  void _openReplySheet(BuildContext context, Review review) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SellerColors.of(context).surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider<ReviewsCubit>.value(
        value: context.read<ReviewsCubit>(),
        child: _ReplySheet(review: review),
      ),
    );
  }
}

// =============================================================================
// App bar — clean white, bold title
// =============================================================================
class _ReviewsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReviewsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return AppBar(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: c.ink,
      leading: IconButton(
        icon: Icon(Iconsax.arrow_left_2_copy, size: 22, color: c.ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        tr('seller.reviews_title'),
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.ink,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// =============================================================================
// Filter tabs — horizontally scrollable choice chips
// =============================================================================
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.current,
    required this.pendingCount,
    required this.onChanged,
  });

  final ReviewFilter current;
  final int pendingCount;
  final ValueChanged<ReviewFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SellerColors.of(context).surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final f in ReviewFilter.values) ...[
              _FilterChip(
                label: f.label,
                selected: current == f,
                badgeCount: f == ReviewFilter.pending ? pendingCount : null,
                onTap: () => onChanged(f),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final bg = selected ? c.ink : c.neutralBgAlt;
    final fg = selected ? c.surface : c.ink;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1.0,
                  letterSpacing: -0.1,
                ),
              ),
              if (badgeCount != null && badgeCount! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.sellerPrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Review card — thumbnail + product, divider, content, reply slot
// =============================================================================
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onReply});

  final Review review;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.26 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(review: review),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: c.divider),
          const SizedBox(height: 12),
          _CustomerLine(review: review),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: c.neutralFgAlt,
                height: 1.5,
                letterSpacing: -0.1,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (review.hasReply)
            _SellerReplyBlock(reply: review.sellerReply!)
          else
            _ReplyButton(onTap: onReply),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: review.productImage.isEmpty
              ? _productImageFallback(c)
              : CachedNetworkImage(
                  imageUrl: review.productImage,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  memCacheWidth: 120,
                  errorWidget: (_, _, _) => _productImageFallback(c),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            review.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.ink,
              height: 1.25,
              letterSpacing: -0.1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _formatTimeAgo(review.createdAt),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: c.grey,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _productImageFallback(SellerColors c) {
    return Container(
      width: 40,
      height: 40,
      color: c.imageBg,
      alignment: Alignment.center,
      child: Icon(Iconsax.box, size: 18, color: c.greyMid),
    );
  }
}

class _CustomerLine extends StatelessWidget {
  const _CustomerLine({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            review.customerName,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SellerColors.of(context).ink,
              height: 1.2,
              letterSpacing: -0.1,
            ),
          ),
        ),
        _StarRow(rating: review.rating),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final emptyColor = SellerColors.of(context).greyMid;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          Icon(
            Iconsax.star_1,
            size: 14,
            color: i <= rating ? _amber : emptyColor,
          ),
          if (i < 5) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

// =============================================================================
// Reply button — indigo outlined
// =============================================================================
class _ReplyButton extends StatelessWidget {
  const _ReplyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(Iconsax.edit, size: 16, color: c.onPrimarySoft),
        label: Text(
          tr('seller.reviews_write_reply'),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: c.onPrimarySoft,
            letterSpacing: -0.1,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: c.onPrimarySoft, width: 1.2),
          backgroundColor: c.primarySoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Seller reply block — soft grey, nested feel
// =============================================================================
class _SellerReplyBlock extends StatelessWidget {
  const _SellerReplyBlock({required this.reply});

  final String reply;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.fillSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Iconsax.shop,
              size: 16,
              color: c.onPrimarySoft,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('seller.reviews_your_reply'),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sellerPrimary,
                    height: 1.2,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reply,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Reply bottom sheet — wired to ReviewsCubit.postReply
// =============================================================================
class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.review});

  final Review review;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cubit = context.read<ReviewsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final text = _controller.text.trim();
    if (text.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('seller.reviews_reply_empty'))),
      );
      return;
    }
    final ok = await cubit.postReply(reviewId: widget.review.id, reply: text);
    if (!mounted) return;
    if (ok) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(tr('seller.reviews_reply_sent'))),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(cubit.state.error ?? tr('seller.reviews_reply_failed')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return BlocBuilder<ReviewsCubit, ReviewsState>(
      builder: (context, state) {
        final sending = state.replyingId == widget.review.id;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + viewInsets),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.dividerStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('seller.reviews_write_reply'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.review.customerName} • ${widget.review.productName}',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.grey,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 5,
                enabled: !sending,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.ink,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  hintText: tr('seller.reviews_reply_hint'),
                  hintStyle: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.greyMid,
                  ),
                  filled: true,
                  fillColor: c.fillFaint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: sending ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sellerPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          tr('seller.reviews_send'),
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Empty / loading / error states
// =============================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.hasAnyReview});

  final ReviewFilter filter;
  final bool hasAnyReview;

  @override
  Widget build(BuildContext context) {
    final title = hasAnyReview
        ? tr('seller.reviews_empty_filtered_title')
        : tr('seller.reviews_empty_none_title');
    final subtitle = hasAnyReview
        ? tr('seller.reviews_empty_filtered_subtitle')
        : tr('seller.reviews_empty_none_subtitle');
    final c = SellerColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.neutralBgAlt,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Iconsax.messages_2, size: 32, color: c.greyMid),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Iconsax.warning_2,
              size: 40,
              color: AppColors.sellerPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SellerColors.of(context).ink,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sellerPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                tr('seller.reviews_retry'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBackendState extends StatelessWidget {
  const _NoBackendState();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.info_circle, size: 40, color: c.greyMid),
            const SizedBox(height: 16),
            Text(
              tr('seller.reviews_unavailable_title'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('seller.reviews_unavailable_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E6),
      highlightColor: dark ? const Color(0xFF383838) : const Color(0xFFF5F5F5),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          height: 140,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Helpers
// =============================================================================

/// Renders the relative time the review was posted, e.g. "2 soat oldin".
String _formatTimeAgo(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return tr('seller.reviews_time_now');
  if (diff.inMinutes < 60) {
    return tr('seller.reviews_time_minutes_ago', args: [diff.inMinutes]);
  }
  if (diff.inHours < 24) {
    return tr('seller.reviews_time_hours_ago', args: [diff.inHours]);
  }
  if (diff.inDays < 7) {
    return tr('seller.reviews_time_days_ago', args: [diff.inDays]);
  }
  if (diff.inDays < 30) {
    return tr('seller.reviews_time_weeks_ago', args: [(diff.inDays / 7).floor()]);
  }
  if (diff.inDays < 365) {
    return tr(
      'seller.reviews_time_months_ago',
      args: [(diff.inDays / 30).floor()],
    );
  }
  return tr('seller.reviews_time_years_ago', args: [(diff.inDays / 365).floor()]);
}
