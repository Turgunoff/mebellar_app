import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/seller_wallet.dart';
import '../../wallet/screens/wallet_screen.dart';

/// Wallet strip at the top of the dashboard. Three escalation states:
///
///   * healthy   → slim balance row (tap → wallet screen);
///   * in grace  → loud WARNING card with the hours-left countdown;
///   * suspended → CRITICAL solid-red card — the shop is frozen.
///
/// Suspension copy promises auto-recovery because the backend reactivates
/// the moment a credit lifts the balance over the floor.
class WalletDebtBanner extends StatelessWidget {
  const WalletDebtBanner({super.key, required this.wallet});

  final SellerWallet wallet;

  void _openWallet(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const WalletScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (wallet.isSuspendedDueToDebt) return _critical(context);
    if (wallet.isInGrace) return _warning(context);
    return _balanceRow(context);
  }

  Widget _critical(BuildContext context) {
    return _TappableCard(
      onTap: () => _openWallet(context),
      color: AppColors.danger,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.lock, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Do'koningiz vaqtincha muzlatildi!",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Iltimos, qarzdorlikni uzing (${formatSom(wallet.debtAmount)} "
                  "so'm). Balans tiklanishi bilan do'kon avtomatik ochiladi.",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                const _BannerCta(
                  label: "Qarzdorlikni uzish",
                  dark: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _warning(BuildContext context) {
    final c = SellerColors.of(context);
    return _TappableCard(
      onTap: () => _openWallet(context),
      color: c.warningBg,
      border: c.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.warning_2, color: c.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balansingiz minusga kirdi',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: c.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Xizmat ko'rsatish to'xtatilmasligi uchun "
                  "${wallet.graceHoursLeft()} soat ichida hisobni to'ldiring.",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.warning,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                _BannerCta(label: "Hisobni to'ldirish", color: c.warning),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceRow(BuildContext context) {
    final c = SellerColors.of(context);
    final negative = wallet.balance < 0;
    return _TappableCard(
      onTap: () => _openWallet(context),
      color: c.surface,
      border: c.divider,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Iconsax.wallet_3, color: c.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hamyon balansi',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.grey,
              ),
            ),
          ),
          Text(
            "${formatSom(wallet.balance)} so'm",
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: negative ? c.negative : c.ink,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Iconsax.arrow_right_3_copy, size: 18, color: c.greyMid),
        ],
      ),
    );
  }
}

class _TappableCard extends StatelessWidget {
  const _TappableCard({
    required this.onTap,
    required this.color,
    required this.child,
    this.border,
    this.padding = const EdgeInsets.all(16),
  });

  final VoidCallback onTap;
  final Color color;
  final Color? border;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: border != null ? Border.all(color: border!) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BannerCta extends StatelessWidget {
  const _BannerCta({required this.label, this.color, this.dark = false});

  final String label;
  final Color? color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.danger : Colors.white;
    final bg = dark ? Colors.white : (color ?? AppColors.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
