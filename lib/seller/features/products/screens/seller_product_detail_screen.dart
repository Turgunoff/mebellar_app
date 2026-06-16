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
import '../data/ar_scan_components.dart';
import 'ar_scan_camera_screen.dart';
import 'seller_ar_model_screen.dart';
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

  /// Entry point for the AR card's scan CTA. Resolves the product's scannable
  /// pieces from its own dimension data (the seller never re-types them), then:
  ///   * exactly one ready piece → straight into the camera,
  ///   * no usable dimensions    → route to the edit form to add them,
  ///   * two or more pieces      → ask which one to scan.
  Future<void> _startArScan(SellerProduct product) async {
    final components = resolveArScanComponents(
      schema: _schema,
      product: product,
    );

    if (components.length == 1 && components.single.isComplete) {
      await _launchArCamera(product.id, components.single);
      return;
    }
    if (components.where((c) => c.isComplete).isEmpty) {
      await _showNeedDimensionsDialog();
      return;
    }

    final picked = await _showComponentPicker(components);
    if (picked != null) await _launchArCamera(product.id, picked);
  }

  /// Opens the locked-down camera for [component], passing its real-world
  /// dimensions straight through. On a successful submit the model is queued
  /// for AI generation + admin QC, so we confirm and let the seller carry on
  /// (the model appears once approved).
  Future<void> _launchArCamera(
    String productId,
    ArScanComponent component,
  ) async {
    // Push on the ROOT navigator so the camera covers the seller shell's
    // bottom navigation bar — a scanner must be a fully immersive surface.
    final submitted = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => ArScanCameraScreen(
          productId: productId,
          heightCm: component.heightCm!,
          widthCm: component.widthCm!,
          lengthCm: component.lengthCm!,
        ),
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

  /// Bottom sheet asking which furniture piece to 3D-scan (a bedroom set has a
  /// bed + wardrobe + dresser). Pieces with incomplete dimensions are shown
  /// disabled with a hint — the backend needs all three, so an under-specified
  /// piece never gets through.
  Future<ArScanComponent?> _showComponentPicker(
    List<ArScanComponent> components,
  ) {
    final c = SellerColors.of(context);
    return showModalBottomSheet<ArScanComponent>(
      context: context,
      backgroundColor: c.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qaysi qismini 3D skaner qilasiz?',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tanlangan qism o‘lchamlari modelga avtomatik qo‘shiladi.',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  color: c.grey,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              for (final component in components) ...[
                _ComponentTile(
                  component: component,
                  onTap: component.isComplete
                      ? () => Navigator.of(sheetContext).pop(component)
                      : null,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Shown when the product has no usable dimensions to feed the scan. The 3D
  /// pipeline needs real cm to size the model, so we route the seller to the
  /// edit form rather than firing a scan the backend would reject.
  Future<void> _showNeedDimensionsDialog() async {
    final c = SellerColors.of(context);
    final goEdit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'O‘lchamlar kerak',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        content: Text(
          '3D model aniq bo‘lishi uchun mahsulot o‘lchamlari (eni, bo‘yi, '
          'chuqurligi) kerak. Iltimos, avval ularni to‘ldiring.',
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
              'Yopish',
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
              backgroundColor: AppColors.sellerPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Tahrirlash',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (goEdit == true) widget.onEdit?.call();
  }

  /// Opens the seller's own QC-approved 3D model full-screen.
  void _openModelViewer(SellerProduct product) {
    final url = product.arModelUrl;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerArModelScreen(
          modelUrl: url,
          productName: product.name.get('uz'),
          widthCm: product.widthCm,
          heightCm: product.heightCm,
          depthCm: product.lengthCm,
        ),
      ),
    );
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
                    onScan: () => _startArScan(product),
                    onViewModel: () => _openModelViewer(product),
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
/// the current `ar_status`, surfaces the terminal-failure reason verbatim
/// (a Meshy `failed` error or a human `rejected` reason), and adapts its CTA
/// to the state. Seller tokens + terracotta, matching the add-product surface.
///
/// Per state:
///   * none (idle)     → a pulsing CTA inviting the first scan (whole card taps),
///   * processing       → a spinner + "yasamoqda", tap disabled,
///   * pending_review   → a clock + "Moderator tekshiruvida", tap disabled,
///   * approved         → a "3D modelni ko‘rish" button + a quiet re-scan,
///   * failed / rejected→ the reason in an error note + a "Qayta urinish" button.
class _ArScanCard extends StatelessWidget {
  const _ArScanCard({
    required this.product,
    required this.onScan,
    required this.onViewModel,
  });

  final SellerProduct product;
  final VoidCallback onScan;
  final VoidCallback onViewModel;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final state = _arState(product.arStatus);
    final fb = _feedback(product);
    final isApproved = product.arStatus == 'approved';
    // The whole card only taps in the idle state; every other actionable state
    // owns an explicit button, so there's never a hidden second affordance.
    final cardTappable = state.canScan && fb == null && !isApproved;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: cardTappable ? onScan : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ArIconBadge(status: product.arStatus, color: state.color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '3D skan (AR)',
                              style: TextStyle(
                                fontFamily: AppFonts.seller,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: c.ink,
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
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 12.5,
                            color: c.grey,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cardTappable)
                    Icon(Icons.chevron_right, color: c.greyFaint),
                ],
              ),

              // Approved → primary "view the model", with a quiet re-scan below.
              if (isApproved) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onViewModel,
                    icon: const Icon(Icons.view_in_ar, size: 20),
                    label: const Text('3D modelni ko‘rish'),
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
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: onScan,
                    icon: Icon(Icons.refresh, size: 17, color: c.grey),
                    label: Text(
                      'Qayta skanlash',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontWeight: FontWeight.w600,
                        color: c.grey,
                      ),
                    ),
                  ),
                ),
              ],

              // Feedback + retry — the "why" so the seller can fix + re-record.
              // `failed` is a machine/Meshy failure (error-styled, sellerNegative);
              // `rejected` is a human QC rejection (terracotta). Both offer retry,
              // which the backend resets to `processing` and clears the old reason.
              if (fb != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: fb.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fb.title,
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: fb.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fb.reason,
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          color: c.ink,
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
                    label: const Text('Qayta urinish'),
                    style: FilledButton.styleFrom(
                      backgroundColor: fb.accent,
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

  /// The feedback note + retry CTA for a terminal failure state, or null
  /// when the current `ar_status` carries no seller-actionable feedback.
  _ArFeedback? _feedback(SellerProduct p) {
    switch (p.arStatus) {
      case 'failed':
        return _ArFeedback(
          title: 'Skan xatosi',
          // arErrorReason is meaningful only while failed; keep a clear
          // Uzbek fallback so the note is never empty.
          reason: p.arErrorReason?.trim().isNotEmpty == true
              ? p.arErrorReason!.trim()
              : 'Skan amalga oshmadi',
          accent: AppColors.sellerNegative,
        );
      case 'rejected':
        if (p.arRejectionReason?.trim().isNotEmpty ?? false) {
          return _ArFeedback(
            title: 'Rad etish sababi',
            reason: p.arRejectionReason!.trim(),
            accent: AppColors.terracotta,
          );
        }
        return null;
      default:
        return null;
    }
  }
}

/// A terminal-state feedback note (failed / rejected) shown in [_ArScanCard].
class _ArFeedback {
  const _ArFeedback({
    required this.title,
    required this.reason,
    required this.accent,
  });
  final String title;
  final String reason;
  final Color accent;
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
        subtitle: 'AI 3D model yasamoqda (2-5 daqiqa)…',
        canScan: false,
        badge: 'Ishlanmoqda',
        color: Color(0xFF8C5A12), // amber — matches ProductStatusChip pending
      );
    case 'pending_review':
      return const _ArCardState(
        subtitle: 'Moderator tekshiruvida',
        canScan: false,
        badge: 'Tekshiruvda',
        color: Color(0xFF2563EB), // blue, awaiting QC
      );
    case 'approved':
      return const _ArCardState(
        subtitle: '3D model tayyor — ko‘rib chiqing yoki qayta skanlang.',
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
    case 'failed':
      // Pipeline/Meshy failure (machine), distinct from a human QC rejection.
      return _ArCardState(
        subtitle: 'Skan amalga oshmadi — qaytadan urinib ko‘ring.',
        canScan: true,
        badge: 'Xatolik',
        color: AppColors.sellerNegative,
      );
    default:
      return const _ArCardState(
        subtitle: 'Mahsulotni 3 ta burchakdan rasmga oling — AI 3D model yasaydi.',
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

/// One selectable furniture piece in the component picker. Disabled (no
/// [onTap]) when its dimensions are incomplete, with a hint instead of dims.
class _ComponentTile extends StatelessWidget {
  const _ComponentTile({required this.component, required this.onTap});

  final ArScanComponent component;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final enabled = onTap != null;
    return Material(
      color: enabled ? c.fillFaint : c.fillFaint.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.view_in_ar,
                size: 22,
                color: enabled ? AppColors.terracotta : c.greyFaint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.label,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: enabled ? c.ink : c.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled
                          ? component.summary
                          : 'O‘lchamlar to‘liq emas',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12.5,
                        color: enabled ? c.grey : c.greyFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled) Icon(Icons.chevron_right, color: c.greyFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 44×44 status glyph for the AR card. Idle pulses to invite the first
/// scan; processing shows a spinner; the rest show a fitting static icon —
/// all tinted to the state colour.
class _ArIconBadge extends StatelessWidget {
  const _ArIconBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'processing':
        return _ArIconBox(
          color: color,
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        );
      case 'pending_review':
        return _ArIconBox(color: color, child: Icon(Icons.schedule, color: color));
      case 'approved':
        return _ArIconBox(
          color: color,
          child: Icon(Icons.view_in_ar, color: color),
        );
      case 'rejected':
      case 'failed':
        return _ArIconBox(
          color: color,
          child: Icon(Icons.error_outline, color: color),
        );
      default:
        return _PulsingArIcon(color: color);
    }
  }
}

/// The rounded tinted square behind every AR card glyph.
class _ArIconBox extends StatelessWidget {
  const _ArIconBox({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

/// Idle-state glyph with a continuous, subtle pulse — an expanding/fading ring
/// behind the icon plus a gentle breath on the box — to draw the seller's eye
/// to the never-used scan CTA.
class _PulsingArIcon extends StatefulWidget {
  const _PulsingArIcon({required this.color});

  final Color color;

  @override
  State<_PulsingArIcon> createState() => _PulsingArIconState();
}

class _PulsingArIconState extends State<_PulsingArIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_controller.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            // Halo that expands and fades out on each cycle.
            Transform.scale(
              scale: 1 + t * 0.7,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: (1 - t) * 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            Transform.scale(scale: 1 + t * 0.06, child: child),
          ],
        );
      },
      child: _ArIconBox(
        color: widget.color,
        child: Icon(Icons.view_in_ar, color: widget.color),
      ),
    );
  }
}
