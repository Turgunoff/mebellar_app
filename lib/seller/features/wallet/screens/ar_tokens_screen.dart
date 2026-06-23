import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../products/data/ar_token_repository.dart';
import '../../products/widgets/ar_token_buy_sheet.dart';

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
      final balance = await sl<ArTokenRepository>().balance();
      if (mounted) {
        setState(() {
          _balance = balance;
          _loading = false;
        });
      }
    } catch (e, st) {
      talker.handle(e, st, '[ar-tokens] balance load failed');
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
        const SnackBar(
          content: Text(
            'To‘lovni ilovada yakunlang — tasdiqlangach tokenlar qo‘shiladi.',
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
        title: Text(
          'AR Tokenlar',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        iconTheme: IconThemeData(color: c.ink),
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
          const SizedBox(height: 20),
          const _HowItWorksCard(),
          if (balance.packages.isNotEmpty) ...[
            const SizedBox(height: 20),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _gradient[1].withValues(alpha: 0.38),
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
            Positioned(
              top: -50,
              right: -30,
              child: _Bloom(
                size: 150,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -20,
              child: _Bloom(
                size: 140,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Mavjud tokenlar',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.bolt_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AR',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.9),
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
                      Text(
                        '$credits',
                        style: const TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          'token',
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 16,
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
            'Tokenlar nima uchun?',
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
            text: 'Har bir mahsulot qismi uchun birinchi 3D skan — bepul.',
          ),
          const SizedBox(height: 10),
          _Bullet(
            color: c.gold,
            text: 'Qismni qayta skanlash 1 token sarflaydi.',
          ),
          const SizedBox(height: 10),
          _Bullet(
            color: c.gold,
            text:
                'Tokenlar do‘konning barcha mahsulotlari uchun umumiy — bir '
                'marta sotib oling, xohlagan mahsulotga ishlating.',
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
                'AR Token sotib olish',
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
            'Token balansini yuklab bo‘lmadi',
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
