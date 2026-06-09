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
import '../../../../shared/models/product.dart';
import '../../../../shared/models/review.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/repositories/customer_reviews_repository.dart';
import '../../../../shared/repositories/product_data_source.dart';
import '../../../../shared/widgets/star_rating.dart';
// `AttributesRepository` is registered at root scope, so it resolves fine
// from the customer surface too.
import '../../../../seller/features/products/data/attributes_repository.dart';
// The customer detail page deliberately reuses the seller's product-preview
// widgets so the two screens are pixel-identical. Seller-only cards (preview
// banner, moderation status, SKU meta, edit action bar) are simply omitted.
import '../../../../seller/features/products/widgets/product_form/dimensions_card.dart'
    as form_dims;
import '../../../../seller/features/products/widgets/product_preview/attributes_card.dart';
import '../../../../seller/features/products/widgets/product_preview/description_card.dart';
import '../../../../seller/features/products/widgets/product_preview/logistics_card.dart';
import '../../../../seller/features/products/widgets/product_preview/meta_card.dart';
import '../../../../seller/features/products/widgets/product_preview/preview_app_bar.dart';
import '../../../../seller/features/products/widgets/product_preview/spec_cards.dart';
import '../../../features/cart/bloc/cart_bloc.dart';
import '../../../features/favorites/bloc/favorites_bloc.dart';
import '../../home/widgets/premium/premium_product_card.dart';
import '../../home/widgets/premium/premium_tokens.dart';

part 'catalog_product_detail_sections.dart';

/// Seller-mode font + Uzbek number grouping — kept identical to the seller
/// preview so the customer detail page renders the same. `color` is nullable:
/// pass an adaptive `PremiumTokens.of(context).dark` from the call site (it
/// can't be a const default).
TextStyle _ts({
  required double size,
  FontWeight weight = FontWeight.w500,
  Color? color,
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

// ═══════════════════════════════════════════════════════════════════════════
// Customer-native section primitives — replace the seller kit's SectionCard /
// SectionTitle (which read SellerColors). These flip with customer dark mode
// via PremiumTokens. Shared with the `part` file (catalog_product_detail_sections).
// ═══════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: PremiumTokens.of(context).dark,
        letterSpacing: -0.2,
        height: 1.2,
      ),
    );
  }
}

class CatalogProductDetailScreen extends StatefulWidget {
  const CatalogProductDetailScreen({super.key, required this.product});

  final ProductModel product;

  @override
  State<CatalogProductDetailScreen> createState() =>
      _CatalogProductDetailScreenState();
}

class _CatalogProductDetailScreenState
    extends State<CatalogProductDetailScreen> {
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
    unawaited(
      sl<AnalyticsService>().productViewed(
        productId: widget.product.id,
        categoryId: widget.product.categoryId,
        price: widget.product.effectivePrice,
      ),
    );
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
    final attributes = product.attributes ?? const {};
    final attributeRows = _attributeRows(attributes);
    final setDimensionGroups = _setDimensionGroups(attributes);
    final shopName = product.shopName?.trim() ?? '';
    final colorOptions = _colorOptions;
    final categoryName = product.categoryName?.trim() ?? '';
    final hasMeta =
        categoryName.isNotEmpty ||
        (product.subcategoryName?.trim().isNotEmpty ?? false) ||
        (product.material?.trim().isNotEmpty ?? false);
    final hasTypedDimensions =
        (product.widthCm ?? 0) > 0 ||
        (product.heightCm ?? 0) > 0 ||
        (product.depthCm ?? 0) > 0;
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
                        if (shopName.isNotEmpty)
                          _ShopCard(name: shopName, shopId: product.shopId),
                        if (hasMeta)
                          MetaCard(
                            category: categoryName.isEmpty ? '—' : categoryName,
                            subcategory: product.subcategoryName,
                            material: product.material,
                          ),
                        if (description.isNotEmpty)
                          DescriptionCard(text: description),
                        if (attributeRows.isNotEmpty)
                          AttributesCard(rows: attributeRows),
                        if (setDimensionGroups.isNotEmpty)
                          SetDimensionsCard(groups: setDimensionGroups),
                        if (hasTypedDimensions)
                          DimensionsCard(
                            lengthCm: product.depthCm,
                            widthCm: product.widthCm,
                            heightCm: product.heightCm,
                          ),
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
  /// Per-piece dimension attributes are excluded — they render in the grouped
  /// [SetDimensionsCard] instead of as flat rows (matching the seller detail).
  List<(String, String)> _attributeRows(Map<String, dynamic> attributes) {
    final defByKey = {for (final d in _schema) d.key: d};
    final rows = <(String, String)>[];
    final seen = <String>{};
    for (final def in _schema) {
      if (!attributes.containsKey(def.key)) continue;
      if (form_dims.DimensionsCard.isDimensionAttribute(def)) continue;
      final value = _renderValue(attributes[def.key], def);
      if (value.isEmpty) continue;
      rows.add((_resolveLabel(def.key, def), value));
      seen.add(def.key);
    }
    for (final entry in attributes.entries) {
      if (seen.contains(entry.key)) continue;
      final def = defByKey[entry.key];
      if (def != null && form_dims.DimensionsCard.isDimensionAttribute(def)) {
        continue;
      }
      final value = _renderValue(entry.value, def);
      if (value.isEmpty) continue;
      rows.add((_resolveLabel(entry.key, def), value));
    }
    return rows;
  }

  /// Groups per-piece dimension attributes (recognised via the seller form's
  /// [form_dims.DimensionsCard.isDimensionAttribute]) by furniture piece, so a
  /// bedroom set reads as KARAVOT / SHKAF / TRYUMO blocks rather than nine flat
  /// rows. Empty for single, non-set products.
  List<SetDimensionGroup> _setDimensionGroups(Map<String, dynamic> attributes) {
    const locale = 'uz';
    final order = <String>[];
    final byPiece = <String, List<(String, String)>>{};
    for (final def in _schema) {
      if (!form_dims.DimensionsCard.isDimensionAttribute(def)) continue;
      if (!attributes.containsKey(def.key)) continue;
      final value = _renderValue(attributes[def.key], def);
      if (value.isEmpty) continue;
      final label = def.labelFor(locale);
      final dash = label.indexOf('—');
      final piece = dash == -1 ? label : label.substring(0, dash).trim();
      final measure = dash == -1 ? label : label.substring(dash + 1).trim();
      byPiece
          .putIfAbsent(piece, () {
            order.add(piece);
            return [];
          })
          .add((measure, value));
    }
    return [
      for (final piece in order)
        SetDimensionGroup(piece: piece, measures: byPiece[piece]!),
    ];
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

  final ProductModel product;

  static const Color _green = Color(0xFF1F6B49);

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return _SectionCard(
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
              color: pt.dark,
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
                    color: pt.dark,
                  ),
                  children: [
                    TextSpan(
                      text: '  UZS',
                      style: _ts(
                        size: 13,
                        weight: FontWeight.w700,
                        color: pt.greyLight,
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
                          color: pt.greyLight,
                          height: 1.0,
                        ).copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: pt.greyLight,
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
          Divider(height: 1, thickness: 1, color: pt.divider),
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
  const _ShopCard({required this.name, this.shopId});

  final String name;

  /// Seller's shop id. When present, the card opens the public shop profile;
  /// null (a dangling shop reference) leaves the card static.
  final String? shopId;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final tappable = (shopId ?? '').isNotEmpty;
    final row = Row(
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
              Text('Sotuvchi', style: _ts(size: 12, color: pt.grey)),
              const SizedBox(height: 2),
              Text(
                name,
                style: _ts(size: 14.5, weight: FontWeight.w600, color: pt.dark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (tappable) ...[
          const SizedBox(width: 8),
          Text(
            'Profil',
            style: _ts(
              size: 12.5,
              weight: FontWeight.w600,
              color: AppColors.terracotta,
            ),
          ),
          const Icon(
            Iconsax.arrow_right_3,
            size: 16,
            color: AppColors.terracotta,
          ),
        ],
      ],
    );

    if (!tappable) return _SectionCard(child: row);
    return _SectionCard(
      child: InkWell(
        onTap: () => context.push('/shop/$shopId'),
        borderRadius: BorderRadius.circular(8),
        child: row,
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
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(text: 'Rang tanlang'),
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
    final pt = PremiumTokens.of(context);
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
              : pt.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.terracotta : pt.divider,
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
                border: Border.all(color: pt.divider, width: 1),
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
                color: selected ? AppColors.terracotta : pt.dark,
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
        final pt = PremiumTokens.of(context);
        final shown = summary.reviews.take(4).toList();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(text: 'Sharhlar'),
                const SizedBox(height: 14),
                _SummaryRow(summary: summary),
                for (final review in shown) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, thickness: 1, color: pt.divider),
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
                      color: pt.grey,
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
    final pt = PremiumTokens.of(context);
    return Row(
      children: [
        Text(
          summary.average.toStringAsFixed(1),
          style: _ts(
            size: 34,
            weight: FontWeight.w800,
            letterSpacing: -0.6,
            color: pt.dark,
          ),
        ),
        const SizedBox(width: 14),
        Container(width: 1, height: 42, color: pt.divider),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StarRating(rating: summary.average, size: 16),
            const SizedBox(height: 4),
            Text(
              '${summary.count} ta xaridor baho berdi',
              style: _ts(size: 12.5, color: pt.grey),
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
    final pt = PremiumTokens.of(context);
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
                    style: _ts(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: pt.dark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtReviewDate(review.createdAt),
                    style: _ts(size: 11, color: pt.greyLight),
                  ),
                ],
              ),
            ),
            StarRating(rating: review.rating.toDouble(), size: 13),
          ],
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(comment, style: _ts(size: 13, color: pt.dark, height: 1.5)),
        ],
        if (review.hasReply) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: pt.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.shop, size: 12, color: pt.grey),
                    const SizedBox(width: 5),
                    Text(
                      'Sotuvchi javobi',
                      style: _ts(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: pt.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  review.sellerReply!.trim(),
                  style: _ts(size: 12.5, color: pt.grey, height: 1.45),
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
