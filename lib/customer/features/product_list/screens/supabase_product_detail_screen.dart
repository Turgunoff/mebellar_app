import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/result/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/constants/product_colors.dart';
import '../../../../shared/models/attribute_definition.dart';
import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/review.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/customer_reviews_repository.dart';
import '../../../../shared/repositories/supabase_product_data_source.dart';
import '../../../../shared/widgets/star_rating.dart';
// `AttributesRepository` is registered at root scope, so it resolves fine
// from the customer surface too.
import '../../../../seller/features/products/data/attributes_repository.dart';
// The customer detail page deliberately reuses the seller's product-preview
// widgets so the two screens are pixel-identical. Seller-only cards (preview
// banner, moderation status, SKU meta, edit action bar) are simply omitted.
import '../../../../seller/features/products/widgets/product_preview/attributes_card.dart';
import '../../../../seller/features/products/widgets/product_preview/description_card.dart';
import '../../../../seller/features/products/widgets/product_preview/logistics_card.dart';
import '../../../../seller/features/products/widgets/product_preview/preview_app_bar.dart';
import '../../../../seller/features/products/widgets/product_preview/product_preview_kit.dart';
import '../../../features/cart/bloc/cart_bloc.dart';
import '../../../features/favorites/bloc/favorites_bloc.dart';
import '../../home/widgets/premium/premium_product_card.dart';

/// Seller-mode font + Uzbek number grouping — kept identical to the seller
/// preview so the customer detail page renders the same.
TextStyle _ts({
  required double size,
  FontWeight weight = FontWeight.w500,
  Color color = kInk,
  double height = 1.3,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: AppFonts.seller,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

String _money(num value) => NumberFormat('#,###', 'uz').format(value);

class SupabaseProductDetailScreen extends StatefulWidget {
  const SupabaseProductDetailScreen({super.key, required this.product});

  final SupabaseProductModel product;

  @override
  State<SupabaseProductDetailScreen> createState() =>
      _SupabaseProductDetailScreenState();
}

class _SupabaseProductDetailScreenState
    extends State<SupabaseProductDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  double _titleOpacity = 0;

  /// Attribute schema for this product's category — resolves raw JSONB keys
  /// into human labels. Empty while loading / on failure; the attributes
  /// card falls back to humanised keys so it never blocks rendering.
  List<AttributeDefinition> _schema = const [];

  /// Colour the customer picked. `_colorError` flips true when they try to
  /// add to cart without choosing one — mandatory for products with colours.
  String? _selectedColor;
  bool _colorError = false;

  /// Anchors the colours card so a failed validation can scroll it into view.
  final GlobalKey _colorsCardKey = GlobalKey();

  /// Product colours resolved against the shared palette; unknown slugs are
  /// dropped so the card never paints a fallback swatch.
  List<ProductColorOption> get _colorOptions {
    final out = <ProductColorOption>[];
    for (final slug in widget.product.colors) {
      final option = productColorBySlug(slug);
      if (option != null) out.add(option);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_loadSchema());
    // Analytics: a single view_item per detail open. Fired here (not in
    // the build) so a rebuild from a stock refresh doesn't double-count.
    unawaited(sl<AnalyticsService>().productViewed(
      productId: widget.product.id,
      categoryId: widget.product.categoryId,
      price: widget.product.effectivePrice,
    ));
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  /// Fades the toolbar title in over the last ~80dp of the gallery collapse —
  /// mirrors `SellerProductDetailScreen` exactly.
  void _handleScroll() {
    final media = MediaQuery.of(context);
    final expandedHeight = media.size.width;
    final collapsedHeight = kToolbarHeight + media.padding.top;
    final fadeStart = expandedHeight - collapsedHeight - 80;
    final fadeEnd = expandedHeight - collapsedHeight;
    final offset = _scrollController.offset;
    final double next;
    if (offset <= fadeStart) {
      next = 0;
    } else if (offset >= fadeEnd) {
      next = 1;
    } else {
      next = (offset - fadeStart) / (fadeEnd - fadeStart);
    }
    if ((next - _titleOpacity).abs() > 0.02) {
      setState(() => _titleOpacity = next);
    }
  }

  Future<void> _loadSchema() async {
    final p = widget.product;
    if (p.attributes == null || p.attributes!.isEmpty) return;
    try {
      final schema = await sl<AttributesRepository>().loadForCategory(
        categoryId: p.categoryId,
        subcategoryId: p.subcategoryId,
      );
      if (mounted) setState(() => _schema = schema);
    } catch (_) {
      // Leave `_schema` empty — the attributes card humanises raw keys.
    }
  }

  /// Adds the product to the cart. When the product has colours, a pick is
  /// mandatory — without one the colours card flags an error and scrolls
  /// into view instead of adding anything.
  void _handleAddToCart() {
    if (_colorOptions.isNotEmpty && _selectedColor == null) {
      setState(() => _colorError = true);
      final cardContext = _colorsCardKey.currentContext;
      if (cardContext != null) {
        Scrollable.ensureVisible(
          cardContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.1,
        );
      }
      return;
    }
    context.read<CartBloc>().add(
      AddToCart(widget.product, selectedColor: _selectedColor),
    );
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr('cart.item_added')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final description = product.description?.trim() ?? '';
    final attributeRows = _attributeRows(product.attributes ?? const {});
    final shopName = product.shopName?.trim() ?? '';
    final colorOptions = _colorOptions;
    final showLogistics =
        (product.productionTimeDays?.trim().isNotEmpty ?? false) ||
        product.hasDelivery ||
        product.hasInstallation ||
        product.warrantyMonths > 0;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              PreviewAppBar(
                images: product.images,
                heroTagPrefix: 'product-${product.id}',
                productName: product.name,
                titleOpacity: _titleOpacity,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TitlePriceCard(product: product),
                      for (final card in [
                        // Colours sit right under the price — they are the
                        // first thing a furniture buyer looks for, and the
                        // pick is mandatory before adding to the cart.
                        if (colorOptions.isNotEmpty)
                          _ColorsCard(
                            key: _colorsCardKey,
                            options: colorOptions,
                            selectedSlug: _selectedColor,
                            showError: _colorError,
                            onSelect: (slug) => setState(() {
                              _selectedColor = slug;
                              _colorError = false;
                            }),
                          ),
                        if (shopName.isNotEmpty) _ShopCard(name: shopName),
                        if (description.isNotEmpty)
                          DescriptionCard(text: description),
                        if (attributeRows.isNotEmpty)
                          AttributesCard(rows: attributeRows),
                        if (showLogistics)
                          LogisticsCard(
                            productionTimeDays: product.productionTimeDays,
                            hasDelivery: product.hasDelivery,
                            deliveryPrice: product.deliveryPrice,
                            hasInstallation: product.hasInstallation,
                            installationPrice: product.installationPrice,
                            warrantyMonths: product.warrantyMonths,
                          ),
                      ]) ...[const SizedBox(height: 14), card],
                      _ReviewsSection(productId: product.id),
                      _SimilarSection(productId: product.id),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(product: product, onAddToCart: _handleAddToCart),
          ),
        ],
      ),
    );
  }

  // ─── Attribute resolution — mirrors SellerProductDetailScreen ─────────────

  /// Builds the `(label, value)` rows the [AttributesCard] renders. Schema
  /// keys come first (so the order matches the seller's form), then leftovers.
  List<(String, String)> _attributeRows(Map<String, dynamic> attributes) {
    final defByKey = {for (final d in _schema) d.key: d};
    final rows = <(String, String)>[];
    final seen = <String>{};
    for (final def in _schema) {
      if (!attributes.containsKey(def.key)) continue;
      final value = _renderValue(attributes[def.key], def);
      if (value.isEmpty) continue;
      rows.add((_resolveLabel(def.key, def), value));
      seen.add(def.key);
    }
    for (final entry in attributes.entries) {
      if (seen.contains(entry.key)) continue;
      final value = _renderValue(entry.value, defByKey[entry.key]);
      if (value.isEmpty) continue;
      rows.add((_resolveLabel(entry.key, defByKey[entry.key]), value));
    }
    return rows;
  }

  String _resolveLabel(String key, AttributeDefinition? def) {
    if (def != null) return def.labelUz;
    final tk = 'attributes.$key';
    final translated = tr(tk);
    if (translated != tk) return translated;
    return key
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());
  }

  String _renderValue(dynamic value, AttributeDefinition? def) {
    if (value == null) return '';
    if (value is bool) return value ? tr('common.yes') : tr('common.no');
    if (value is List) {
      return value
          .map((v) => _resolveOptionLabel(v?.toString() ?? '', def))
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
    final str = value.toString();
    if (def?.dataType == AttributeDataType.select) {
      return _resolveOptionLabel(str, def);
    }
    final unit = def?.unit;
    if (unit != null && unit.isNotEmpty && str.isNotEmpty) {
      return '$str $unit';
    }
    return str;
  }

  String _resolveOptionLabel(String value, AttributeDefinition? def) {
    if (def == null) return value;
    for (final opt in def.options) {
      if (opt.value == value) return opt.labelUz;
    }
    return value;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Title + price card
// ═══════════════════════════════════════════════════════════════════════════

class _TitlePriceCard extends StatelessWidget {
  const _TitlePriceCard({required this.product});

  final SupabaseProductModel product;

  static const Color _green = Color(0xFF1F6B49);

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: _ts(
              size: 20,
              weight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  text: _money(product.effectivePrice),
                  style: _ts(
                    size: 26,
                    weight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                  children: [
                    TextSpan(
                      text: '  UZS',
                      style: _ts(
                        size: 13,
                        weight: FontWeight.w700,
                        color: kGreyMid,
                      ),
                    ),
                  ],
                ),
              ),
              if (product.hasDiscount) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${_money(product.price)} UZS',
                    style:
                        _ts(
                          size: 13,
                          weight: FontWeight.w500,
                          color: kGreySoft,
                          height: 1.0,
                        ).copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: kGreySoft,
                        ),
                  ),
                ),
              ],
            ],
          ),
          if (product.hasDiscount) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-${product.discountPercent}%',
                style: _ts(
                  size: 12,
                  weight: FontWeight.w800,
                  color: const Color(0xFFC0392B),
                  height: 1.0,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: kDivider),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Iconsax.tick_circle, size: 16, color: _green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sotuvda mavjud · buyurtma bo\'yicha tayyorlanadi',
                  style: _ts(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _green,
                    height: 1.2,
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

// ═══════════════════════════════════════════════════════════════════════════
// Shop card
// ═══════════════════════════════════════════════════════════════════════════

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.terracotta.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Iconsax.shop,
              size: 21,
              color: AppColors.terracotta,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sotuvchi', style: _ts(size: 12, color: kGrey)),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: _ts(size: 14.5, weight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Colours — placed directly under the price card
// ═══════════════════════════════════════════════════════════════════════════

/// Error tint shared by the colour validation hint.
const Color _kColorError = Color(0xFFD64545);

class _ColorsCard extends StatelessWidget {
  const _ColorsCard({
    super.key,
    required this.options,
    required this.selectedSlug,
    required this.showError,
    required this.onSelect,
  });

  final List<ProductColorOption> options;
  final String? selectedSlug;
  final bool showError;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = selectedSlug == null
        ? null
        : productColorBySlug(selectedSlug!);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionTitle(text: 'Rang tanlang'),
              const Spacer(),
              if (selected != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.tick_circle,
                      size: 14,
                      color: AppColors.terracotta,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selected.label,
                      style: _ts(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: AppColors.terracotta,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _ColorChip(
                  option: option,
                  selected: option.slug == selectedSlug,
                  onTap: () => onSelect(option.slug),
                ),
            ],
          ),
          if (showError) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Iconsax.info_circle, size: 13, color: _kColorError),
                const SizedBox(width: 5),
                Text(
                  'Davom etish uchun rang tanlang',
                  style: _ts(
                    size: 12,
                    weight: FontWeight.w600,
                    color: _kColorError,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ProductColorOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The tick contrasts against the swatch: dark accent on light fills
    // (e.g. white/beige), white on dark ones — so it stays visible on both.
    final tickColor = option.swatch.computeLuminance() > 0.6
        ? AppColors.terracotta
        : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(5, 5, 13, 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.terracotta.withValues(alpha: 0.08)
              : kSurfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.terracotta : kOutline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: option.swatch,
                shape: BoxShape.circle,
                border: Border.all(color: kOutline, width: 1),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 13, color: tickColor)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: _ts(
                size: 13,
                weight: FontWeight.w700,
                color: selected ? AppColors.terracotta : kInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reviews section
// ═══════════════════════════════════════════════════════════════════════════

class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({required this.productId});

  final String productId;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  late final Future<Result<ProductReviewSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<CustomerReviewsRepository>().reviewsForProduct(
      widget.productId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<ProductReviewSummary>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final summary =
            snap.data?.fold(
              ok: (s) => s,
              err: (_) => ProductReviewSummary.empty,
            ) ??
            ProductReviewSummary.empty;
        if (summary.isEmpty) return const SizedBox.shrink();
        final shown = summary.reviews.take(4).toList();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(text: 'Sharhlar'),
                const SizedBox(height: 14),
                _SummaryRow(summary: summary),
                for (final review in shown) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: kDivider),
                  const SizedBox(height: 12),
                  _ReviewRow(review: review),
                ],
                if (summary.count > shown.length) ...[
                  const SizedBox(height: 12),
                  Text(
                    'va yana ${summary.count - shown.length} ta sharh',
                    style: _ts(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: kGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final ProductReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          summary.average.toStringAsFixed(1),
          style: _ts(size: 34, weight: FontWeight.w800, letterSpacing: -0.6),
        ),
        const SizedBox(width: 14),
        Container(width: 1, height: 42, color: kDivider),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StarRating(rating: summary.average, size: 16),
            const SizedBox(height: 4),
            Text(
              '${summary.count} ta xaridor baho berdi',
              style: _ts(size: 12.5, color: kGrey),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final name = review.customerName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final comment = review.comment.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.terracotta.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: _ts(
                  size: 15,
                  weight: FontWeight.w700,
                  color: AppColors.terracotta,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Xaridor' : name,
                    style: _ts(size: 13.5, weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtReviewDate(review.createdAt),
                    style: _ts(size: 11, color: kGreySoft),
                  ),
                ],
              ),
            ),
            StarRating(rating: review.rating.toDouble(), size: 13),
          ],
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(comment, style: _ts(size: 13, color: kInk, height: 1.5)),
        ],
        if (review.hasReply) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: kSurfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.shop, size: 12, color: kGrey),
                    const SizedBox(width: 5),
                    Text(
                      'Sotuvchi javobi',
                      style: _ts(size: 11.5, weight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  review.sellerReply!.trim(),
                  style: _ts(size: 12.5, color: kGrey, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// `2026-05-21T…` → `21.05.2026` (local).
String _fmtReviewDate(DateTime date) {
  final d = date.toLocal();
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

// ═══════════════════════════════════════════════════════════════════════════
// Similar products
// ═══════════════════════════════════════════════════════════════════════════

class _SimilarSection extends StatefulWidget {
  const _SimilarSection({required this.productId});

  final String productId;

  @override
  State<_SimilarSection> createState() => _SimilarSectionState();
}

class _SimilarSectionState extends State<_SimilarSection> {
  late final Future<List<SupabaseProductModel>> _future;

  @override
  void initState() {
    super.initState();
    // Server-ranked recommendations — see `get_similar_products`.
    _future = sl<SupabaseProductDataSource>().listSimilar(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupabaseProductModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sizga yoqishi mumkin',
                  style: _ts(
                    size: 16,
                    weight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                const _SimilarSkeleton(),
              ],
            ),
          );
        }
        final products = snap.data ?? const [];
        if (products.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sizga yoqishi mumkin',
                style: _ts(
                  size: 16,
                  weight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 16),
              // Horizontal carousel — `clipBehavior: none` keeps each card's
              // soft shadow from being clipped at the rail's top/bottom edge.
              SizedBox(
                height: _kSimilarCardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  physics: const BouncingScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (ctx, i) {
                    final p = products[i];
                    return SizedBox(
                      width: _kSimilarCardWidth,
                      child: BlocSelector<FavoritesBloc, FavoritesState, bool>(
                        selector: (state) => state.isFavorite(p.id),
                        builder: (ctx, isFav) => PremiumProductCard(
                          imageUrl: p.thumbnail ?? '',
                          name: p.name,
                          shop: '',
                          price: '${_money(p.effectivePrice)} UZS',
                          discountPercent: p.discountPercent,
                          isFavorite: isFav,
                          customImageHeight: _kSimilarImageHeight,
                          onTap: () =>
                              context.push('/product-detail/${p.id}', extra: p),
                          onFavoriteToggle: () => context
                              .read<FavoritesBloc>()
                              .add(FavoriteToggled(_toProduct(p))),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Carousel card geometry — shared by the loaded rail and its skeleton so
// both reserve exactly the same height.
const double _kSimilarCardWidth = 160;
const double _kSimilarImageHeight = 150;
const double _kSimilarCardHeight = 240;

class _SimilarSkeleton extends StatelessWidget {
  const _SimilarSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kSimilarCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => Shimmer.fromColors(
          baseColor: kImageBg,
          highlightColor: Colors.white,
          child: Container(
            width: _kSimilarCardWidth,
            decoration: BoxDecoration(
              color: kImageBg,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom action bar — customer (favourite + add to cart)
// ═══════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.product, required this.onAddToCart});

  final SupabaseProductModel product;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          BlocSelector<FavoritesBloc, FavoritesState, bool>(
            selector: (state) => state.isFavorite(product.id),
            builder: (context, isFav) {
              return GestureDetector(
                onTap: () => context.read<FavoritesBloc>().add(
                  FavoriteToggled(_toProduct(product)),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isFav
                        ? AppColors.terracotta.withValues(alpha: 0.12)
                        : kImageBg,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isFav
                          ? AppColors.terracotta.withValues(alpha: 0.4)
                          : kOutline,
                    ),
                  ),
                  child: Icon(
                    isFav ? Iconsax.heart_copy : Iconsax.heart,
                    size: 23,
                    color: isFav ? AppColors.terracotta : kGrey,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onAddToCart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                minimumSize: const Size.fromHeight(54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Iconsax.shopping_bag,
                    size: 19,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    tr('cart.add'),
                    style: _ts(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

Product _toProduct(SupabaseProductModel m) => Product(
  id: m.id,
  slug: m.id,
  name: MultilingualText(uz: m.name, ru: m.name, en: m.name),
  price: m.effectivePrice,
  oldPrice: m.hasDiscount ? m.price : null,
  images: m.images,
  attributes: m.attributes,
  stock: m.stock,
);
