import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/constants/product_colors.dart';
import '../../../../shared/models/ar_part.dart';
import '../../../../shared/models/attribute_definition.dart';
import '../../../../shared/models/seller_product.dart';
import '../bloc/seller_products_bloc.dart';
import '../data/attributes_repository.dart';
import '../data/ar_scan_components.dart';
import '../data/ar_scan_repository.dart';
import '../data/ar_token_repository.dart';
import '../widgets/ar_not_approved_card.dart';
import '../widgets/ar_scan_onboarding_sheet.dart';
import 'ar_scan_camera_screen.dart';
import 'seller_ar_model_screen.dart';
import '../../wallet/screens/ar_tokens_screen.dart';
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

  // Per-part AR models, fetched on open and after every scan / visibility
  // change. Each scannable component (Krovat, Shkaf, … or a single-piece
  // product) maps to one part with its own model, customer visibility, and
  // free-scan state. Null model = not yet scanned (first scan free).
  List<ArPart> _arParts = const [];
  bool _arPartsLoaded = false;

  // The seller's AR-token balance + the purchasable catalog, loaded once on
  // open. Null while loading; drives the balance label + the morph-to-buy CTA.
  ArTokenBalance? _arBalance;

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
    _loadArBalance();
    _loadArParts();
  }

  /// Loads the product's existing AR parts. Only approved products can scan, so
  /// a non-published product skips the call (the card shows the locked state).
  Future<void> _loadArParts() async {
    if (!widget.product.status.isPublished) {
      if (mounted) setState(() => _arPartsLoaded = true);
      return;
    }
    try {
      final parts = await sl<ArScanRepository>().fetchArParts(widget.product.id);
      if (mounted) {
        setState(() {
          _arParts = parts;
          _arPartsLoaded = true;
        });
      }
    } catch (e, st) {
      // Non-fatal: the card falls back to the derived components as not-yet-
      // scanned. The scan endpoint still enforces ownership + limits server-side.
      talker.handle(e, st, '[seller-product-detail] ar parts load failed');
      if (mounted) setState(() => _arPartsLoaded = true);
    }
  }

  Future<void> _loadArBalance() async {
    try {
      final balance = await sl<ArTokenRepository>().balance();
      if (mounted) setState(() => _arBalance = balance);
    } catch (e, st) {
      // Non-fatal: the card falls back to hiding the balance / buy CTA. The
      // scan endpoint still enforces the limit server-side.
      talker.handle(e, st, '[seller-product-detail] ar balance load failed');
    }
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
      title: tr('seller.product_archive_confirm_title'),
      message: tr('seller.product_archive_confirm_body'),
      confirmLabel: tr('seller.product_archive_action'),
      destructive: false,
    );
    if (confirmed != true) return;
    await _runMutation(
      action: () => context.read<SellerProductsBloc>().add(
        SellerProductArchived(widget.product.id),
      ),
      nextStatus: SellerProductStatus.archived,
      successMessage: tr('seller.product_archived_success'),
    );
  }

  Future<void> _onRestore() async {
    await _runMutation(
      action: () => context.read<SellerProductsBloc>().add(
        SellerProductRestored(widget.product.id),
      ),
      nextStatus: SellerProductStatus.pendingReview,
      successMessage: tr('seller.product_restored_success'),
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
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: Text(
              tr('common.cancel'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w600,
                color: c.grey,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
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

  /// Builds the AR card's rows: one per scannable component, merged with its
  /// existing part (model state, visibility, free-scan spent) by `part_key`.
  ///
  /// A part whose key matches a derived component attaches to it directly. A
  /// part with no matching component is an "orphan" — most importantly the
  /// pre-per-part legacy model, which migration 0059 backfilled under the key
  /// `single`: that key never matches a *set's* derived pieces (bed/wardrobe/
  /// dresser), so the model would otherwise strand as a duplicate row while every
  /// named piece wrongly offered "Yaratish". We adopt such a model-bearing orphan
  /// onto the first piece that has no model yet, so the seller keeps their
  /// existing model (view / hide / rescan) and is never asked to — or charged to —
  /// regenerate it. An orphan is only surfaced standalone when no piece is free,
  /// so a model is never hidden.
  List<_ArPartRow> _buildArRows(SellerProduct product) {
    final components = resolveArScanComponents(schema: _schema, product: product);
    final rows = <String, _ArPartRow>{
      for (final comp in components)
        comp.partKey: _ArPartRow(component: comp, part: null),
    };

    final orphans = <ArPart>[];
    for (final part in _arParts) {
      if (rows.containsKey(part.partKey)) {
        rows[part.partKey] = _ArPartRow(
          component: rows[part.partKey]!.component,
          part: part,
        );
      } else {
        orphans.add(part);
      }
    }

    for (final orphan in orphans) {
      final adoptable =
          orphan.hasModel || orphan.isProcessing || orphan.isFailed;
      String? freeKey;
      if (adoptable) {
        for (final comp in components) {
          if (rows[comp.partKey]?.part == null) {
            freeKey = comp.partKey;
            break;
          }
        }
      }
      if (freeKey != null) {
        rows[freeKey] = _ArPartRow(
          component: rows[freeKey]!.component,
          part: orphan,
        );
      } else {
        rows[orphan.partKey] = _ArPartRow(part: orphan);
      }
    }

    return rows.values.toList(growable: false);
  }

  /// Scans (or rescans) a single part. The part's FIRST generation is free; a
  /// rescan costs 1 AR token, so we confirm before spending one. Incomplete
  /// dimensions route to the edit form instead of firing a scan the backend
  /// would reject.
  Future<void> _scanPart(_ArPartRow row) async {
    final component = row.component;
    if (component == null || !component.isComplete) {
      await _showNeedDimensionsDialog();
      return;
    }
    // A spent free scan means the next generation is token-paid. Evaluate the
    // balance before opening the modal: a known-empty wallet must NOT reach the
    // camera — it routes the seller to top up instead of firing a doomed scan.
    if (row.part?.freeScanUsed ?? false) {
      final tokens = _arBalance?.arCredits;
      if (tokens != null && tokens <= 0) {
        await _promptBuyTokens();
        return;
      }
      final ok = await _confirmRescan();
      if (ok != true || !mounted) return;
    }
    await _launchArCamera(component);
  }

  /// Opens the AR-token top-up screen and refreshes the balance on return, so a
  /// successful purchase immediately unlocks the rescan flow + updates the card
  /// banner. Shared by the header balance banner and the out-of-tokens dialog.
  Future<void> _openArTokens() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/ar-tokens'),
        builder: (_) => const ArTokensScreen(),
      ),
    );
    if (mounted) await _loadArBalance();
  }

  /// Opens the locked-down camera for [component], passing its part identity +
  /// real-world dimensions. On a successful submit the model is queued for
  /// generation, so we refresh the parts (the row flips to "processing").
  Future<void> _launchArCamera(ArScanComponent component) async {
    // Resolve the ROOT navigator up-front, BEFORE the onboarding sheet opens an
    // async gap. The camera must cover the seller shell's bottom nav, so it
    // rides the root navigator — but reaching for `Navigator.of(context,
    // rootNavigator: true)` *after* the await (against a tree the sheet
    // dismissal has been mutating) is what let the close bubble into the shell
    // and tear down the product-detail route underneath ("over-pop"). Capture
    // it once, here, and reuse the handle for the push.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    // Surface the 3-photo "gold rules" (clean background / good lighting / three
    // distinct angles) before the immersive camera opens — they materially
    // improve the 3D result. The sheet now mounts on this SAME root navigator
    // (useRootNavigator: true), so the whole confirm → rules → camera sequence
    // lives on one stack: the sheet pops cleanly first, THEN we push the camera.
    // Abort the scan if the seller dismisses it.
    final proceed = await showArScanOnboardingSheet(context);
    if (!proceed || !mounted) return;
    // The sheet has fully popped (the await above completed) — only now push the
    // camera, onto the captured root navigator. Closing the camera then pops
    // exactly one route, landing back on Product Details without unmounting it.
    final submitted = await rootNavigator.push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/ar-scan-camera'),
        fullscreenDialog: true,
        builder: (_) => ArScanCameraScreen(
          productId: widget.product.id,
          partKey: component.partKey,
          label: component.label,
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
          SnackBar(
            content: Text(
              tr('seller.ar_scan_queued_snack'),
            ),
          ),
        );
      // Re-pull the live part state (now processing) + the balance (a rescan
      // may have spent a token).
      await _loadArParts();
      await _loadArBalance();
    }
  }

  /// Confirms a token-charged rescan before spending one. Returns true to go on.
  /// Only reached when the seller has ≥1 token (the empty case is intercepted in
  /// [_scanPart] → [_promptBuyTokens]), so the primary CTA truly proceeds.
  Future<bool?> _confirmRescan() {
    final c = SellerColors.of(context);
    return showDialog<bool>(
      context: context,
      routeSettings: const RouteSettings(name: '/ar-rescan-confirm'),
      builder: (dialogContext) => _PremiumActionDialog(
        icon: Icons.autorenew_rounded,
        iconColor: c.onPrimarySoft,
        iconBg: c.primarySoft,
        title: tr('product.ar_rescan_confirm_title'),
        message: tr('product.ar_rescan_confirm_message'),
        primaryLabel: tr('product.ar_rescan_confirm_yes'),
        primaryColor: c.primary,
        cancelLabel: tr('product.ar_rescan_confirm_cancel'),
        onPrimary: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
        onCancel: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
      ),
    );
  }

  /// Shown when a token-charged rescan is attempted with an empty wallet. The
  /// primary CTA routes to the top-up screen — the camera is NEVER opened here.
  Future<void> _promptBuyTokens() async {
    final c = SellerColors.of(context);
    final goTopUp = await showDialog<bool>(
      context: context,
      routeSettings: const RouteSettings(name: '/ar-no-tokens'),
      builder: (dialogContext) => _PremiumActionDialog(
        icon: Icons.bolt_rounded,
        iconColor: c.gold,
        iconBg: c.goldBg,
        title: tr('product.ar_no_tokens_title'),
        message: tr('product.ar_no_tokens_message'),
        primaryLabel: tr('product.ar_no_tokens_buy'),
        primaryColor: c.primary,
        cancelLabel: tr('product.ar_rescan_confirm_cancel'),
        onPrimary: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
        onCancel: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
      ),
    );
    if (goTopUp == true && mounted) await _openArTokens();
  }

  /// Optimistically flips a part's customer visibility (the eye icon) and PATCHes
  /// it. On failure, reverts and warns — the toggle should feel instant.
  Future<void> _toggleVisibility(ArPart part) async {
    final next = !part.isArVisible;
    setState(() {
      _arParts = [
        for (final p in _arParts)
          if (p.id == part.id) p.copyWith(isArVisible: next) else p,
      ];
    });
    try {
      await sl<ArScanRepository>().setPartVisibility(
        productId: widget.product.id,
        partId: part.id,
        isVisible: next,
      );
    } catch (e, st) {
      talker.handle(e, st, '[seller-product-detail] ar visibility toggle failed');
      if (!mounted) return;
      setState(() {
        _arParts = [
          for (final p in _arParts)
            if (p.id == part.id) p.copyWith(isArVisible: part.isArVisible) else p,
        ];
      });
      _showSnack(tr('seller.ar_visibility_toggle_failed'), isError: true);
    }
  }

  /// Opens a single part's approved 3D model full-screen for the seller.
  void _openPartViewer(ArPart part) {
    final url = part.arModelUrl;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/seller-ar-model'),
        builder: (_) => SellerArModelScreen(
          modelUrl: url,
          usdzUrl: part.usdzUrl,
          posterUrl: widget.product.heroImage,
          productName: part.label,
          widthCm: part.widthCm ?? widget.product.widthCm,
          heightCm: part.heightCm ?? widget.product.heightCm,
          depthCm: part.depthCm ?? widget.product.lengthCm,
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
      routeSettings: const RouteSettings(name: '/ar-need-dimensions'),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          tr('seller.ar_need_dimensions_title'),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        content: Text(
          tr('seller.ar_need_dimensions_body'),
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
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: Text(
              tr('common.close'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w600,
                color: c.grey,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sellerPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              tr('seller.product_edit_action'),
              style: const TextStyle(
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
                    rows: _buildArRows(product),
                    partsLoaded: _arPartsLoaded,
                    arCredits: _arBalance?.arCredits,
                    onScan: _scanPart,
                    onView: _openPartViewer,
                    onToggleVisibility: _toggleVisibility,
                    onTopUp: _openArTokens,
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
                      maxDeliveryFee: product.maxDeliveryFee,
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
      final piece = form_dims.DimensionsCard.pieceLabel(def, locale);
      final measure = form_dims.DimensionsCard.measureLabel(def, locale);
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
/// to the state. Brand actions are seller indigo; the AR-token currency is gold.
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
    required this.rows,
    required this.partsLoaded,
    required this.arCredits,
    required this.onScan,
    required this.onView,
    required this.onToggleVisibility,
    required this.onTopUp,
  });

  final SellerProduct product;

  /// One row per scannable component, merged with its existing part state.
  final List<_ArPartRow> rows;

  /// False until the parts fetch resolves — drives the in-card loading copy.
  final bool partsLoaded;

  /// The seller's AR-token balance; null while still loading. Display-only here:
  /// the badge shows it, but topping up moved to the profile's AR-tokens screen.
  final int? arCredits;

  final ValueChanged<_ArPartRow> onScan;
  final ValueChanged<ArPart> onView;
  final ValueChanged<ArPart> onToggleVisibility;

  /// Opens the AR-token top-up screen (header balance banner taps through here).
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    // AR generation is gated to moderation-approved products (a paid Meshy
    // task). A draft/pending/rejected/archived product shows the locked card.
    if (!product.status.isPublished) {
      return const ArNotApprovedCard();
    }

    final c = SellerColors.of(context);
    final overall = _overallStatus();

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: glyph + title on the left, the info action pinned right.
            // The description moved OUT of this row (see below) so it no longer
            // competes with a trailing chip and reads at full width.
            Row(
              children: [
                _ArIconBadge(status: overall, color: _arStatusColor(overall, c)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    tr('seller.ar_scan_card_title'),
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: c.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showArScanInfoSheet(context),
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: tr('seller.info_tooltip'),
                  icon: Icon(Icons.info_outline_rounded, color: c.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Full-width description — breathes now that nothing crowds it.
            Text(
              tr('seller.ar_scan_card_description'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                color: c.grey,
                height: 1.45,
              ),
            ),
            if (arCredits != null) ...[
              const SizedBox(height: 12),
              _ArTokenBanner(tokens: arCredits!, onTopUp: onTopUp),
            ],
            const SizedBox(height: 4),
            _body(c),
          ],
        ),
      ),
    );
  }

  Widget _body(SellerColors c) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          partsLoaded
              ? tr('seller.ar_scan_no_components')
              : tr('common.loading_2'),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13,
            color: c.grey,
            height: 1.35,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: c.divider),
          _ArPartTile(
            row: rows[i],
            onScan: () => onScan(rows[i]),
            onView: onView,
            onToggleVisibility: onToggleVisibility,
          ),
        ],
      ],
    );
  }

  /// The header glyph reflects the most "active" part: generating > ready >
  /// error > idle.
  String _overallStatus() {
    var hasApproved = false;
    var hasFailed = false;
    for (final r in rows) {
      final s = r.part?.arStatus;
      if (s == 'processing') return 'processing';
      if (s == 'approved') hasApproved = true;
      if (s == 'failed') hasFailed = true;
    }
    if (hasApproved) return 'approved';
    if (hasFailed) return 'failed';
    return 'none';
  }
}

/// The status tint shared by the AR card glyph + the per-part rows.
Color _arStatusColor(String status, SellerColors c) {
  switch (status) {
    case 'processing':
      return c.warning;
    case 'approved':
      return c.positive;
    case 'failed':
      return c.negative;
    default:
      return AppColors.sellerPrimary;
  }
}

/// One AR card row: a scannable component merged with its existing part state.
/// Either may be null (a not-yet-scanned component has no part; a part whose
/// component vanished from the schema has no component) but never both.
class _ArPartRow {
  const _ArPartRow({this.component, this.part});

  final ArScanComponent? component;
  final ArPart? part;

  String get label =>
      component?.label ?? part?.label ?? tr('seller.ar_part_default_label');
  bool get hasModel => part?.hasModel ?? false;
  bool get isProcessing => part?.isProcessing ?? false;
  bool get isFailed => part?.isFailed ?? false;
  bool get dimsReady => component?.isComplete ?? false;
}

/// A slim per-part row: the part name + a contextual trailing action set —
/// "Yaratish" when never scanned, a spinner while generating, or the
/// visibility / view / rescan icons once a model exists.
class _ArPartTile extends StatelessWidget {
  const _ArPartTile({
    required this.row,
    required this.onScan,
    required this.onView,
    required this.onToggleVisibility,
  });

  final _ArPartRow row;
  final VoidCallback onScan;
  final ValueChanged<ArPart> onView;
  final ValueChanged<ArPart> onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    color: row.isFailed ? c.negative : c.grey,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _trailing(c),
        ],
      ),
    );
  }

  String _subtitle() {
    final part = row.part;
    if (row.isProcessing) return tr('seller.ar_part_processing');
    if (row.hasModel) {
      return (part?.isArVisible ?? true)
          ? tr('seller.ar_part_ready_visible')
          : tr('seller.ar_part_ready_hidden');
    }
    if (row.isFailed) {
      final reason = part?.arErrorReason?.trim();
      return (reason != null && reason.isNotEmpty)
          ? reason
          : tr('seller.ar_part_scan_failed');
    }
    if (!row.dimsReady) return tr('seller.ar_part_dims_incomplete');
    return tr('seller.ar_part_ready_to_scan');
  }

  Widget _trailing(SellerColors c) {
    if (row.isProcessing) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(c.warning),
        ),
      );
    }
    final part = row.part;
    if (row.hasModel && part != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconAction(
            icon: part.isArVisible ? Icons.visibility : Icons.visibility_off,
            color: part.isArVisible ? c.primary : c.grey,
            onTap: () => onToggleVisibility(part),
          ),
          _IconAction(
            icon: Icons.view_in_ar_rounded,
            color: c.primary,
            onTap: () => onView(part),
          ),
          // Rescan costs a token — the bolt badge signals that.
          _RescanAction(badgeColor: c.gold, color: c.grey, onTap: onScan),
        ],
      );
    }
    // Never scanned or failed → a scan / retry pill.
    return _ScanPill(
      label: row.isFailed ? tr('seller.ar_part_retry') : tr('seller.ar_part_create'),
      enabled: row.dimsReady,
      onTap: onScan,
    );
  }
}

/// A compact tappable icon button used in a part row's trailing actions.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      icon: Icon(icon, color: color),
    );
  }
}

/// The rescan action — a refresh glyph with a tiny token/bolt badge, signalling
/// that a regenerate costs an AR token.
class _RescanAction extends StatelessWidget {
  const _RescanAction({
    required this.badgeColor,
    required this.color,
    required this.onTap,
  });

  final Color badgeColor;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.refresh_rounded, color: color),
          Positioned(
            right: -3,
            top: -3,
            child: Icon(Icons.bolt_rounded, size: 12, color: badgeColor),
          ),
        ],
      ),
    );
  }
}

/// A compact filled pill for the "scan / retry" action on a not-yet-modelled
/// part. Greyed when the part's dimensions are incomplete (a tap then routes to
/// the "add dimensions" dialog rather than firing a doomed scan).
class _ScanPill extends StatelessWidget {
  const _ScanPill({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: enabled ? c.primary : c.fillFaint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.view_in_ar_rounded,
                size: 16,
                color: enabled ? Colors.white : c.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : c.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width balance strip under the AR card header: the seller's AR-token
/// count plus a tap-through to top up. Replaces the old cramped header chip so
/// the description owns the full card width. Tints to a warning wash when the
/// wallet is empty, nudging a top-up before the next (token-charged) rescan.
class _ArTokenBanner extends StatelessWidget {
  const _ArTokenBanner({required this.tokens, required this.onTopUp});

  final int tokens;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final depleted = tokens <= 0;
    final fg = depleted ? c.warning : c.gold;
    final bg = depleted ? c.warningBg : c.goldBg;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTopUp,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('seller.ar_tokens_balance', args: [tokens]),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              Text(
                tr('seller.ar_tokens_top_up'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// A premium centred dialog used for the AR rescan flow: a soft icon disc, a
/// bold title, a readable body, a fully-rounded primary CTA, and a subtle text
/// cancel. Parameterised so the same shell serves both the "confirm rescan" and
/// the "out of tokens → buy" states.
class _PremiumActionDialog extends StatelessWidget {
  const _PremiumActionDialog({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryColor,
    required this.cancelLabel,
    required this.onPrimary,
    required this.onCancel,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String message;
  final String primaryLabel;
  final Color primaryColor;
  final String cancelLabel;
  final VoidCallback onPrimary;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.grey,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: onCancel,
                child: Text(
                  cancelLabel,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the AR-info bottom sheet: a tinted icon disc + a title/body pair.
class _ArInfoBullet extends StatelessWidget {
  const _ArInfoBullet({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: c.onPrimarySoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: c.grey,
                    height: 1.4,
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

/// Explains the 3D/AR scan feature in a calm bottom sheet — opened from the
/// card's header info icon. Pure copy + a close CTA; no side effects.
Future<void> _showArScanInfoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    routeSettings: const RouteSettings(name: '/ar-scan-info'),
    backgroundColor: SellerColors.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final c = SellerColors.of(sheetContext);
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.view_in_ar_rounded,
                      color: c.onPrimarySoft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('seller.ar_info_title'),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                tr('seller.ar_info_intro'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: c.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              _ArInfoBullet(
                icon: Icons.dashboard_customize_rounded,
                title: tr('seller.ar_info_bullet_per_part_title'),
                body: tr('seller.ar_info_bullet_per_part_body'),
              ),
              _ArInfoBullet(
                icon: Icons.bolt_rounded,
                title: tr('seller.ar_info_bullet_free_title'),
                body: tr('seller.ar_info_bullet_free_body'),
              ),
              _ArInfoBullet(
                icon: Icons.photo_camera_rounded,
                title: tr('seller.ar_info_bullet_quality_title'),
                body: tr('seller.ar_info_bullet_quality_body'),
              ),
              _ArInfoBullet(
                icon: Icons.verified_rounded,
                title: tr('seller.ar_info_bullet_visible_title'),
                body: tr('seller.ar_info_bullet_visible_body'),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    tr('common.got_it'),
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
        return _ArIconBox(
          color: color,
          child: Icon(Icons.schedule, color: color),
        );
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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
