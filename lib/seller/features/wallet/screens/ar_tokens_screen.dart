import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../products/data/ar_token_repository.dart';
import '../../products/widgets/ar_token_buy_sheet.dart';
import 'ar_token_purchase_history_screen.dart';

/// Dedicated AR-token wallet — the seller's token balance + the top-up flow.
///
/// This is the single home for buying AR tokens: the seller product detail
/// screen now only *shows* the balance, and all purchasing happens here. The
/// checkout deep-link is launched by [showArTokenBuySheet]; settlement is
/// reconciled globally by the app's PaymentRecoveryGate on return, so this
/// screen just refreshes the balance and reminds the seller to finish paying.
class ArTokensScreen extends StatefulWidget {
  const ArTokensScreen({super.key});

  @override
  State<ArTokensScreen> createState() => _ArTokensScreenState();
}

class _ArTokensScreenState extends State<ArTokensScreen> {
  ArTokenBalance? _balance;
  List<ArTokenPurchase> _recentPurchases = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final repo = sl<ArTokenRepository>();
      final results = await Future.wait([
        repo.balance(),
        repo.purchaseHistory(limit: 5),
      ]);
      if (mounted) {
        setState(() {
          _balance = results[0] as ArTokenBalance;
          _recentPurchases = results[1] as List<ArTokenPurchase>;
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

  Future<void> _openBuyTokens() async {
    final balance = _balance;
    if (balance == null) return;
    final started = await showArTokenBuySheet(
      context,
      packages: balance.packages,
    );
    if (!mounted || !started) return;
    await _load();
    if (!mounted) return;
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
          const SizedBox(height: 16),
          const _HowItWorksCard(),
          if (_recentPurchases.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RecentPurchasesCard(
              purchases: _recentPurchases,
              onViewAll: _openHistory,
            ),
          ],
          if (balance.packages.isNotEmpty) ...[
            const SizedBox(height: 16),
            _BuyButton(onPressed: _openBuyTokens),
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

/// Full-width gold CTA that opens the top-up sheet.
class _BuyButton extends StatelessWidget {
  const _BuyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.goldBright, c.gold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c.gold.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_rounded, size: 20, color: AppColors.sellerInk),
              const SizedBox(width: 10),
              Text(
                tr('seller.ar_buy_title'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.sellerInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPurchasesCard extends StatelessWidget {
  const _RecentPurchasesCard({
    required this.purchases,
    required this.onViewAll,
  });

  final List<ArTokenPurchase> purchases;
  final VoidCallback onViewAll;

  static final _uzs = NumberFormat('#,##0', 'uz_UZ');
  static final _when = DateFormat('d MMM, HH:mm');

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr('seller.ar_purchase_recent_title'),
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    tr('seller.ar_purchase_view_all'),
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w700,
                      color: c.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < purchases.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 52, color: c.divider),
            _RecentPurchaseRow(purchase: purchases[i], uzs: _uzs, when: _when),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RecentPurchaseRow extends StatelessWidget {
  const _RecentPurchaseRow({
    required this.purchase,
    required this.uzs,
    required this.when,
  });

  final ArTokenPurchase purchase;
  final NumberFormat uzs;
  final DateFormat when;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final statusColor = purchase.isPaid
        ? c.positive
        : purchase.isCancelled
        ? c.grey
        : c.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.goldBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bolt_rounded, size: 18, color: c.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'seller.ar_token_count',
                    namedArgs: {'count': '${purchase.tokens}'},
                  ),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                Text(
                  '${uzs.format(purchase.amountUzs)} ${tr('common.currency_uzs')}',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.grey,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                purchase.isPaid
                    ? tr('seller.ar_purchase_status_paid')
                    : purchase.isCancelled
                    ? tr('seller.ar_purchase_status_cancelled')
                    : tr('seller.ar_purchase_status_pending'),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              Text(
                when.format(purchase.createdAt.toLocal()),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: c.greyMid,
                ),
              ),
            ],
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
