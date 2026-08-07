import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../config/remote_config.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/product_set.dart';
import '../../../../shared/repositories/seller_product_repository.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/error_state.dart';
import '../data/seller_set_repository.dart';
import 'seller_set_editor_screen.dart';

/// Seller furniture-set (garnitur) management. Lists the seller's own sets with
/// a status chip + archive action, and a "+" to create a new one. Reached via a
/// Navigator.push from the products screen app-bar action — NOT a bottom tab.
///
/// Uzbek-only with seller tokens (`SellerColors.of(context)`, `AppFonts.seller`).
class SellerSetsScreen extends StatefulWidget {
  const SellerSetsScreen({
    super.key,
    required this.repo,
    required this.productRepo,
    required this.tariffRepo,
  });

  final WoodySellerSetRepository repo;
  final SellerProductRepository productRepo;
  final TariffRepository tariffRepo;

  @override
  State<SellerSetsScreen> createState() => _SellerSetsScreenState();
}

class _SellerSetsScreenState extends State<SellerSetsScreen> {
  late final _repo = widget.repo;

  List<ProductSet> _sets = const [];
  bool _loading = true;
  String? _error;

  /// Whether the seller's current plan may create sets. Defaults to true so the
  /// create button isn't hidden before the plan resolves (or when tariffs off).
  bool _allowsSets = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Sets are unrestricted when tariffs are disabled; otherwise the current
  /// plan's `allowsSets` decides. Any read error → allow (never hard-block on a
  /// transient failure).
  Future<bool> _resolveAllowsSets() async {
    if (!RemoteConfig.instance.tariffEnabled) return true;
    final snap = await widget.tariffRepo.currentSnapshot();
    return snap.valueOrNull?.plan.allowsSets ?? true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sets = await _repo.listMySets();
      final allowsSets = await _resolveAllowsSets();
      if (!mounted) return;
      setState(() {
        _sets = sets;
        _allowsSets = allowsSets;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? tr('seller.sets_list_load_failed');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = tr('seller.sets_list_load_failed');
        _loading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/seller-set-editor'),
        builder: (_) => SellerSetEditorScreen(
          setRepo: widget.repo,
          productRepo: widget.productRepo,
        ),
      ),
    );
    if (!mounted) return;
    if (created == true) _load();
  }

  Future<void> _confirmDelete(ProductSet set) async {
    final c = SellerColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr('seller.sets_archive_dialog_title'),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        content: Text(
          tr('seller.sets_archive_dialog_body', namedArgs: {'name': set.name}),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 14,
            height: 1.45,
            color: c.grey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              tr('common.cancel'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w600,
                color: c.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              tr('seller.product_archive_action'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w700,
                color: c.negative,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _delete(set.id);
  }

  Future<void> _delete(String id) async {
    try {
      await _repo.deleteSet(id);
      if (!mounted) return;
      _load();
    } on ApiError catch (e) {
      if (!mounted) return;
      _showError(e.message ?? tr('seller.sets_archive_failed'));
    } catch (_) {
      if (!mounted) return;
      _showError(tr('seller.sets_archive_failed'));
    }
  }

  void _showError(String message) {
    final c = SellerColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.negative,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: AppFonts.seller,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        iconTheme: IconThemeData(color: c.ink),
        title: Text(
          tr('seller.products_sets_tooltip'),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: _buildBody(c),
      // Create-set button is hidden when the current plan doesn't allow sets
      // (Free/Basic). Upgrading to Pro/Enterprise unlocks it.
      floatingActionButton: _allowsSets
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: AppColors.sellerPrimary,
              foregroundColor: Colors.white,
              elevation: 4,
              highlightElevation: 6,
              icon: const Icon(Iconsax.add, size: 20),
              label: Text(
                tr('seller.sets_add_button'),
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(SellerColors c) {
    if (_loading) {
      return const Center(child: BrandLoadingIndicator());
    }
    if (_error != null && _sets.isEmpty) {
      return ErrorState(message: _error, onRetry: _load);
    }
    return BrandRefreshIndicator(
      color: AppColors.sellerPrimary,
      onRefresh: _load,
      child: _sets.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _SetsZeroState(c: c),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              itemCount: _sets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SetTile(
                set: _sets[i],
                onDelete: () => _confirmDelete(_sets[i]),
              ),
            ),
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({required this.set, required this.onDelete});

  final ProductSet set;
  final VoidCallback onDelete;

  bool get _archived => set.status == 'archived';

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: _archived ? c.fillSoft : c.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: _archived ? c.fillSoft : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: _archived ? Border.all(color: c.outline) : null,
          boxShadow: _archived
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(url: set.coverImageUrl, muted: _archived),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _archived ? c.grey : c.ink,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        'seller.sets_item_count',
                        namedArgs: {'count': set.itemCount.toString()},
                      ),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.greyMid,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusChip(status: set.status),
                        if (!_archived) _DeleteButton(onPressed: onDelete),
                      ],
                    ),
                    if (set.status == 'rejected' &&
                        (set.rejectionReason?.trim().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 8),
                      _RejectionReason(reason: set.rejectionReason!.trim()),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.muted});

  final String? url;
  final bool muted;

  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final placeholder = Container(
      color: c.imageBg,
      alignment: Alignment.center,
      child: Icon(Iconsax.box, size: 22, color: c.greyMid),
    );
    Widget image = url == null || url!.isEmpty
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url!,
            memCacheWidth: 320,
            fit: BoxFit.cover,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    if (muted) {
      image = Opacity(
        opacity: 0.55,
        child: ColorFiltered(colorFilter: _greyscale, child: image),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 76, height: 76, child: image),
    );
  }
}

/// Status pill mirroring the backend's set lifecycle, Uzbek-labelled.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final (label, fg, bg) = switch (status) {
      'approved' => (
        tr('seller.sets_status_approved'),
        c.positive,
        c.positiveBg,
      ),
      'pending_review' => (
        tr('seller.sets_status_pending'),
        c.warning,
        c.warningBg,
      ),
      'rejected' => (
        tr('seller.sets_status_rejected'),
        c.negative,
        c.negativeBg,
      ),
      'archived' => (tr('seller.sets_status_archived'), c.grey, c.fillSoft),
      'draft' => (tr('seller.sets_status_draft'), c.grey, c.fillSoft),
      _ => (tr('seller.sets_status_pending'), c.warning, c.warningBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: c.negativeBg,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.archive_1, size: 13, color: c.negative),
              const SizedBox(width: 5),
              Text(
                tr('seller.product_archive_action'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.negative,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RejectionReason extends StatelessWidget {
  const _RejectionReason({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.negativeBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Iconsax.info_circle, size: 14, color: c.negative),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c.negative,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetsZeroState extends StatelessWidget {
  const _SetsZeroState({required this.c});

  final SellerColors c;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.sellerPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Iconsax.box,
                size: 44,
                color: AppColors.sellerPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('seller.sets_empty_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.ink,
                letterSpacing: -0.2,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('seller.sets_empty_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
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
