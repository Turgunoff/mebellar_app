import 'package:flutter/material.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';

/// Opens the wallet explainer sheet. Educational only — no actions, fully
/// dismissible (scrim tap / drag-down / the header close button).
Future<void> showWalletInfoBottomSheet(BuildContext context) {
  final c = SellerColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surface,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const WalletInfoBottomSheet(),
  );
}

/// Explains the seller wallet: what it is, the automatic commission debit, and
/// the negative-balance grace/freeze rule. The warning item deliberately reuses
/// the same `warning` chrome as the in-screen debt banner for visual continuity.
class WalletInfoBottomSheet extends StatelessWidget {
  const WalletInfoBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final items = <_WalletInfoItem>[
      _WalletInfoItem(
        icon: Icons.receipt_long,
        title: tr('seller.wallet_info_purpose_title'),
        description: tr('seller.wallet_info_purpose_desc'),
      ),
      _WalletInfoItem(
        icon: Icons.autorenew,
        title: tr('seller.wallet_info_auto_debit_title'),
        description: tr('seller.wallet_info_auto_debit_desc'),
      ),
      _WalletInfoItem(
        icon: Icons.warning_amber_rounded,
        title: tr('seller.wallet_info_debt_title'),
        description: tr('seller.wallet_info_debt_desc'),
        warning: true,
      ),
    ];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    tr('seller.wallet_how_it_works_cta'),
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _CloseButton(onTap: () => Navigator.of(context).maybePop()),
              ],
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 20),
              _WalletInfoRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _WalletInfoItem {
  const _WalletInfoItem({
    required this.icon,
    required this.title,
    required this.description,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool warning;
}

class _WalletInfoRow extends StatelessWidget {
  const _WalletInfoRow({required this.item});

  final _WalletInfoItem item;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    // Fixed accent chips (brand icon on its tint) read on both light and dark
    // surfaces — same recipe as the screen's debt banner for the warning case.
    final iconColor = item.warning ? c.warning : c.onPrimarySoft;
    final chipColor = item.warning ? c.warningBg : c.primarySoft;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: iconColor, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.grey,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: c.fillSoft,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.close, size: 20, color: c.grey),
        ),
      ),
    );
  }
}
