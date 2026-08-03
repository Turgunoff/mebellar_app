import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../bloc/onboarding_bloc.dart';
import '../constants/seller_contract_oferta.dart';
import '../widgets/onboarding_kit.dart';

/// Seller public-offer (ommaviy oferta) screen.
///
/// * Onboarding (default): scroll-to-accept + submit via [OnboardingBloc].
/// * Profile (`isReadOnly: true`): scrollable A4 document only — no accept
///   CTA and no scroll gate. Optionally pass [sellerName] to personalize §1.1.
class SellerContractScreen extends StatelessWidget {
  const SellerContractScreen({
    super.key,
    this.isReadOnly = false,
    this.sellerName = '',
  });

  final bool isReadOnly;
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    if (isReadOnly) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tr('seller.profile_contract_title')),
        ),
        body: _SellerContractBody(
          isReadOnly: true,
          sellerName: sellerName,
        ),
      );
    }

    return StepActivation(
      step: OnboardingStep.contract,
      builder: (context, animation) {
        return FadeTransition(
          opacity: animation,
          child: const _SellerContractBody(isReadOnly: false),
        );
      },
    );
  }
}

class _SellerContractBody extends StatefulWidget {
  const _SellerContractBody({
    required this.isReadOnly,
    this.sellerName = '',
  });

  final bool isReadOnly;
  final String sellerName;

  @override
  State<_SellerContractBody> createState() => _SellerContractBodyState();
}

class _SellerContractBodyState extends State<_SellerContractBody> {
  final ScrollController _scrollController = ScrollController();
  bool _hasReachedBottom = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isReadOnly) {
      _scrollController.addListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollExtent());
    }
  }

  @override
  void dispose() {
    if (!widget.isReadOnly) {
      _scrollController.removeListener(_onScroll);
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasReachedBottom || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 50) {
      setState(() => _hasReachedBottom = true);
    }
  }

  void _checkScrollExtent() {
    if (!mounted || !_scrollController.hasClients || _hasReachedBottom) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 50) {
      setState(() => _hasReachedBottom = true);
    }
  }

  String _resolveSellerName(BuildContext context) {
    if (widget.sellerName.trim().isNotEmpty) return widget.sellerName.trim();
    if (widget.isReadOnly) return '';
    final draft = context.select((OnboardingBloc b) => b.state.draft);
    if (draft.legalName?.trim().isNotEmpty ?? false) {
      return draft.legalName!.trim();
    }
    if (draft.shopNameUz?.trim().isNotEmpty ?? false) {
      return draft.shopNameUz!.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final isSubmitting = widget.isReadOnly
        ? false
        : context.select(
            (OnboardingBloc b) => b.state.status == OnboardingStatus.submitting,
          );
    final sellerName = _resolveSellerName(context);

    final bodyStyle = TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 14,
      height: 1.55,
      color: const Color(0xFF1A1A1A),
      fontWeight: FontWeight.w400,
    );
    final boldStyle = bodyStyle.copyWith(fontWeight: FontWeight.w700);
    final headingStyle = bodyStyle.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.35,
      letterSpacing: 0.2,
    );
    final sectionStyle = bodyStyle.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.4,
    );

    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: pt.background,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (!widget.isReadOnly) ...[
                  Text(
                    tr('onboarding.step_contract_title'),
                    style: PremiumTokens.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: pt.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('onboarding.step_contract_subtitle'),
                    style: PremiumTokens.body(size: 12, color: pt.grey),
                  ),
                  const SizedBox(height: 16),
                ],
                // A4 paper illusion: white sheet, soft drop shadow, page margins.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
                    child: Text.rich(
                      TextSpan(
                        children: buildSellerContractSpans(
                          sellerName: sellerName,
                          body: bodyStyle,
                          bold: boldStyle,
                          heading: headingStyle,
                          section: sectionStyle,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!widget.isReadOnly && !_hasReachedBottom) ...[
                  const SizedBox(height: 16),
                  Text(
                    tr('onboarding.contract_scroll_hint'),
                    textAlign: TextAlign.center,
                    style: PremiumTokens.body(size: 12, color: pt.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!widget.isReadOnly)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () => context.read<OnboardingBloc>().add(
                                  const OnboardingPreviousStep(),
                                ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        child: Text(tr('common.back')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: (!_hasReachedBottom || isSubmitting)
                            ? null
                            : () => context.read<OnboardingBloc>().add(
                                  const OnboardingSubmitted(),
                                ),
                        style: FilledButton.styleFrom(
                          backgroundColor: PremiumTokens.accent,
                          disabledBackgroundColor:
                              pt.grey.withValues(alpha: 0.28),
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.85),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          tr('onboarding.contract_accept'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: PremiumTokens.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
