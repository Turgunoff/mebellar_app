import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/seller_wallet.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/pending_payment_service.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../../../../shared/repositories/seller_wallet_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../products/widgets/product_form/thousands_formatter.dart';
import '../bloc/seller_wallet_cubit.dart';
import '../widgets/wallet_info_bottom_sheet.dart';

/// Official provider brand colours for the top-up tiles.
const Color _kPaymeTeal = Color(0xFF00A19A);
const Color _kClickBlue = Color(0xFF0073FF);

/// Seller wallet — balance, debt state, automated Payme/Click top-up, ledger.
/// A top-up opens the payment app via a deep-link; the balance is credited by
/// the Merchant webhook and reconciled on return (the global PaymentRecoveryGate
/// shows the settled outcome, and the screen refreshes the balance once the
/// deposit confirms — see [SellerWalletCubit.reconcileDeposit]).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with WidgetsBindingObserver {
  /// Persisted flag — the explainer auto-opens only on the seller's first
  /// visit; afterwards it stays reachable via the "Hamyon qanday ishlaydi?"
  /// link on the balance card.
  static const _seenInfoKey = 'has_seen_wallet_info';

  late final SellerWalletCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = SellerWalletCubit(sl<SellerWalletRepository>())..load();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoShowInfo());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the Payme/Click app: poll the deposit + refresh the balance
    // the instant the webhook credits it (no-op when nothing is in flight).
    if (state == AppLifecycleState.resumed) {
      _cubit.reconcileDeposit();
    }
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
    return BlocProvider<SellerWalletCubit>.value(
      value: _cubit,
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
          tr('seller.profile_wallet_title'),
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
        listenWhen: (prev, next) => prev.depositStatus != next.depositStatus,
        listener: (context, state) {
          if (state.depositStatus == DepositStatus.failure) {
            _showSnack(
              context,
              tr('seller.wallet_deposit_start_failed'),
              icon: Iconsax.close_circle,
              tone: _SnackTone.error,
            );
            context.read<SellerWalletCubit>().acknowledgeDepositResult();
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
                    tr('seller.wallet_recent_transactions'),
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
                        tr('seller.wallet_current_balance'),
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
                          tr('seller.wallet_currency_som'),
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
                        tr('seller.wallet_how_it_works_cta'),
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
        tr(
          'seller.wallet_credit_limit_chip',
          namedArgs: {
            'limit': formatSom(wallet.creditLimit),
            'floor': formatSom(wallet.debtFloor),
          },
        ),
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
        ? tr('seller.wallet_debt_suspended_notice')
        : tr(
            'seller.wallet_debt_grace_notice',
            namedArgs: {'hours': wallet.graceHoursLeft().toString()},
          );
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
              tr(
                'seller.wallet_pending_topup_notice',
                namedArgs: {'amount': formatSom(topUp.amount)},
              ),
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
  PaymentProvider _provider = PaymentProvider.payme;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(' ', '')) ?? 0;
    final cubit = context.read<SellerWalletCubit>();
    if (amount <= 0) {
      _showSnack(
        context,
        tr('seller.wallet_enter_topup_amount'),
        icon: Iconsax.info_circle,
        tone: _SnackTone.neutral,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final link = await cubit.startDeposit(amount: amount, provider: _provider);
    if (link == null || !mounted) return;
    // Mark the top-up in flight BEFORE handing off so the global
    // PaymentRecoveryGate reconciles it (and shows the settled outcome) when the
    // seller returns from the payment app.
    final reference = link.reference;
    if (reference != null &&
        reference.isNotEmpty &&
        sl.isRegistered<PendingPaymentService>()) {
      await sl<PendingPaymentService>().mark(
        kind: PendingPaymentKind.walletDeposit,
        reference: reference,
      );
    }
    final uri = Uri.tryParse(link.checkoutUrl);
    if (uri != null && link.checkoutUrl.isNotEmpty) {
      // externalApplication forces the OS to open the Payme/Click app.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final submitting = widget.state.depositStatus == DepositStatus.starting;

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
            tr('seller.wallet_topup_section_title'),
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
            tr('seller.wallet_topup_section_subtitle'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12.5,
              color: c.grey,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
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
              labelText: tr('seller.wallet_amount_label'),
              labelStyle: TextStyle(fontFamily: AppFonts.seller, color: c.grey),
              prefixIcon: Icon(Iconsax.money_4, color: c.greyMid, size: 20),
              suffixText: tr('seller.wallet_currency_som'),
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
          const SizedBox(height: 16),
          Text(
            tr('seller.wallet_payment_method'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 10),
          _ProviderTile(
            brand: _kPaymeTeal,
            wordmark: 'Payme',
            label: tr('seller.wallet_via_payme'),
            selected: _provider == PaymentProvider.payme,
            onTap: submitting
                ? null
                : () => setState(() => _provider = PaymentProvider.payme),
          ),
          const SizedBox(height: 10),
          _ProviderTile(
            brand: _kClickBlue,
            wordmark: 'Click',
            label: tr('seller.wallet_via_click'),
            selected: _provider == PaymentProvider.click,
            onTap: submitting
                ? null
                : () => setState(() => _provider = PaymentProvider.click),
          ),
          const SizedBox(height: 18),
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
                onPressed: submitting ? null : _submit,
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
                    : const Icon(Iconsax.wallet_add_1, size: 19),
                label: Text(
                  submitting
                      ? tr('seller.wallet_opening')
                      : tr('seller.wallet_topup_button'),
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

/// A branded payment-app choice (wordmark badge + label + selection ring),
/// mirroring the AR-token / tariff top-up sheets.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.brand,
    required this.wordmark,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color brand;
  final String wordmark;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: selected ? brand.withValues(alpha: 0.08) : c.fillSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? brand : c.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: brand,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  wordmark,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: c.ink,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: brand, size: 20),
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
            tr('seller.wallet_load_failed'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.grey,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: Text(tr('seller.reviews_retry'))),
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
