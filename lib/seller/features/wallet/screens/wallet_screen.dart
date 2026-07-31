import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/remote_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/result/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/seller_wallet.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/pending_payment_service.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../../../../shared/repositories/seller_wallet_repository.dart';
import '../../../../shared/payments/manual_payment_pending_screen.dart';
import '../../../../shared/payments/payment_pending_copy.dart';
import '../../../../shared/payments/refresh_payment_remote_config.dart';
import '../../../../shared/payments/seller_payment_refresh.dart';
import '../../../../shared/repositories/tariff_repository.dart';
import '../../../../shared/utils/image_upload.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/payment_provider_tile.dart';
import '../../products/widgets/product_form/thousands_formatter.dart';
import '../bloc/seller_wallet_cubit.dart';
import '../widgets/wallet_info_bottom_sheet.dart';
import 'wallet_history_screen.dart';

/// Seller wallet — balance, debt state, Payme/Click or manual card top-up, ledger.
/// Online top-up opens the payment app via a deep-link; manual top-up shows the
/// platform card + receipt upload for admin approval. Both reconcile on return
/// (online via [SellerWalletCubit.reconcileDeposit] + PaymentRecoveryGate).
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
  StreamSubscription<PendingPaymentKind>? _refreshSub;

  @override
  void initState() {
    super.initState();
    _cubit = SellerWalletCubit(sl<SellerWalletRepository>())..load();
    WidgetsBinding.instance.addObserver(this);
    _refreshSub = SellerPaymentRefreshHub.instance.stream.listen((kind) {
      if (kind == PendingPaymentKind.walletDeposit && mounted) {
        unawaited(_cubit.refresh());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoShowInfo());
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
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
        actions: [
          IconButton(
            tooltip: tr('seller.wallet_history_title'),
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/wallet-history'),
                      builder: (_) => const WalletHistoryScreen(),
                    ),
                  )
                  .then((_) {
                    if (context.mounted) {
                      context.read<SellerWalletCubit>().refresh();
                    }
                  });
            },
            icon: Icon(Icons.history_rounded, color: c.ink),
          ),
        ],
      ),
      body: BlocConsumer<SellerWalletCubit, SellerWalletState>(
        listenWhen: (prev, next) =>
            prev.depositStatus != next.depositStatus ||
            prev.withdrawStatus != next.withdrawStatus,
        listener: (context, state) {
          if (state.depositStatus == DepositStatus.failure) {
            _showSnack(
              context,
              state.error ?? tr('seller.wallet_deposit_start_failed'),
              icon: Iconsax.close_circle,
              tone: _SnackTone.error,
            );
            context.read<SellerWalletCubit>().acknowledgeDepositResult();
          }
          if (state.withdrawStatus == WithdrawStatus.success) {
            _showSnack(
              context,
              tr('seller.wallet_withdraw_success'),
              icon: Iconsax.tick_circle,
              tone: _SnackTone.success,
            );
            context.read<SellerWalletCubit>().acknowledgeWithdrawResult();
          } else if (state.withdrawStatus == WithdrawStatus.failure) {
            _showSnack(
              context,
              state.error ?? tr('seller.wallet_withdraw_failed'),
              icon: Iconsax.close_circle,
              tone: _SnackTone.error,
            );
            context.read<SellerWalletCubit>().acknowledgeWithdrawResult();
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
            onRefresh: () async {
              await Future.wait([
                context.read<SellerWalletCubit>().refresh(),
                refreshPaymentRemoteConfig(),
              ]);
            },
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
                if (wallet.pendingDeposit != null) ...[
                  const SizedBox(height: 12),
                  _PendingDepositCard(deposit: wallet.pendingDeposit!),
                ],
                const SizedBox(height: 20),
                if (wallet.hasPendingPayment)
                  _WalletPendingLockedCard(wallet: wallet)
                else
                  _TopUpSection(
                    state: state,
                    suggestedAmount: wallet.debtAmount,
                  ),
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

  void _openPending(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/seller-wallet-pending'),
        builder: (_) => ManualPaymentPendingScreen(
          args: WalletTopUpPendingArgs(topUp: topUp),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPending(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
                  pendingBannerNotice(
                    manualReview: true,
                    amountSom: topUp.amount,
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
              Icon(Iconsax.arrow_right_3, color: c.progress, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingDepositCard extends StatelessWidget {
  const _PendingDepositCard({required this.deposit});

  final WalletDeposit deposit;

  void _openPending(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/seller-wallet-pending'),
        builder: (_) => ManualPaymentPendingScreen(
          args: WalletDepositPendingArgs(deposit: deposit),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPending(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
                  pendingBannerNotice(
                    manualReview: false,
                    amountSom: deposit.amount,
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
              Icon(Iconsax.arrow_right_3, color: c.progress, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletPendingLockedCard extends StatelessWidget {
  const _WalletPendingLockedCard({required this.wallet});

  final SellerWallet wallet;

  void _openPending(BuildContext context) {
    final route = switch ((wallet.pendingTopUp, wallet.pendingDeposit)) {
      (final topUp?, _) => ManualPaymentPendingScreen(
        args: WalletTopUpPendingArgs(topUp: topUp),
      ),
      (_, final deposit?) => ManualPaymentPendingScreen(
        args: WalletDepositPendingArgs(deposit: deposit),
      ),
      _ => null,
    };
    if (route == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/seller-wallet-pending'),
        builder: (_) => route,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final manualReview = wallet.pendingTopUp != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('seller.wallet_topup_section_title'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pendingSubtitle(manualReview: manualReview),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12.5,
              color: c.grey,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => _openPending(context),
            style: FilledButton.styleFrom(
              backgroundColor: c.divider,
              foregroundColor: c.greyMid,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              tr('tariff.cta_pending'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w700,
                fontSize: 15,
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
  int get _minTopUpUzs => RemoteConfig.instance.minWalletTopUp;

  late final TextEditingController _amountCtrl = TextEditingController(
    text: widget.suggestedAmount >= _minTopUpUzs
        ? formatThousands(widget.suggestedAmount)
        : '',
  );
  late final TextEditingController _cardCtrl = TextEditingController();
  PaymentProvider? _provider;
  _WalletPayMode? _payMode;
  File? _screenshotFile;
  Future<Result<TariffPaymentInstructions>>? _instructionsFuture;

  bool get _anyProviderEnabled =>
      RemoteConfig.instance.anyOnlineProviderEnabled;

  /// Always show the switcher so sellers can reach card withdrawal even when
  /// online top-up providers are temporarily off.
  bool get _showPayModeSwitcher => true;

  int? get _parsedAmount {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(' ', '')) ?? 0;
    return amount > 0 ? amount : null;
  }

  String get _cardDigits => _cardCtrl.text.replaceAll(RegExp(r'\D'), '');

  bool get _amountValid {
    final amount = _parsedAmount;
    return amount != null && amount >= _minTopUpUzs;
  }

  bool get _withdrawAmountValid {
    final amount = _parsedAmount;
    final balance = widget.state.wallet.balance;
    return amount != null && amount > 0 && amount <= balance;
  }

  bool get _cardValid => _cardDigits.length >= 16 && _cardDigits.length <= 19;

  bool _providerIsEnabled(PaymentProvider provider) => switch (provider) {
    PaymentProvider.payme => RemoteConfig.instance.paymeEnabled,
    PaymentProvider.click => RemoteConfig.instance.clickEnabled,
  };

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    _cardCtrl.addListener(() => setState(() {}));
    RemoteConfig.instance.addListener(_onPaymentRemoteConfig);
    _syncFromRemoteConfig();
    unawaited(refreshPaymentRemoteConfig());
  }

  void _onPaymentRemoteConfig() {
    if (!mounted) return;
    setState(_syncFromRemoteConfig);
  }

  void _syncFromRemoteConfig() {
    if (_provider != null && !_providerIsEnabled(_provider!)) {
      _provider = null;
    }
    if (_payMode == _WalletPayMode.online && !_anyProviderEnabled) {
      _ensureInstructions();
    }
  }

  void _ensureInstructions() {
    _instructionsFuture ??= sl<TariffRepository>().paymentInstructions();
  }

  void _selectPayMode(_WalletPayMode mode) {
    if (_payMode == mode) return;
    setState(() {
      _payMode = mode;
      _provider = null;
      _screenshotFile = null;
      if (mode == _WalletPayMode.online && !_anyProviderEnabled) {
        _ensureInstructions();
      }
    });
  }

  @override
  void dispose() {
    RemoteConfig.instance.removeListener(_onPaymentRemoteConfig);
    _amountCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOnline() async {
    if (!_anyProviderEnabled) return;
    final amount = _parsedAmount;
    final provider = _provider;
    final cubit = context.read<SellerWalletCubit>();
    if (amount == null) {
      _showSnack(
        context,
        tr('seller.wallet_enter_topup_amount'),
        icon: Iconsax.info_circle,
        tone: _SnackTone.neutral,
      );
      return;
    }
    if (amount < _minTopUpUzs) {
      _showSnack(
        context,
        tr(
          'seller.wallet_min_topup_amount',
          namedArgs: {'min': formatThousands(_minTopUpUzs)},
        ),
        icon: Iconsax.info_circle,
        tone: _SnackTone.neutral,
      );
      return;
    }
    if (provider == null || !_providerIsEnabled(provider)) {
      _showSnack(
        context,
        tr('seller.wallet_select_payment_method_hint'),
        icon: Iconsax.info_circle,
        tone: _SnackTone.neutral,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final link = await cubit.startDeposit(amount: amount, provider: provider);
    if (link == null || !mounted) return;
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) {
      await cubit.refresh();
    }
  }

  Future<void> _copyCard(String number) async {
    await Clipboard.setData(ClipboardData(text: number.replaceAll(' ', '')));
    if (!mounted) return;
    _showSnack(
      context,
      tr('tariff.card_copied'),
      icon: Iconsax.copy,
      tone: _SnackTone.neutral,
    );
  }

  Future<void> _pickScreenshot() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImageUploadHelper().pick(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      setState(() => _screenshotFile = picked.file);
    } on ImagePickError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submitManual() async {
    final amount = _parsedAmount;
    final file = _screenshotFile;
    if (amount == null || amount < _minTopUpUzs || file == null) return;
    FocusScope.of(context).unfocus();
    final cubit = context.read<SellerWalletCubit>();
    final upload = await sl<TariffRepository>().uploadPaymentScreenshot(
      file: file,
      fileExtension: file.path.split('.').last,
    );
    if (!mounted) return;
    final path = upload.valueOrNull;
    if (path == null) {
      _showSnack(
        context,
        upload.failureOrNull?.message ?? tr('seller.ar_manual_failed'),
        icon: Iconsax.warning_2,
        tone: _SnackTone.error,
      );
      return;
    }
    final topUp = await cubit.submitManualTopup(
      amount: amount,
      paymentScreenshotPath: path,
    );
    if (!mounted) return;
    if (topUp != null) {
      setState(() {
        _screenshotFile = null;
        _amountCtrl.clear();
      });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/seller-wallet-pending'),
          builder: (_) => ManualPaymentPendingScreen(
            args: WalletTopUpPendingArgs(topUp: topUp),
          ),
        ),
      );
    } else {
      cubit.acknowledgeManualTopUpResult();
      _showSnack(
        context,
        cubit.state.error ?? tr('seller.ar_manual_failed'),
        icon: Iconsax.warning_2,
        tone: _SnackTone.error,
      );
    }
  }

  Future<void> _submitWithdraw() async {
    final amount = _parsedAmount;
    final cubit = context.read<SellerWalletCubit>();
    if (amount == null || amount <= 0) {
      _showSnack(
        context,
        tr('seller.wallet_withdraw_enter_amount'),
        icon: Iconsax.info_circle,
        tone: _SnackTone.neutral,
      );
      return;
    }
    if (amount > cubit.state.wallet.balance) {
      _showSnack(
        context,
        tr('seller.wallet_withdraw_amount_too_high'),
        icon: Iconsax.info_circle,
        tone: _SnackTone.neutral,
      );
      return;
    }
    if (!_cardValid) {
      _showSnack(
        context,
        tr('seller.wallet_withdraw_enter_card'),
        icon: Iconsax.info_circle,
        tone: _SnackTone.neutral,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final row = await cubit.requestWithdrawal(
      amount: amount,
      cardNumber: _cardDigits,
    );
    if (!mounted) return;
    if (row != null) {
      setState(() {
        _amountCtrl.clear();
        _cardCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final submittingOnline =
        widget.state.depositStatus == DepositStatus.starting;
    final submittingManual =
        widget.state.manualTopUpStatus == ManualTopUpStatus.submitting;
    final submittingWithdraw =
        widget.state.withdrawStatus == WithdrawStatus.submitting;
    final busy = submittingOnline || submittingManual || submittingWithdraw;
    final amount = _parsedAmount;
    final amountValid = _amountValid;
    final isWithdraw = _payMode == _WalletPayMode.card;
    final canSubmitOnline =
        amountValid &&
        _provider != null &&
        _providerIsEnabled(_provider!) &&
        !submittingOnline;
    final canSubmitWithdraw =
        _withdrawAmountValid && _cardValid && !submittingWithdraw;

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
            isWithdraw
                ? tr('seller.ar_pay_mode_card')
                : tr('seller.wallet_topup_section_title'),
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
            isWithdraw
                ? tr('seller.wallet_withdraw_section_subtitle')
                : tr('seller.wallet_topup_section_subtitle'),
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
          if (!isWithdraw && amount != null && !amountValid) ...[
            const SizedBox(height: 8),
            Text(
              tr(
                'seller.wallet_min_topup_amount',
                namedArgs: {'min': formatThousands(_minTopUpUzs)},
              ),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.sellerNegative,
              ),
            ),
          ],
          if (isWithdraw &&
              amount != null &&
              amount > widget.state.wallet.balance) ...[
            const SizedBox(height: 8),
            Text(
              tr('seller.wallet_withdraw_amount_too_high'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.sellerNegative,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_showPayModeSwitcher) ...[
            _WalletPayModeBar(
              mode: _payMode,
              busy: busy,
              onSelect: _selectPayMode,
            ),
            if (_payMode == null) ...[
              const SizedBox(height: 10),
              Text(
                tr('seller.wallet_select_pay_mode'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12.5,
                  color: c.grey,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
          if (isWithdraw)
            _WalletWithdrawFields(
              cardCtrl: _cardCtrl,
              busy: busy,
              submitting: submittingWithdraw,
              canSubmit: canSubmitWithdraw,
              onSubmit: _submitWithdraw,
            )
          else if (_payMode != _WalletPayMode.card &&
              (_payMode == _WalletPayMode.online || _payMode == null) &&
              _anyProviderEnabled) ...[
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
            if (RemoteConfig.instance.paymeVisible)
              PaymentProviderTile(
                provider: PaymentProvider.payme,
                label: tr('seller.wallet_via_payme'),
                selected: _provider == PaymentProvider.payme,
                comingSoon: RemoteConfig.instance.paymeComingSoon,
                style: PaymentProviderTileStyle.seller,
                onTap: busy || !RemoteConfig.instance.paymeEnabled
                    ? null
                    : () => setState(() => _provider = PaymentProvider.payme),
              ),
            if (RemoteConfig.instance.paymeVisible &&
                RemoteConfig.instance.clickVisible)
              const SizedBox(height: 10),
            if (RemoteConfig.instance.clickVisible)
              PaymentProviderTile(
                provider: PaymentProvider.click,
                label: tr('seller.wallet_via_click'),
                selected: _provider == PaymentProvider.click,
                comingSoon: RemoteConfig.instance.clickComingSoon,
                style: PaymentProviderTileStyle.seller,
                onTap: busy || !RemoteConfig.instance.clickEnabled
                    ? null
                    : () => setState(() => _provider = PaymentProvider.click),
              ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: canSubmitOnline
                    ? [
                        BoxShadow(
                          color: AppColors.sellerPrimary.withValues(
                            alpha: 0.32,
                          ),
                          blurRadius: 18,
                          spreadRadius: -4,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: canSubmitOnline ? _submitOnline : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sellerPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.sellerPrimary.withValues(
                      alpha: 0.35,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: submittingOnline
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
                    submittingOnline
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
          ] else if (_payMode == _WalletPayMode.online && !_anyProviderEnabled)
            _WalletManualTopUpSection(
              instructionsFuture: _instructionsFuture,
              amount: amount,
              amountValid: amountValid,
              screenshotFile: _screenshotFile,
              busy: busy,
              submitting: submittingManual,
              onCopyCard: _copyCard,
              onPickScreenshot: _pickScreenshot,
              onSubmit: _submitManual,
            ),
        ],
      ),
    );
  }
}

enum _WalletPayMode { online, card }

class _WalletWithdrawFields extends StatelessWidget {
  const _WalletWithdrawFields({
    required this.cardCtrl,
    required this.busy,
    required this.submitting,
    required this.canSubmit,
    required this.onSubmit,
  });

  final TextEditingController cardCtrl;
  final bool busy;
  final bool submitting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: cardCtrl,
          enabled: !busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(19),
            _CardNumberFormatter(),
          ],
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
            labelText: tr('seller.wallet_card_number_label'),
            labelStyle: TextStyle(fontFamily: AppFonts.seller, color: c.grey),
            prefixIcon: Icon(Iconsax.card, color: c.greyMid, size: 20),
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
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: canSubmit ? onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sellerPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.sellerPrimary.withValues(
                alpha: 0.35,
              ),
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
                : const Icon(Iconsax.send_2, size: 19),
            label: Text(
              submitting
                  ? tr('seller.wallet_withdraw_submitting')
                  : tr('seller.wallet_withdraw_button'),
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Groups card digits as `XXXX XXXX XXXX XXXX`.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _WalletPayModeBar extends StatelessWidget {
  const _WalletPayModeBar({
    required this.mode,
    required this.busy,
    required this.onSelect,
  });

  final _WalletPayMode? mode;
  final bool busy;
  final ValueChanged<_WalletPayMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.fillFaint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _WalletPayModeChip(
              label: tr('seller.ar_pay_mode_online'),
              icon: Icons.smartphone_rounded,
              selected: mode == _WalletPayMode.online,
              onTap: busy ? null : () => onSelect(_WalletPayMode.online),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _WalletPayModeChip(
              label: tr('seller.ar_pay_mode_card'),
              icon: Icons.credit_card_rounded,
              selected: mode == _WalletPayMode.card,
              onTap: busy ? null : () => onSelect(_WalletPayMode.card),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletPayModeChip extends StatelessWidget {
  const _WalletPayModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: selected ? c.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: c.primary.withValues(alpha: 0.35))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? c.primary : c.grey),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? c.ink : c.grey,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletManualTopUpSection extends StatelessWidget {
  const _WalletManualTopUpSection({
    required this.instructionsFuture,
    required this.amount,
    required this.amountValid,
    required this.screenshotFile,
    required this.busy,
    required this.submitting,
    required this.onCopyCard,
    required this.onPickScreenshot,
    required this.onSubmit,
  });

  final Future<Result<TariffPaymentInstructions>>? instructionsFuture;
  final int? amount;
  final bool amountValid;
  final File? screenshotFile;
  final bool busy;
  final bool submitting;
  final Future<void> Function(String) onCopyCard;
  final VoidCallback onPickScreenshot;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final future = instructionsFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<Result<TariffPaymentInstructions>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final result = snap.data;
        if (result == null || result.failureOrNull != null) {
          return Text(
            tr('tariff.instructions_load_failed'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              color: AppColors.sellerNegative,
            ),
          );
        }
        final ins = result.valueOrNull!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (amount != null) ...[
              Text(
                tr(
                  'common.uzs_amount',
                  namedArgs: {'amount': formatSom(amount!)},
                ),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _WalletCardBlock(
              number: ins.cardNumber,
              holder: ins.cardHolder,
              bank: ins.bankName,
              onCopy: () => onCopyCard(ins.cardNumber),
            ),
            const SizedBox(height: 16),
            Text(
              tr('tariff.upload_screenshot_title'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('tariff.upload_screenshot_hint'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                color: c.grey,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : onPickScreenshot,
              icon: const Icon(Icons.image_outlined, size: 20),
              label: Text(
                screenshotFile == null
                    ? tr('tariff.upload_screenshot')
                    : tr('seller.ar_manual_receipt_selected'),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: c.divider),
              ),
            ),
            if (screenshotFile case final file?) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: c.positiveBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.positive.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: c.positive,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(
                          'seller.wallet_receipt_attached',
                          namedArgs: {'name': _receiptLabel(file)},
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (screenshotFile != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: (!busy && amountValid) ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sellerPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.sellerPrimary.withValues(
                      alpha: 0.35,
                    ),
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
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    tr('seller.ar_manual_submit'),
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _receiptLabel(File file) {
    final name = file.path.split('/').last;
    if (name.isNotEmpty) return name;
    return tr('seller.ar_manual_receipt_selected');
  }
}

class _WalletCardBlock extends StatelessWidget {
  const _WalletCardBlock({
    required this.number,
    required this.holder,
    required this.bank,
    required this.onCopy,
  });

  final String number;
  final String holder;
  final String bank;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.fillFaint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  number,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: 0.5,
                    color: c.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('tariff.tap_to_copy'),
                onPressed: onCopy,
                icon: Icon(Icons.copy_outlined, color: c.gold, size: 20),
              ),
            ],
          ),
          if (holder.isNotEmpty)
            Text(
              holder,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.grey,
              ),
            ),
          if (bank.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              bank,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                color: c.greyMid,
              ),
            ),
          ],
        ],
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
          TextButton(
            onPressed: onRetry,
            child: Text(tr('seller.reviews_retry')),
          ),
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
