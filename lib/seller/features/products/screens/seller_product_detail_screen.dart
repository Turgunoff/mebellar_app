import 'package:flutter/material.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/attribute_definition.dart';
import '../../../../shared/models/seller_product.dart';
import '../bloc/add_product_cubit.dart';
import '../data/attributes_repository.dart';
import '../widgets/product_preview/attributes_card.dart';
import '../widgets/product_preview/bottom_action_bar.dart';
import '../widgets/product_preview/description_card.dart';
import '../widgets/product_preview/logistics_card.dart';
import '../widgets/product_preview/meta_card.dart';
import '../widgets/product_preview/preview_app_bar.dart';
import '../widgets/product_preview/preview_summary_cards.dart';
import '../widgets/product_preview/spec_cards.dart';

/// Customer-style preview of a seller's own product — gallery, title/price,
/// status and the buyer-facing content cards, with an Edit primary action.
///
/// On open the screen kicks off an [AttributesRepository.loadForCategory]
/// fetch for the product's (category, subcategory) so attribute keys and
/// `select`/`multiselect` values can be resolved from their canonical slugs
/// (`fabric_type` → "Mato turi", `velour` → "Velur"). Until the schema
/// arrives, raw keys are shown as a humanised fallback.
class SellerProductDetailScreen extends StatefulWidget {
  const SellerProductDetailScreen({
    super.key,
    required this.product,
    this.onEdit,
  });

  final SellerProduct product;
  final VoidCallback? onEdit;

  @override
  State<SellerProductDetailScreen> createState() =>
      _SellerProductDetailScreenState();
}

class _SellerProductDetailScreenState extends State<SellerProductDetailScreen> {
  List<AttributeDefinition> _schema = const [];
  final ScrollController _scrollController = ScrollController();
  double _titleOpacity = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadSchema();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  /// Computes how much the title should fade in based on the user's scroll
  /// past the gallery. The bar is `width × width` tall when fully expanded,
  /// shrinking to `kToolbarHeight + statusBar` when fully pinned. We fade in
  /// across the last ~80dp of that collapse so the title appears just as the
  /// gallery is about to clip off.
  void _handleScroll() {
    final media = MediaQuery.of(context);
    final expandedHeight = media.size.width;
    final collapsedHeight = kToolbarHeight + media.padding.top;
    final fadeStart = expandedHeight - collapsedHeight - 80;
    final fadeEnd = expandedHeight - collapsedHeight;
    final offset = _scrollController.offset;
    double next;
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
    final categoryId = widget.product.categorySlug;
    if (categoryId.isEmpty) return;
    try {
      final schema =
          await sl<AttributesRepository>().loadForCategory(
        categoryId: categoryId,
        subcategoryId: widget.product.subcategoryId,
      );
      if (!mounted) return;
      setState(() => _schema = schema);
    } catch (e, st) {
      talker.handle(e, st,
          '[seller-product-detail] schema load failed productId=${widget.product.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final imageUrls = [
      for (final img in product.images)
        if (img.remoteUrl != null && img.remoteUrl!.isNotEmpty) img.remoteUrl!,
    ];
    final description = product.description.uz?.trim() ?? '';
    final attributeRows = _attributeRows(product);
    final hasDimensions = product.widthCm != null ||
        product.heightCm != null ||
        product.lengthCm != null ||
        product.weightKg != null;
    final showLogistics = (product.productionTimeDays?.isNotEmpty ?? false) ||
        product.hasDelivery ||
        product.hasInstallation ||
        product.warrantyMonths > 0;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          PreviewAppBar(
            images: imageUrls,
            heroTagPrefix: 'seller-product-${product.id}',
            productName: product.name.get('uz'),
            titleOpacity: _titleOpacity,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PreviewModeBanner(),
                  const SizedBox(height: 14),
                  StatusCard(
                    status: product.status,
                    updatedAtLabel: _formatDateTime(product.updatedAt),
                  ),
                  const SizedBox(height: 14),
                  TitlePriceCard(product: product),
                  const SizedBox(height: 14),
                  MetaCard(
                    sku: product.sku.isEmpty ? '—' : product.sku,
                    category: product.categoryName ?? '—',
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    DescriptionCard(text: description),
                  ],
                  if (attributeRows.isNotEmpty || product.colors.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    AttributesCard(
                      rows: attributeRows,
                      colorChips: _colorChipsFor(product.colors),
                    ),
                  ],
                  if (hasDimensions) ...[
                    const SizedBox(height: 14),
                    DimensionsCard(
                      lengthCm: product.lengthCm ?? 0,
                      widthCm: product.widthCm ?? 0,
                      heightCm: product.heightCm ?? 0,
                      weightKg: product.weightKg ?? 0,
                    ),
                  ],
                  if (showLogistics) ...[
                    const SizedBox(height: 14),
                    LogisticsCard(
                      productionTimeDays: product.productionTimeDays,
                      hasDelivery: product.hasDelivery,
                      deliveryPrice: product.deliveryPrice,
                      hasInstallation: product.hasInstallation,
                      installationPrice: product.installationPrice,
                      warrantyMonths: product.warrantyMonths,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(onEdit: widget.onEdit),
    );
  }

  /// Builds the `(label, value)` rows the [AttributesCard] renders.
  ///
  /// Resolution order for each row:
  /// 1. If the DB schema has a definition for the key — use its `label_uz`
  ///    and, for select/multiselect values, the matching option's
  ///    `label_uz`.
  /// 2. Otherwise fall back to the i18n `attributes.<key>` entry from
  ///    `product_translations.dart`.
  /// 3. Last resort: humanise the raw key (snake_case → Title Case).
  ///
  /// Colours are NOT included here — they're rendered as swatch chips in the
  /// dedicated `colorChips` slot on [AttributesCard].
  List<(String, String)> _attributeRows(SellerProduct p) {
    final defByKey = {for (final d in _schema) d.key: d};
    final rows = <(String, String)>[];

    // Stable order: schema-declared keys first (so the preview matches the
    // form's layout), then anything left over.
    final seen = <String>{};
    for (final def in _schema) {
      if (!p.attributes.containsKey(def.key)) continue;
      final value = _renderValue(p.attributes[def.key], def);
      if (value.isEmpty) continue;
      rows.add((_resolveLabel(def.key, def), value));
      seen.add(def.key);
    }
    for (final entry in p.attributes.entries) {
      if (seen.contains(entry.key)) continue;
      final value = _renderValue(entry.value, defByKey[entry.key]);
      if (value.isEmpty) continue;
      rows.add((_resolveLabel(entry.key, defByKey[entry.key]), value));
    }
    return rows;
  }

  /// Maps each persisted colour slug to its visual chip (label + swatch).
  /// Unknown slugs are skipped so we never paint a fallback "?" swatch.
  List<AttributeColorChip> _colorChipsFor(List<String> slugs) {
    if (slugs.isEmpty) return const [];
    final palette = {
      for (final option in kAddProductColorOptions)
        option.slug: option,
    };
    return [
      for (final slug in slugs)
        if (palette[slug] != null)
          AttributeColorChip(
            label: palette[slug]!.label,
            swatch: Color(palette[slug]!.swatch),
          ),
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
    if (value is bool) return value ? 'Ha' : 'Yo\'q';
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

  String _formatDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, HH:mm', 'uz').format(dt);
}

