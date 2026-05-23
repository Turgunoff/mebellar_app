import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/analytics.dart';
import 'analytics_common.dart';
import 'revenue_line_chart.dart';

/// "Baholar" tab — average rating hero + distribution histogram +
/// reply-rate + recent reviews preview.
class ReviewsTab extends StatelessWidget {
  const ReviewsTab({super.key, required this.snapshot, required this.refreshing});

  final AnalyticsSnapshot snapshot;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final reviews = snapshot.reviews;
    final granularity = snapshot.filter.granularityFor(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _ReviewsHeroCard(
          reviews: reviews,
          granularity: granularity,
          refreshing: refreshing,
        ),
        const SizedBox(height: 14),
        _ReviewsKpiRow(reviews: reviews),
        const SizedBox(height: 24),
        _DistributionCard(reviews: reviews),
        const SizedBox(height: 24),
        _RecentReviewsSection(reviews: reviews),
      ],
    );
  }
}

class _ReviewsHeroCard extends StatelessWidget {
  const _ReviewsHeroCard({
    required this.reviews,
    required this.granularity,
    required this.refreshing,
  });

  final ReviewsBreakdown reviews;
  final BucketGranularity granularity;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final hasData = reviews.total > 0;
    return AnalyticsCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Davr ichidagi o'rtacha baho",
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AnalyticsTokens.grey,
                  ),
                ),
              ),
              if (refreshing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    valueColor:
                        AlwaysStoppedAnimation(AnalyticsTokens.positive),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasData ? reviews.average.toStringAsFixed(2) : '—',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AnalyticsTokens.ink,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _StarRow(value: reviews.average, size: 18),
              ),
              const Spacer(),
              TrendChip(deltaPercent: reviews.deltaPercent),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${reviews.total} ta sharh',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AnalyticsTokens.grey,
            ),
          ),
          if (reviews.series.isNotEmpty &&
              reviews.series.any((p) => p.count > 0)) ...[
            const SizedBox(height: 14),
            RevenueLineChart(
              values: reviews.series
                  .map((p) => p.count.toDouble() as num)
                  .toList(),
              dates: reviews.series.map((p) => p.bucketStart).toList(),
              granularity: granularity,
              valueFormatter: (v) => v.round().toString(),
              unit: 'sharh',
              height: 130,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewsKpiRow extends StatelessWidget {
  const _ReviewsKpiRow({required this.reviews});

  final ReviewsBreakdown reviews;

  @override
  Widget build(BuildContext context) {
    final replyRate = reviews.replyRate;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.message_text,
              label: 'Sharhlar',
              value: reviews.total.toString(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.reserve,
              label: 'Javob berildi',
              value: reviews.repliedCount.toString(),
              color: AnalyticsTokens.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.percentage_circle,
              label: 'Javob %',
              value: replyRate == null
                  ? '—'
                  : '${replyRate.toStringAsFixed(0)}%',
              color: AnalyticsTokens.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.reviews});

  final ReviewsBreakdown reviews;

  @override
  Widget build(BuildContext context) {
    final dist = reviews.distribution;
    final max = dist.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Baholar taqsimoti'),
        AnalyticsCard(
          child: reviews.total == 0
              ? SectionEmpty(
                  icon: Iconsax.star_1,
                  message: "Bu davr uchun sharh yo'q",
                )
              : Column(
                  children: [
                    for (var star = 5; star >= 1; star--) ...[
                      if (star < 5) const SizedBox(height: 10),
                      _DistributionRow(
                        star: star,
                        count: dist[star] ?? 0,
                        max: max == 0 ? 1 : max,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.star,
    required this.count,
    required this.max,
  });

  final int star;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = count / max;
    final color = switch (star) {
      5 => AnalyticsTokens.success,
      4 => const Color(0xFF84CC16),
      3 => AnalyticsTokens.warning,
      2 => const Color(0xFFF97316),
      _ => AnalyticsTokens.negative,
    };
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(
            '$star',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AnalyticsTokens.ink,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Iconsax.star_1, size: 14, color: Color(0xFFFBBF24)),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: AnalyticsTokens.placeholderBg),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0, 1),
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AnalyticsTokens.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentReviewsSection extends StatelessWidget {
  const _RecentReviewsSection({required this.reviews});

  final ReviewsBreakdown reviews;

  @override
  Widget build(BuildContext context) {
    final items = reviews.recent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "So'nggi sharhlar"),
        if (items.isEmpty)
          AnalyticsCard(
            child: SectionEmpty(
              icon: Iconsax.message_text,
              message: "Hozircha sharhlar yo'q",
            ),
          )
        else
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _RecentReviewTile(review: items[i]),
          ),
      ],
    );
  }
}

class _RecentReviewTile extends StatelessWidget {
  const _RecentReviewTile({required this.review});

  final ReviewPreview review;

  @override
  Widget build(BuildContext context) {
    return AnalyticsCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AnalyticsTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AnalyticsTokens.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _StarRow(value: review.rating.toDouble(), size: 14),
            ],
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AnalyticsTokens.ink,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                AnalyticsFmt.relative(review.createdAt),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AnalyticsTokens.greyMid,
                ),
              ),
              const Spacer(),
              if (review.hasReply)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AnalyticsTokens.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.tick_circle,
                          size: 12, color: AnalyticsTokens.success),
                      const SizedBox(width: 4),
                      Text(
                        'Javob berildi',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AnalyticsTokens.success,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AnalyticsTokens.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.message_question,
                          size: 12, color: AnalyticsTokens.warning),
                      const SizedBox(width: 4),
                      Text(
                        'Javob kutilmoqda',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AnalyticsTokens.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Five-star row with half-fill support. Rendered from a single decimal
/// value so it can show "4.3" with a partially-filled fourth star.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.value, this.size = 14});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) _starAt(i),
      ],
    );
  }

  Widget _starAt(int idx) {
    // Use rounded half-step to keep the visual close to the numeric.
    final delta = value - (idx - 1);
    final IconData icon;
    if (delta >= 0.75) {
      icon = Iconsax.star_1;
    } else if (delta >= 0.25) {
      icon = Iconsax.star_slash;
    } else {
      icon = Iconsax.star;
    }
    final color = delta >= 0.25
        ? const Color(0xFFFBBF24)
        : const Color(0xFFE5E5E5);
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Icon(icon, size: size, color: color),
    );
  }
}
