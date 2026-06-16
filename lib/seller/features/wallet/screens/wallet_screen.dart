import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/seller_wallet.dart';
import '../../../../shared/repositories/seller_wallet_repository.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../products/widgets/product_form/thousands_formatter.dart';
import '../bloc/seller_wallet_cubit.dart';
import '../widgets/wallet_info_bottom_sheet.dart';

/// Local fallback for the Woody top-up card — used only when the backend
/// hasn't published payment instructions yet ([state.instructions] == null or
/// an empty card number). When the backend returns a card it always wins, so
/// the till stays server-owned (same source the tariff flow reads).
const _kFallbackCardNumber = '9860 1501 0444 6953';
const _kFallbackCardHolder = 'WOODY XIZMATI';

/// Seller wallet — balance, debt state, top-up by card + screenshot, ledger.
/// The top-up trust model mirrors the tariff flow: pay to the Woody card,
/// upload the receipt, an admin approves and the balance is credited (a
/// clearing balance also lifts the debt freeze automatically).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  /// Persisted flag — the explainer auto-opens only on the seller's first
  /// visit; afterwards it stays reachable via the "Hamyon qanday ishlaydi?"
  /// link on the balance card.
  static const _seenInfoKey = 'has_seen_wallet_info';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoShowInfo());
  }

  Future<void> _maybeAutoShowInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seenInfoKey) ?? false) return;
    if (!mounted) return;
    // Persist before awaiting dismissal so killing the app mid-sheet can't
    // make it auto-open a second time.
    await prefs.setBool(_seenInfoKey, true);
    if (!mounted) return;
    await showWalletInfoBottomSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerWalletCubit>(
      create: (_) => SellerWalletCubit(
        sl<SellerWalletRepository>(),
        tariffs: sl<TariffRepository>(),
      )..load(),
      child: const _WalletView(),
    );
  }
}

class _WalletView extends StatelessWidget {
  const _WalletView();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hamyon',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        iconTheme: IconThemeData(color: c.ink),
      ),
      body: BlocConsumer<SellerWalletCubit, SellerWalletState>(
        listenWhen: (prev, next) => prev.topUpStatus != next.topUpStatus,
        listener: (context, state) {
          if (state.topUpStatus == TopUpStatus.success) {
            _showSnack(
              context,
              "So'rov yuborildi — admin tasdiqlagach balans yangilanadi.",
              icon: Iconsax.tick_circle,
              tone: _SnackTone.success,
            );
            context.read<SellerWalletCubit>().acknowledgeTopUpResult();
          } else if (state.topUpStatus == TopUpStatus.failure) {
            _showSnack(
              context,
              "To'lov so'rovini yuborib bo'lmadi. Qayta urinib ko'ring.",
              icon: Iconsax.close_circle,
              tone: _SnackTone.error,
            );
            context.read<SellerWalletCubit>().acknowledgeTopUpResult();
          }
        },
        builder: (context, state) {
          if (state.status == WalletStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == WalletStatus.failure) {
            return _ErrorView(
              onRetry: () => context.read<SellerWalletCubit>().load(),
            );
          }
          final wallet = state.wallet;
          return BrandRefreshIndicator(
            color: AppColors.sellerPrimary,
            onRefresh: () => context.read<SellerWalletCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                _BalanceCard(wallet: wallet),
                if (!wallet.isHealthy) ...[
                  const SizedBox(height: 12),
                  _DebtNotice(wallet: wallet),
                ],
                if (wallet.pendingTopUp != null) ...[
                  const SizedBox(height: 12),
                  _PendingTopUpCard(topUp: wallet.pendingTopUp!),
                ],
                const SizedBox(height: 20),
                _TopUpSection(state: state, suggestedAmount: wallet.debtAmount),
                if (wallet.transactions.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    "So'nggi amallar",
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TransactionsCard(transactions: wallet.transactions),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium balance card — a fixed brand "card face" (deep indigo, or a maroon
// alarm gradient when the seller is in the red). It's decorative chrome like
// the tariff payment card, so it intentionally doesn't flip with the theme:
// white text reads on either gradient in light and dark alike.
// ---------------------------------------------------------------------------

const _kHealthyGradient = <Color>[
  Color(0xFF222663),
  Color(0xFF2F3A8F),
  Color(0xFF4554C4),
];
const _kDebtGradient = <Color>[
  Color(0xFF6E1A19),
  Color(0xFFA32C25),
  Color(0xFFC0392B),
];

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final SellerWallet wallet;

  @override
  Widget build(BuildContext context) {
    final negative = wallet.balance < 0;
    final gradient = negative ? _kDebtGradient : _kHealthyGradient;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withValues(alpha: 0.38),
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Soft light blooms give the flat gradient depth.
            Positioned(
              top: -50,
              right: -30,
              child: _Bloom(
                size: 150,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -20,
              child: _Bloom(
                size: 140,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Joriy balans',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.78),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Iconsax.wallet_3,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'WOODY',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          formatSom(wallet.balance),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                            height: 1.05,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          "so'm",
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (wallet.creditLimit > 0) ...[
                    const SizedBox(height: 10),
                    _CreditLimitChip(wallet: wallet),
                  ],
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => showWalletInfoBottomSheet(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      label: Text(
                        'Hamyon qanday ishlaydi?',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditLimitChip extends StatelessWidget {
  const _CreditLimitChip({required this.wallet});

  final SellerWallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "Kredit limiti: ${formatSom(wallet.creditLimit)} so'm "
        "(${formatSom(wallet.debtFloor)} gacha)",
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Grace-period warning or suspension notice, mirroring the dashboard banner.
class _DebtNotice extends StatelessWidget {
  const _DebtNotice({required this.wallet});

  final SellerWallet wallet;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final suspended = wallet.isSuspendedDueToDebt;
    final fg = suspended ? c.negative : c.warning;
    final bg = suspended ? c.negativeBg : c.warningBg;
    final text = suspended
        ? "Do'koningiz vaqtincha muzlatildi! Iltimos, qarzdorlikni uzing — "
              "balans tiklanishi bilan do'kon avtomatik ochiladi."
        : "Balansingiz minusga kirdi. Xizmat ko'rsatish to'xtatilmasligi "
              "uchun ${wallet.graceHoursLeft()} soat ichida hisobni "
              "to'ldiring.";
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            suspended ? Iconsax.lock : Iconsax.warning_2,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingTopUpCard extends StatelessWidget {
  const _PendingTopUpCard({required this.topUp});

  final WalletTopUp topUp;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.progressBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Iconsax.clock, color: c.progress, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${formatSom(topUp.amount)} so'mlik to'lovingiz ko'rib "
              'chiqilmoqda.',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.progress,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUpSection extends StatefulWidget {
  const _TopUpSection({required this.state, required this.suggestedAmount});

  final SellerWalletState state;

  /// Prefill: the exact debt the seller must clear (0 when healthy).
  final int suggestedAmount;

  @override
  State<_TopUpSection> createState() => _TopUpSectionState();
}

class _TopUpSectionState extends State<_TopUpSection> {
  late final TextEditingController _amountCtrl = TextEditingController(
    text: widget.suggestedAmount > 0
        ? formatThousands(widget.suggestedAmount)
        : '',
  );

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyCard(String number) async {
    await Clipboard.setData(ClipboardData(text: number.replaceAll(' ', '')));
    if (!mounted) return;
    _showSnack(
      context,
      'Karta raqami nusxalandi',
      icon: Iconsax.copy_success,
      tone: _SnackTone.success,
    );
  }

  Future<void> _pickAndSubmit() async {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(' ', '')) ?? 0;
    final cubit = context.read<SellerWalletCubit>();
    if (amount <= 0) {
      _showSnack(
        context,
        "To'ldirish summasini kiriting.",
        icon: Iconsax.info_circle,
        tone: _SnackTone.neutral,
      );
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final ext = picked.path.split('.').last;
    await cubit.submitTopUp(
      amount: amount,
      screenshot: File(picked.path),
      fileExtension: ext.length <= 4 ? ext : 'jpg',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final instructions = widget.state.instructions;
    final submitting = widget.state.topUpStatus == TopUpStatus.submitting;

    final hasBackendCard =
        instructions != null && instructions.cardNumber.trim().isNotEmpty;
    final cardNumber = hasBackendCard
        ? instructions.cardNumber
        : _kFallbackCardNumber;
    final cardHolder = (instructions?.cardHolder.trim().isNotEmpty ?? false)
        ? instructions!.cardHolder
        : _kFallbackCardHolder;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hisobni to'ldirish",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Quyidagi hisobga to'lov qiling va tasdiqlovchi chekni yuklang:",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12.5,
              color: c.grey,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _CardCopyPill(
            number: cardNumber,
            holder: cardHolder,
            onCopy: () => _copyCard(cardNumber),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: const [ThousandsSpaceFormatter()],
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
            decoration: InputDecoration(
              labelText: "Summa (so'm)",
              labelStyle: TextStyle(fontFamily: AppFonts.seller, color: c.grey),
              prefixIcon: Icon(Iconsax.money_4, color: c.greyMid, size: 20),
              suffixText: "so'm",
              suffixStyle: TextStyle(
                fontFamily: AppFonts.seller,
                color: c.greyMid,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: c.fillSoft,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.divider),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.primary, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: submitting
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.sellerPrimary.withValues(alpha: 0.32),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: submitting ? null : _pickAndSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sellerPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.sellerPrimary.withValues(
                    alpha: 0.55,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Iconsax.receipt_2, size: 19),
                label: Text(
                  submitting ? 'Yuborilmoqda…' : 'Chek yuklash va yuborish',
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tap-to-copy pill for the top-up card number — a distinct, brand-tinted
/// interactive element with a trailing copy affordance.
class _CardCopyPill extends StatelessWidget {
  const _CardCopyPill({
    required this.number,
    required this.holder,
    required this.onCopy,
  });

  final String number;
  final String holder;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: c.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.primary.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Iconsax.card, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // scaleDown keeps the full 16-digit number on one line on
                    // any width — it shrinks to fit instead of truncating.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        number,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      holder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.greyMid,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 15, color: c.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Nusxa',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
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

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, indent: 64, color: c.divider),
            _TransactionTile(tx: transactions[i]),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final WalletTransaction tx;

  static final _fmt = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final debit = tx.isDebit;
    final accent = debit ? c.negative : c.positive;
    final accentBg = debit ? c.negativeBg : c.positiveBg;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: accentBg, shape: BoxShape.circle),
            child: Icon(
              debit ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
              color: accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.note ?? tx.typeLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _fmt.format(tx.createdAt.toLocal()),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    color: c.greyMid,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "${debit ? '' : '+'}${formatSom(tx.amount)}",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.wifi_square, color: c.greyMid, size: 36),
          const SizedBox(height: 10),
          Text(
            "Hamyonni yuklab bo'lmadi",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.grey,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
        ],
      ),
    );
  }
}

enum _SnackTone { success, error, neutral }

/// Sleek floating snackbar shared across the wallet surface — an icon + copy
/// over a rounded card tinted to the action's tone.
void _showSnack(
  BuildContext context,
  String message, {
  required IconData icon,
  required _SnackTone tone,
}) {
  final c = SellerColors.of(context);
  final (Color fg, Color bg) = switch (tone) {
    _SnackTone.success => (c.positive, c.positiveBg),
    _SnackTone.error => (c.negative, c.negativeBg),
    _SnackTone.neutral => (c.ink, c.fillSoft),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        elevation: 2,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
