import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/constants/product_colors.dart';
import '../../../../shared/models/attribute_definition.dart';
import '../../../../shared/models/seller_product.dart';
import '../bloc/seller_products_bloc.dart';
import '../data/attributes_repository.dart';
import 'ar_scan_camera_screen.dart';
import '../widgets/product_preview/attributes_card.dart';
import '../widgets/product_preview/bottom_action_bar.dart';
import '../widgets/product_preview/description_card.dart';
import '../widgets/product_preview/logistics_card.dart';
import '../widgets/product_preview/meta_card.dart';
import '../widgets/product_form/dimensions_card.dart' as form_dims;
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

  // The product is passed in as a snapshot; archive/restore can change its
  // status without leaving the screen, so we track the live status locally and
  // let the bottom bar + status card flip between Archive and Restore.
  late SellerProductStatus _status = widget.product.status;
  bool _isBusy = false;

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
      final schema = await sl<AttributesRepository>().loadForCategory(
        categoryId: categoryId,
        subcategoryId: widget.product.subcategoryId,
      );
      if (!mounted) return;
      setState(() => _schema = schema);
    } catch (e, st) {
      talker.handle(
        e,
        st,
        '[seller-product-detail] schema load failed productId=${widget.product.id}',
      );
    }
  }

  Future<void> _onArchive() async {
    final confirmed = await _confirm(
      title: 'Mahsulotni arxivlash',
      message:
          'Mahsulot xaridorlarga ko\'rinmaydi, lekin keyin qaytarib olishingiz '
          'mumkin. Arxivlansinmi?',
      confirmLabel: 'Arxivlash',
      destructive: false,
    );
    if (confirmed != true) return;
    await _runMutation(
      action: () => context.read<SellerProductsBloc>().add(
        SellerProductArchived(widget.product.id),
      ),
      nextStatus: SellerProductStatus.archived,
      successMessage: 'Mahsulot arxivlandi',
    );
  }

  Future<void> _onRestore() async {
    await _runMutation(
      action: () => context.read<SellerProductsBloc>().add(
        SellerProductRestored(widget.product.id),
      ),
      nextStatus: SellerProductStatus.pendingReview,
      successMessage:
          'Mahsulot qaytarildi va qayta ko\'rib chiqishga yuborildi',
    );
  }

  /// Dispatches [action], waits for the bloc to settle, then reflects the new
  /// status locally and shows a snackbar. Surfaces the bloc's error if the
  /// mutation failed. Guards against a double-tap via [_isBusy].
  Future<void> _runMutation({
    required VoidCallback action,
    required SellerProductStatus nextStatus,
    required String successMessage,
  }) async {
    if (_isBusy) return;
    final bloc = context.read<SellerProductsBloc>();
    setState(() => _isBusy = true);
    action();
    // Wait until the bloc leaves the `mutating` state the event triggers.
    final settled = await bloc.stream.firstWhere(
      (s) => s.status != SellerProductsStatus.mutating,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (settled.error != null) {
      _showSnack(settled.error!, isError: true);
      return;
    }
    setState(() => _status = nextStatus);
    _showSnack(successMessage);
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required bool destructive,
  }) {
    final c = SellerColors.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.grey,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Bekor qilish',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w600,
                color: c.grey,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: destructive
                  ? AppColors.sellerNegative
                  : AppColors.sellerPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    final c = SellerColors.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: isError ? AppColors.sellerNegative : c.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Opens the custom AR scan camera. On a successful submit the product's
  /// model is queued for AI generation + admin QC, so we confirm and let the
  /// seller carry on (the model appears once approved).
  Future<void> _openArScan(String productId) async {
    // Push on the ROOT navigator so the camera covers the seller shell's
    // bottom navigation bar — a scanner must be a fully immersive surface.
    final submitted = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => ArScanCameraScreen(productId: productId),
      ),
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '3D model yaratilmoqda. Tasdiqdan so‘ng ilovada ko‘rinadi.',
            ),
          ),
        );
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
    final setDimensionGroups = _setDimensionGroups(product);
    final hasDimensions =
        (product.widthCm ?? 0) > 0 ||
        (product.heightCm ?? 0) > 0 ||
        (product.lengthCm ?? 0) > 0 ||
        (product.weightKg ?? 0) > 0;
    final showLogistics =
        (product.productionTimeDays?.isNotEmpty ?? false) ||
        product.hasDelivery ||
        product.hasInstallation ||
        product.warrantyMonths > 0;

    return Scaffold(
      backgroundColor: SellerColors.of(context).background,
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
                    status: _status,
                    updatedAtLabel: _formatDateTime(product.updatedAt),
                  ),
                  if (product.status == SellerProductStatus.rejected &&
                      (product.rejectionReason?.trim().isNotEmpty ??
                          false)) ...[
                    const SizedBox(height: 14),
                    RejectionReasonCard(
                      reason: product.rejectionReason!.trim(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TitlePriceCard(product: product),
                  const SizedBox(height: 14),
                  _ArScanCard(
                    product: product,
                    onScan: () => _openArScan(product.id),
                  ),
                  const SizedBox(height: 14),
                  MetaCard(
                    sku: product.sku.isEmpty ? '—' : product.sku,
                    category: product.categoryName ?? '—',
                    subcategory: product.subcategoryName,
                    material: product.material,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    DescriptionCard(text: description),
                  ],
                  if (attributeRows.isNotEmpty ||
                      product.colors.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    AttributesCard(
                      rows: attributeRows,
                      colorChips: _colorChipsFor(product.colors),
                    ),
                  ],
                  if (setDimensionGroups.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SetDimensionsCard(groups: setDimensionGroups),
                  ],
                  if (hasDimensions) ...[
                    const SizedBox(height: 14),
                    DimensionsCard(
                      lengthCm: product.lengthCm,
                      widthCm: product.widthCm,
                      heightCm: product.heightCm,
                      weightKg: product.weightKg,
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
      bottomNavigationBar: BottomActionBar(
        onEdit: widget.onEdit,
        onArchive: _onArchive,
        onRestore: _onRestore,
        isArchived: _status == SellerProductStatus.archived,
        isBusy: _isBusy,
      ),
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
  /// dedicated `colorChips` slot on [AttributesCard]. Per-piece dimension
  /// attributes are also excluded — they render in the grouped
  /// [SetDimensionsCard] instead of as flat rows.
  List<(String, String)> _attributeRows(SellerProduct p) {
    final defByKey = {for (final d in _schema) d.key: d};
    final rows = <(String, String)>[];

    // Stable order: schema-declared keys first (so the preview matches the
    // form's layout), then anything left over.
    final seen = <String>{};
    for (final def in _schema) {
      if (!p.attributes.containsKey(def.key)) continue;
      if (form_dims.DimensionsCard.isDimensionAttribute(def)) continue;
      final value = _renderValue(p.attributes[def.key], def);
      if (value.isEmpty) continue;
      rows.add((_resolveLabel(def.key, def), value));
      seen.add(def.key);
    }
    for (final entry in p.attributes.entries) {
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

  /// Groups the per-piece dimension attributes (recognised by the form's
  /// [form_dims.DimensionsCard.isDimensionAttribute]) by furniture piece, so a
  /// bedroom set renders as KARAVOT / SHKAF / TRYUMO blocks. Returns empty when
  /// the product has no dimension attributes (e.g. a single non-set product) —
  /// the typed width/height/depth columns drive the plain [DimensionsCard]
  /// then instead.
  List<SetDimensionGroup> _setDimensionGroups(SellerProduct p) {
    const locale = 'uz';
    final order = <String>[];
    final byPiece = <String, List<(String, String)>>{};
    for (final def in _schema) {
      if (!form_dims.DimensionsCard.isDimensionAttribute(def)) continue;
      if (!p.attributes.containsKey(def.key)) continue;
      final value = _renderValue(p.attributes[def.key], def);
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

  /// Maps each persisted colour slug to its visual chip (label + swatch).
  /// Unknown slugs are skipped so we never paint a fallback "?" swatch.
  List<AttributeColorChip> _colorChipsFor(List<String> slugs) {
    if (slugs.isEmpty) return const [];
    final palette = {for (final option in kProductColors) option.slug: option};
    return [
      for (final slug in slugs)
        if (palette[slug] != null)
          AttributeColorChip(
            label: palette[slug]!.label,
            swatch: palette[slug]!.swatch,
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

/// Seller-facing AR pipeline card under the price — closes the loop: it badges
/// the current `ar_status`, surfaces the rejection reason verbatim, and offers
/// the (re-)scan CTA. Seller tokens + terracotta, matching the add-product
/// surface. The CTA is live only when an action makes sense (never scanned,
/// rejected, or approved → re-record); blocked while in flight
/// (processing / pending_review).
class _ArScanCard extends StatelessWidget {
  const _ArScanCard({required this.product, required this.onScan});

  final SellerProduct product;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final state = _arState(product.arStatus);
    final canScan = state.canScan;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: canScan ? onScan : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.terracotta.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.view_in_ar,
                      color: AppColors.terracotta,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '3D skan (AR)',
                              style: TextStyle(
                                fontFamily: AppFonts.seller,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if (state.badge != null) ...[
                              const SizedBox(width: 8),
                              _ArBadge(label: state.badge!, color: state.color),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.subtitle,
                          style: const TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 12.5,
                            color: Colors.black54,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canScan)
                    const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),

              // Rejection feedback — the "why" so the seller can fix + re-record.
              if (product.arStatus == 'rejected' &&
                  (product.arRejectionReason?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.terracotta.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rad etish sababi',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.terracotta,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.arRejectionReason!.trim(),
                        style: const TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Qaytadan skan qilish'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontWeight: FontWeight.w700,
                      ),
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

/// Per-status presentation for the seller AR card.
class _ArCardState {
  const _ArCardState({
    required this.subtitle,
    required this.canScan,
    this.badge,
    this.color = AppColors.terracotta,
  });
  final String subtitle;
  final bool canScan;
  final String? badge;
  final Color color;
}

_ArCardState _arState(String arStatus) {
  switch (arStatus) {
    case 'processing':
      return const _ArCardState(
        subtitle: 'AI 3D model tayyorlamoqda…',
        canScan: false,
        badge: 'Ishlanmoqda',
        color: Color(0xFF8C5A12), // amber — matches ProductStatusChip pending
      );
    case 'pending_review':
      return const _ArCardState(
        subtitle: 'Admin tasdiqlashini kutmoqda.',
        canScan: false,
        badge: 'Tekshiruvda',
        color: Color(0xFF2563EB), // blue, awaiting QC
      );
    case 'approved':
      return const _ArCardState(
        subtitle: '3D model ilovada ko‘rinmoqda. Qayta skan qilish mumkin.',
        canScan: true,
        badge: 'Tasdiqlangan',
        color: Color(0xFF1F6B49), // green — matches ProductStatusChip approved
      );
    case 'rejected':
      return const _ArCardState(
        subtitle: 'Skan rad etildi — sababini ko‘ring va qaytadan oling.',
        canScan: true,
        badge: 'Rad etilgan',
        color: Color(0xFFC0392B), // red — matches ProductStatusChip rejected
      );
    default:
      return const _ArCardState(
        subtitle: 'Mahsulotni aylanib videoga oling — AI 3D model yasaydi.',
        canScan: true,
      );
  }
}

class _ArBadge extends StatelessWidget {
  const _ArBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
