import 'package:flutter/material.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../shared/models/ar_part.dart';
import '../../../shared/models/attribute_definition.dart';
import '../../../shared/models/seller_product.dart';
import '../wallet/screens/ar_tokens_screen.dart';
import 'data/ar_scan_components.dart';
import 'data/ar_scan_repository.dart';
import 'data/ar_token_repository.dart';
import '../../../shared/widgets/ar/product_3d_preview_view.dart';
import 'widgets/ar_not_approved_card.dart';

/// The seller's "3D model (AR)" section on the product-detail screen — the
/// admin-reviewed REQUEST workflow.
///
/// The seller no longer scans photos or triggers Meshy directly. Per part
/// (a garnitur has one per piece) the section is a small state machine driven
/// by the part's `ar_status`:
///
///  * `none`      → quota + "So'rov yuborish" (request a 3D model);
///  * `pending`   → "Adminga so'rov yuborildi. Tekshirilmoqda…" (button off);
///  * `processing`→ "Admin tasdiqladi. Model yasalmoqda…" (spinner);
///  * `approved`  → "AR rejimida ko'rish" (+ the customer-visibility eye);
///  * `rejected`  → the reason + "Qaytadan so'rov yuborish".
///
/// The first request per part is free; a re-request (after a rejection) locks
/// 1 AR token, refunded if the admin rejects it. The token balance is shown as
/// the available quota with a top-up shortcut.
class SellerArSection extends StatefulWidget {
  const SellerArSection({
    super.key,
    required this.product,
    required this.schema,
    this.onEdit,
  });

  final SellerProduct product;
  final List<AttributeDefinition> schema;

  /// Routes the seller to the edit form when a part lacks the dimensions the
  /// model needs.
  final VoidCallback? onEdit;

  @override
  State<SellerArSection> createState() => _SellerArSectionState();
}

class _SellerArSectionState extends State<SellerArSection> {
  List<ArPart> _parts = const [];
  bool _partsLoaded = false;
  ArTokenBalance? _balance;

  /// Part keys with an in-flight request, for a per-tile button spinner.
  final Set<String> _busy = <String>{};

  bool get _published => widget.product.status.isPublished;

  @override
  void initState() {
    super.initState();
    if (_published) {
      _loadParts();
      _loadBalance();
    } else {
      _partsLoaded = true;
    }
  }

  Future<void> _loadParts() async {
    try {
      final parts = await sl<ArScanRepository>().fetchArParts(
        widget.product.id,
      );
      if (mounted) {
        setState(() {
          _parts = parts;
          _partsLoaded = true;
        });
      }
    } catch (e, st) {
      appLog.handle(e, st, '[ar-section] parts load failed');
      if (mounted) setState(() => _partsLoaded = true);
    }
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await sl<ArTokenRepository>().balance();
      if (mounted) setState(() => _balance = balance);
    } catch (e, st) {
      appLog.handle(e, st, '[ar-section] balance load failed');
    }
  }

  /// One row per scannable component, merged with its existing part by
  /// `part_key`. A model-bearing "orphan" part (e.g. a legacy `single` model on
  /// a set) is adopted onto the first piece with no part yet, so an existing
  /// model is never stranded or duplicated.
  List<_ArRow> _rows() {
    final components = resolveArScanComponents(
      schema: widget.schema,
      product: widget.product,
    );
    final rows = <String, _ArRow>{
      for (final c in components) c.partKey: _ArRow(component: c, part: null),
    };

    final orphans = <ArPart>[];
    for (final part in _parts) {
      if (rows.containsKey(part.partKey)) {
        rows[part.partKey] = _ArRow(
          component: rows[part.partKey]!.component,
          part: part,
        );
      } else {
        orphans.add(part);
      }
    }
    for (final orphan in orphans) {
      final adoptable =
          orphan.hasModel ||
          orphan.isProcessing ||
          orphan.isPending ||
          orphan.isFailed ||
          orphan.isRejected;
      String? freeKey;
      if (adoptable) {
        for (final c in components) {
          if (rows[c.partKey]?.part == null) {
            freeKey = c.partKey;
            break;
          }
        }
      }
      if (freeKey != null) {
        rows[freeKey] = _ArRow(
          component: rows[freeKey]!.component,
          part: orphan,
        );
      } else {
        rows[orphan.partKey] = _ArRow(part: orphan);
      }
    }
    return rows.values.toList(growable: false);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Requests (or re-requests) a 3D model for one part. The first request is
  /// free while the shop's bonus quota has headroom; after that (or on a
  /// re-request) 1 token is locked — confirm + balance-check first.
  /// Incomplete dimensions route to the edit form instead of a doomed request.
  Future<void> _request(_ArRow row) async {
    final component = row.component;
    if (component == null || !component.isComplete) {
      await _showNeedDimensionsDialog();
      return;
    }
    final needsToken =
        _balance?.requestNeedsToken(
          partFreeScanUsed: row.part?.freeScanUsed ?? false,
        ) ??
        false;
    if (needsToken) {
      final tokens = _balance?.arCredits ?? 0;
      if (tokens <= 0) {
        await _promptBuyTokens();
        return;
      }
      final ok = await _confirmReRequest();
      if (ok != true || !mounted) return;
    }

    setState(() => _busy.add(component.partKey));
    try {
      final parts = await sl<ArScanRepository>().requestArModel(
        productId: widget.product.id,
        partKey: component.partKey,
        label: component.label,
        heightCm: component.heightCm!,
        widthCm: component.widthCm!,
        lengthCm: component.lengthCm!,
      );
      if (!mounted) return;
      setState(() => _parts = parts);
      await _loadBalance();
      if (mounted) _showSnack(tr('seller.ar_request_sent_snack'));
    } on ApiError catch (e) {
      if (e.status == 402 && mounted) {
        await _promptBuyTokens();
      } else if (mounted) {
        _showSnack(tr('seller.ar_request_failed'), isError: true);
      }
    } catch (e, st) {
      appLog.handle(e, st, '[ar-section] request failed');
      if (mounted) _showSnack(tr('seller.ar_request_failed'), isError: true);
    } finally {
      if (mounted) setState(() => _busy.remove(component.partKey));
    }
  }

  Future<void> _toggleVisibility(ArPart part) async {
    final next = !part.isArVisible;
    setState(() {
      _parts = [
        for (final p in _parts)
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
      appLog.handle(e, st, '[ar-section] visibility toggle failed');
      if (!mounted) return;
      setState(() {
        _parts = [
          for (final p in _parts)
            if (p.id == part.id)
              p.copyWith(isArVisible: part.isArVisible)
            else
              p,
        ];
      });
      _showSnack(tr('seller.ar_visibility_toggle_failed'), isError: true);
    }
  }

  void _openViewer(ArPart part) {
    if (!part.hasModel) return;
    // Every model-bearing piece becomes a switchable part in one viewer; the
    // tapped piece opens first. Opening separate screens per part is the bad UX
    // this replaces.
    final modelParts = _parts.where((p) => p.hasModel).toList(growable: false);
    final parts = [
      for (final p in modelParts)
        Product3DPart(
          id: p.id,
          name: p.label,
          glbUrl: p.arModelUrl!,
          usdzUrl: p.usdzUrl,
          widthCm: p.widthCm ?? widget.product.widthCm,
          heightCm: p.heightCm ?? widget.product.heightCm,
          depthCm: p.depthCm ?? widget.product.lengthCm,
        ),
    ];
    final tapped = modelParts.indexWhere((p) => p.id == part.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/seller-ar-model'),
        builder: (_) => Product3DPreviewScreen(
          parts: parts,
          initialIndex: tapped < 0 ? 0 : tapped,
          productName: widget.product.name.get('uz'),
          posterUrl: widget.product.heroImage,
        ),
      ),
    );
  }

  Future<void> _openTokens() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/ar-tokens'),
        builder: (_) => const ArTokensScreen(),
      ),
    );
    if (mounted) await _loadBalance();
  }

  Future<bool?> _confirmReRequest() {
    final c = SellerColors.of(context);
    return showDialog<bool>(
      context: context,
      routeSettings: const RouteSettings(name: '/ar-rerequest-confirm'),
      builder: (ctx) => _ActionDialog(
        icon: Icons.autorenew_rounded,
        iconColor: c.onPrimarySoft,
        iconBg: c.primarySoft,
        title: tr('product.ar_rescan_confirm_title'),
        message: tr('product.ar_rescan_confirm_message'),
        primaryLabel: tr('product.ar_rescan_confirm_yes'),
        primaryColor: c.primary,
        cancelLabel: tr('product.ar_rescan_confirm_cancel'),
        onPrimary: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        onCancel: () => Navigator.of(ctx, rootNavigator: true).pop(false),
      ),
    );
  }

  Future<void> _promptBuyTokens() async {
    final c = SellerColors.of(context);
    final go = await showDialog<bool>(
      context: context,
      routeSettings: const RouteSettings(name: '/ar-no-tokens'),
      builder: (ctx) => _ActionDialog(
        icon: Icons.bolt_rounded,
        iconColor: c.gold,
        iconBg: c.goldBg,
        title: tr('product.ar_no_tokens_title'),
        message: tr('product.ar_no_tokens_message'),
        primaryLabel: tr('product.ar_no_tokens_buy'),
        primaryColor: c.primary,
        cancelLabel: tr('product.ar_rescan_confirm_cancel'),
        onPrimary: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        onCancel: () => Navigator.of(ctx, rootNavigator: true).pop(false),
      ),
    );
    if (go == true && mounted) await _openTokens();
  }

  Future<void> _showNeedDimensionsDialog() async {
    final c = SellerColors.of(context);
    final goEdit = await showDialog<bool>(
      context: context,
      routeSettings: const RouteSettings(name: '/ar-need-dimensions'),
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
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
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
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

  bool _canSubmitRequest(_ArRow row) {
    final component = row.component;
    if (component == null || !component.isComplete) return true;
    final needsToken =
        _balance?.requestNeedsToken(
          partFreeScanUsed: row.part?.freeScanUsed ?? false,
        ) ??
        false;
    if (!needsToken) return true;
    return (_balance?.arCredits ?? 0) > 0;
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_published) return const ArNotApprovedCard();

    final c = SellerColors.of(context);
    final rows = _rows();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.view_in_ar_rounded,
                  size: 20,
                  color: c.onPrimarySoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('seller.ar_scan_card_title'),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('seller.ar_scan_card_description'),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.grey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TokenBanner(
            credits: _balance?.arCredits,
            ai3dUsed: _balance?.ai3dUsed,
            ai3dLimit: _balance?.ai3dLimit,
            onTopUp: _openTokens,
          ),
          if (!_partsLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: c.primary,
                  ),
                ),
              ),
            )
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr('seller.ar_scan_no_components'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: c.grey,
                  height: 1.3,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 16, color: c.divider),
              _PartTile(
                row: rows[i],
                busy: _busy.contains(rows[i].component?.partKey),
                canRequest: _canSubmitRequest(rows[i]),
                showTitle: rows.length > 1,
                onRequest: () => _request(rows[i]),
                onView: rows[i].part != null
                    ? () => _openViewer(rows[i].part!)
                    : null,
                onToggleVisibility: rows[i].part != null
                    ? () => _toggleVisibility(rows[i].part!)
                    : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One AR row = a scannable component (its dimensions) + its existing part
/// (null when not yet requested).
class _ArRow {
  const _ArRow({this.component, this.part});
  final ArScanComponent? component;
  final ArPart? part;

  String get label =>
      part?.label ?? component?.label ?? tr('seller.ar_part_default_label');
}

/// The per-part state-machine tile.
class _PartTile extends StatelessWidget {
  const _PartTile({
    required this.row,
    required this.busy,
    required this.canRequest,
    required this.showTitle,
    required this.onRequest,
    this.onView,
    this.onToggleVisibility,
  });

  final _ArRow row;
  final bool busy;
  final bool canRequest;
  final bool showTitle;
  final VoidCallback onRequest;
  final VoidCallback? onView;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final part = row.part;
    final status = part?.arStatus ?? 'none';

    final (subtitle, subtitleColor) = _subtitle(c, part, status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle) ...[
                Text(
                  row.label,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
              ],
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _trailing(context, c, part, status),
      ],
    );
  }

  (String, Color) _subtitle(SellerColors c, ArPart? part, String status) {
    switch (status) {
      case 'pending':
        return (tr('seller.ar_part_pending'), c.info);
      case 'processing':
        return (tr('seller.ar_part_processing'), c.info);
      case 'approved':
        return (
          part?.isArVisible ?? true
              ? tr('seller.ar_part_ready_visible')
              : tr('seller.ar_part_ready_hidden'),
          c.positive,
        );
      case 'rejected':
      case 'failed':
        final reason = part?.arErrorReason?.trim();
        return (
          reason != null && reason.isNotEmpty
              ? '${tr('seller.ar_part_rejected')}: $reason'
              : tr('seller.ar_part_rejected'),
          c.negative,
        );
      default:
        // none — ready to request, unless dimensions are missing.
        final complete = row.component?.isComplete ?? false;
        return complete
            ? (tr('seller.ar_part_ready_to_scan'), c.grey)
            : (tr('seller.ar_part_dims_incomplete'), c.warning);
    }
  }

  Widget _trailing(
    BuildContext context,
    SellerColors c,
    ArPart? part,
    String status,
  ) {
    switch (status) {
      case 'pending':
        return _StatusChip(
          label: tr('seller.ar_part_pending_chip'),
          color: c.info,
          bg: c.infoBg,
        );
      case 'processing':
        return SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: c.info),
        );
      case 'approved':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onToggleVisibility != null)
              IconButton(
                onPressed: onToggleVisibility,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  (part?.isArVisible ?? true)
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: c.grey,
                  size: 20,
                ),
              ),
            _PrimaryButton(
              label: tr('seller.ar_view_in_ar'),
              icon: Icons.view_in_ar_rounded,
              color: c.primary,
              onTap: onView,
            ),
          ],
        );
      case 'rejected':
      case 'failed':
        return _PrimaryButton(
          label: tr('seller.ar_part_retry'),
          icon: Icons.autorenew_rounded,
          color: c.primary,
          busy: busy,
          onTap: canRequest ? onRequest : null,
        );
      default:
        return _PrimaryButton(
          label: tr('seller.ar_part_create'),
          icon: Icons.auto_awesome_rounded,
          color: c.primary,
          busy: busy,
          onTap: canRequest ? onRequest : null,
        );
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    this.busy = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // A hand-rolled Material/InkWell button, NOT a ButtonStyleButton: this
    // tile's trailing slot is a non-flex child of a Row, so it is measured with
    // an UNBOUNDED width — and FilledButton/ElevatedButton assert
    // "BoxConstraints forces an infinite width" under an unbounded width
    // constraint. Material + InkWell + a mainAxisSize.min Row just sizes to its
    // content, so it lays out correctly in that slot.
    return Material(
      color: onTap == null && !busy ? color.withValues(alpha: 0.45) : color,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.bg,
  });
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// The AR-token balance / quota banner with a top-up shortcut.
class _TokenBanner extends StatelessWidget {
  const _TokenBanner({
    required this.credits,
    required this.onTopUp,
    this.ai3dUsed,
    this.ai3dLimit,
  });
  final int? credits;
  final int? ai3dUsed;
  final int? ai3dLimit;
  final VoidCallback onTopUp;

  String _summary() {
    final count = credits ?? 0;
    final tokens = tr(
      'seller.ar_tokens_balance',
    ).replaceFirst('{count}', '$count');
    final limit = ai3dLimit;
    if (limit == null || limit <= 0) return tokens;
    final used = ai3dUsed ?? 0;
    if (used >= limit && count <= 0) {
      return '$tokens · ${tr('seller.ar_quota_exhausted_short')}';
    }
    return '$tokens · ${tr('dashboard.bonus_banner_ai3d_value', args: ['$used', '$limit'])}';
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final limit = ai3dLimit;
    final quotaExhausted =
        limit != null &&
        limit > 0 &&
        (ai3dUsed ?? 0) >= limit &&
        (credits ?? 0) <= 0;
    final accent = quotaExhausted ? c.negative : c.gold;
    return InkWell(
      onTap: onTopUp,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: quotaExhausted ? c.negativeBg : c.goldBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _summary(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: quotaExhausted ? c.negative : c.ink,
                  height: 1.25,
                ),
              ),
            ),
            Text(
              tr('seller.ar_tokens_top_up'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: accent),
          ],
        ),
      ),
    );
  }
}

/// A compact themed confirm dialog (token-charged re-request / out-of-tokens).
class _ActionDialog extends StatelessWidget {
  const _ActionDialog({
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
            const SizedBox(height: 8),
            TextButton(
              onPressed: onCancel,
              child: Text(
                cancelLabel,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontWeight: FontWeight.w600,
                  color: c.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
