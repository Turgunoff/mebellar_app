import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/payments/manual_payment_pending_screen.dart';
import '../../../../shared/payments/payment_pending_copy.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/seller_payment_refresh.dart';
import '../../products/data/ar_token_repository.dart';
import '../../products/widgets/ar_token_buy_section.dart';
import 'ar_token_purchase_history_screen.dart';

/// Dedicated AR-token wallet — balance, inline purchase, and history.
class ArTokensScreen extends StatefulWidget {
  const ArTokensScreen({super.key});

  @override
  State<ArTokensScreen> createState() => _ArTokensScreenState();
}

class _ArTokensScreenState extends State<ArTokensScreen>
    with WidgetsBindingObserver {
  ArTokenBalance? _balance;
  bool _loading = true;
  bool _failed = false;
  StreamSubscription<PendingPaymentKind>? _refreshSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSub = SellerPaymentRefreshHub.instance.stream.listen((kind) {
      if (kind == PendingPaymentKind.arTokens && mounted) {
        unawaited(_load());
      }
    });
    _load();
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final balance = await sl<ArTokenRepository>().balance();
      if (mounted) {
        setState(() {
          _balance = balance;
          _loading = false;
        });
      }
    } catch (e, st) {
      appLog.handle(e, st, '[ar-tokens] balance load failed');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _onOnlineLaunched() {
    if (!mounted) return;
    _load();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(tr('seller.ar_tokens_finish_payment_notice'))),
      );
  }

  void _openHistory() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/ar-token-purchase-history'),
            builder: (_) => const ArTokenPurchaseHistoryScreen(),
          ),
        )
        .then((_) {
          if (mounted) _load();
        });
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
        title: Text(
          tr('seller.profile_ar_tokens_title'),
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
            tooltip: tr('seller.ar_purchase_history_title'),
            onPressed: _openHistory,
            icon: Icon(Icons.history_rounded, color: c.ink),
          ),
        ],
      ),
      body: _buildBody(c),
    );
  }

  Widget _buildBody(SellerColors c) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed || _balance == null) {
      return _ErrorView(onRetry: _load);
    }
    final balance = _balance!;
    return RefreshIndicator(
      color: AppColors.sellerPrimary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          _BalanceCard(credits: balance.arCredits),
          if (balance.pendingPurchase != null) ...[
            const SizedBox(height: 12),
            _PendingPurchaseBanner(
              purchase: balance.pendingPurchase!,
              onReturned: _load,
            ),
          ],
          const SizedBox(height: 16),
          const _HowItWorksCard(),
          if (balance.packages.isNotEmpty &&
              balance.pendingPurchase == null) ...[
            const SizedBox(height: 16),
            ArTokenBuySection(
              packages: balance.packages,
              onOnlineLaunched: _onOnlineLaunched,
              onFlowCompleted: _load,
            ),
          ],
          if (balance.pendingPurchase != null) ...[
            const SizedBox(height: 16),
            _PendingPurchaseLockedCard(
              purchase: balance.pendingPurchase!,
              onReturned: _load,
            ),
          ],
        ],
      ),
    );
  }
}

/// Gold "token card face" — mirrors the wallet balance card's premium chrome but
/// in the AR-token gold currency. Decorative, so it keeps white text on the gold
/// gradient in both light and dark.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.credits});

  final int credits;

  static const _gradient = <Color>[
    Color(0xFFB67A1E),
    Color(0xFFD9A02C),
    Color(0xFFF0C04A),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _gradient[1].withValues(alpha: 0.32),
            blurRadius: 20,
            spreadRadius: -6,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -24,
              child: _Bloom(
                size: 120,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tr('seller.ar_tokens_available_tokens'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.bolt_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AR',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$credits',
                        style: const TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          tr('seller.ar_tokens_token_unit'),
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
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

/// Explains the token economy so the seller knows what they're buying: the first
/// scan per part is free, a rescan spends one token.
class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
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
            tr('seller.ar_tokens_what_for_title'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          _Bullet(
            color: c.gold,
            text: tr('seller.ar_tokens_bullet_first_scan_free'),
          ),
          const SizedBox(height: 10),
          _Bullet(
            color: c.gold,
            text: tr('seller.ar_tokens_bullet_rescan_cost'),
          ),
          const SizedBox(height: 10),
          _Bullet(
            color: c.gold,
            text: tr('seller.ar_tokens_bullet_shared_pool'),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.bolt_rounded, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: c.grey,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingPurchaseBanner extends StatelessWidget {
  const _PendingPurchaseBanner({
    required this.purchase,
    required this.onReturned,
  });

  final ArTokenPurchase purchase;
  final VoidCallback onReturned;

  void _openPending(BuildContext context) {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/seller-ar-token-pending'),
            builder: (_) => ManualPaymentPendingScreen(
              args: ArTokenPurchasePendingArgs(purchase: purchase),
            ),
          ),
        )
        .then((_) => onReturned());
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final manualReview = isManualPaymentReview(
      provider: purchase.provider,
      status: purchase.status,
    );
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
                    manualReview: manualReview,
                    amountSom: purchase.amountUzs,
                    tokenCount: purchase.tokens,
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

/// Replaces the buy block while a purchase is in flight — mirrors tariff's
/// disabled "Tasdiqlash kutilmoqda" CTA.
class _PendingPurchaseLockedCard extends StatelessWidget {
  const _PendingPurchaseLockedCard({
    required this.purchase,
    required this.onReturned,
  });

  final ArTokenPurchase purchase;
  final VoidCallback onReturned;

  void _openPending(BuildContext context) {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/seller-ar-token-pending'),
            builder: (_) => ManualPaymentPendingScreen(
              args: ArTokenPurchasePendingArgs(purchase: purchase),
            ),
          ),
        )
        .then((_) => onReturned());
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final manualReview = isManualPaymentReview(
      provider: purchase.provider,
      status: purchase.status,
    );
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
            tr('seller.ar_buy_title'),
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
              disabledBackgroundColor: c.divider,
              disabledForegroundColor: c.greyMid,
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
          Icon(Icons.wifi_off_rounded, color: c.greyMid, size: 36),
          const SizedBox(height: 10),
          Text(
            tr('seller.ar_tokens_load_failed'),
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
