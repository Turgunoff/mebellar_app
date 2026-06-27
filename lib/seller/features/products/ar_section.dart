import 'package:flutter/material.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/logging/talker.dart';
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
import 'screens/seller_ar_model_screen.dart';
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
      final parts = await sl<ArScanRepository>().fetchArParts(widget.product.id);
      if (mounted) {
        setState(() {
          _parts = parts;
          _partsLoaded = true;
        });
      }
    } catch (e, st) {
      talker.handle(e, st, '[ar-section] parts load failed');
      if (mounted) setState(() => _partsLoaded = true);
    }
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await sl<ArTokenRepository>().balance();
      if (mounted) setState(() => _balance = balance);
    } catch (e, st) {
      talker.handle(e, st, '[ar-section] balance load failed');
    }
  }

  /// One row per scannable component, merged with its existing part by
  /// `part_key`. A model-bearing "orphan" part (e.g. a legacy `single` model on
  /// a set) is adopted onto the first piece with no part yet, so an existing
  /// model is never stranded or duplicated.
  List<_ArRow> _rows() {
    final components =
        resolveArScanComponents(schema: widget.schema, product: widget.product);
    final rows = <String, _ArRow>{
      for (final c in components) c.partKey: _ArRow(component: c, part: null),
    };

    final orphans = <ArPart>[];
    for (final part in _parts) {
      if (rows.containsKey(part.partKey)) {
        rows[part.partKey] =
            _ArRow(component: rows[part.partKey]!.component, part: part);
      } else {
        orphans.add(part);
      }
    }
    for (final orphan in orphans) {
      final adoptable = orphan.hasModel ||
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
        rows[freeKey] = _ArRow(component: rows[freeKey]!.component, part: orphan);
      } else {
        rows[orphan.partKey] = _ArRow(part: orphan);
      }
    }
    return rows.values.toList(growable: false);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Requests (or re-requests) a 3D model for one part. The first request is
  /// free; a re-request costs 1 token, so we confirm + balance-check first.
  /// Incomplete dimensions route to the edit form instead of a doomed request.
  Future<void> _request(_ArRow row) async {
    final component = row.component;
    if (component == null || !component.isComplete) {
      await _showNeedDimensionsDialog();
      return;
    }
    if (row.part?.freeScanUsed ?? false) {
      final tokens = _balance?.arCredits;
      if (tokens != null && tokens <= 0) {
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
      talker.handle(e, st, '[ar-section] request failed');
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
      talker.handle(e, st, '[ar-section] visibility toggle failed');
      if (!mounted) return;
      setState(() {
        _parts = [
          for (final p in _parts)
            if (p.id == part.id) p.copyWith(isArVisible: part.isArVisible) else p,
        ];
      });
      _showSnack(tr('seller.ar_visibility_toggle_failed'), isError: true);
    }
  }

  void _openViewer(ArPart part) {
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider),
      ),
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
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.view_in_ar_rounded, color: c.onPrimarySoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('seller.ar_scan_card_title'),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tr('seller.ar_scan_card_description'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: c.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _TokenBanner(
            credits: _balance?.arCredits,
            onTopUp: _openTokens,
          ),
          const SizedBox(height: 12),
          if (!_partsLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: c.primary),
                ),
              ),
            )
          else if (rows.isEmpty)
            Text(
              tr('seller.ar_scan_no_components'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.grey,
              ),
            )
          else
            ...[
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 22, color: c.divider),
                _PartTile(
                  row: rows[i],
                  busy: _busy.contains(rows[i].component?.partKey),
                  onRequest: () => _request(rows[i]),
                  onView: rows[i].part != null ? () => _openViewer(rows[i].part!) : null,
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
    required this.onRequest,
    this.onView,
    this.onToggleVisibility,
  });

  final _ArRow row;
  final bool busy;
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
              Text(
                row.label,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
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
        return _StatusChip(label: tr('seller.ar_part_pending_chip'), color: c.info, bg: c.infoBg);
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
          onTap: onRequest,
        );
      default:
        return _PrimaryButton(
          label: tr('seller.ar_part_create'),
          icon: Icons.auto_awesome_rounded,
          color: c.primary,
          busy: busy,
          onTap: onRequest,
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
    return FilledButton.icon(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// The AR-token balance / quota banner with a top-up shortcut.
class _TokenBanner extends StatelessWidget {
  const _TokenBanner({required this.credits, required this.onTopUp});
  final int? credits;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return InkWell(
      onTap: onTopUp,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.goldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, size: 18, color: c.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('seller.ar_tokens_balance')
                    .replaceFirst('{count}', '${credits ?? 0}'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ),
            Text(
              tr('seller.ar_tokens_top_up'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: c.gold,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.gold),
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
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
