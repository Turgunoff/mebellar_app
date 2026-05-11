import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../auth/auth_bottom_sheet.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../../../shared/repositories/seller_onboarding_repository.dart';
import '../bloc/onboarding_bloc.dart';
import '../widgets/business_type_step.dart';
import '../widgets/done_step.dart';
import '../widgets/personal_info_step.dart';
import '../widgets/review_step.dart';
import '../widgets/shop_address_step.dart';
import '../widgets/shop_info_step.dart';
import '../widgets/step_indicator.dart';
import '../widgets/welcome_step.dart';
import 'document_upload_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          OnboardingBloc(sl<SellerOnboardingRepository>())
            ..add(const OnboardingStarted()),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final PageController _pageController = PageController();
  final GlobalKey<FormState> _personalFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _shopFormKey = GlobalKey<FormState>();
  int? _lastSyncedStep;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _syncPage(int targetIndex) {
    if (!_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPage(targetIndex);
      });
      return;
    }
    final current = _pageController.page?.round();
    if (current == targetIndex) return;
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<bool> _validateCurrentStep(OnboardingState state) async {
    switch (state.step) {
      case OnboardingStep.personalInfo:
        return _personalFormKey.currentState?.validate() ?? false;
      case OnboardingStep.shopInfo:
        return _shopFormKey.currentState?.validate() ?? false;
      case OnboardingStep.shopAddress:
        return state.canAdvance;
      case OnboardingStep.businessType:
      case OnboardingStep.welcome:
      case OnboardingStep.review:
      case OnboardingStep.done:
        return true;
    }
  }

  Future<void> _handleNext(OnboardingState state) async {
    final bloc = context.read<OnboardingBloc>();
    final isFirst = state.step == OnboardingStep.welcome;

    if (state.step == OnboardingStep.personalInfo ||
        state.step == OnboardingStep.shopInfo ||
        state.step == OnboardingStep.shopAddress ||
        state.step == OnboardingStep.businessType) {
      final valid = await _validateCurrentStep(state);
      if (!valid) return;
    }

    if (state.step == OnboardingStep.review) {
      bloc.add(const OnboardingSubmitted());
      return;
    }

    if (state.step == OnboardingStep.businessType && !state.canAdvance) {
      return;
    }

    if (!isFirst) {
      bloc.add(const OnboardingNextStep());
      return;
    }

    if (_isAuthenticated()) {
      bloc.add(const OnboardingNextStep());
      return;
    }

    await _promptAuthAndAdvance();
  }

  Future<void> _promptAuthAndAdvance() async {
    await showAuthBottomSheet(context);
    if (!mounted) return;
    if (_isAuthenticated()) {
      context.read<OnboardingBloc>().add(const OnboardingNextStep());
    }
  }

  bool _isAuthenticated() {
    if (!sl.isRegistered<SupabaseClient>()) return false;
    return sl<SupabaseClient>().auth.currentUser != null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        // Handle error
        if (state.error != null && state.status == OnboardingStatus.failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }

        // Handle navigation to document upload screen
        if (state.status == OnboardingStatus.navigateDocuments &&
            state.shopId != null &&
            state.draft.businessType != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DocumentUploadScreen(
                shopId: state.shopId!,
                businessType: state.draft.businessType!,
                onSubmit: () {
                  // After documents submitted, navigate to dashboard
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isDone = state.step == OnboardingStep.done;
        final isSubmitting = state.status == OnboardingStatus.submitting;
        if (_lastSyncedStep != state.step.index) {
          _lastSyncedStep = state.step.index;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncPage(state.step.index);
          });
        }
        return Stack(
          children: [
            PopScope(
              canPop: state.step == OnboardingStep.welcome || isDone,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                context.read<OnboardingBloc>().add(
                  const OnboardingPreviousStep(),
                );
              },
              child: Scaffold(
                appBar: AppBar(
                  title: Text(tr('onboarding.title')),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(12),
                    child: OnboardingStepIndicator(
                      currentStep: state.step.index,
                      totalSteps: OnboardingStep.total - 1,
                    ),
                  ),
                ),
                body: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    const WelcomeStep(),
                    const BusinessTypeStep(),
                    PersonalInfoStep(formKey: _personalFormKey),
                    ShopInfoStep(formKey: _shopFormKey),
                    const ShopAddressStep(),
                    ReviewStep(
                      onEditStep: (step) => context.read<OnboardingBloc>().add(
                        OnboardingGoToStep(step),
                      ),
                    ),
                    const DoneStep(),
                  ],
                ),
                bottomNavigationBar: isDone
                    ? null
                    : _BottomBar(state: state, onNextPressed: _handleNext),
              ),
            ),
            if (isSubmitting) const _FullScreenLoader(),
          ],
        );
      },
    );
  }
}

class _BottomBar extends StatefulWidget {
  const _BottomBar({required this.state, required this.onNextPressed});
  final OnboardingState state;
  final Future<void> Function(OnboardingState state) onNextPressed;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isFirst = state.step == OnboardingStep.welcome;
    final isLast = state.step == OnboardingStep.review;
    final canAdvance = switch (state.step) {
      OnboardingStep.businessType => state.canAdvance,
      OnboardingStep.shopAddress => state.canAdvance,
      OnboardingStep.welcome => true,
      OnboardingStep.personalInfo => true,
      OnboardingStep.shopInfo => true,
      OnboardingStep.review => true,
      OnboardingStep.done => false,
    };
    final isBusy = state.status == OnboardingStatus.submitting;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (!isFirst)
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy
                      ? null
                      : () => context.read<OnboardingBloc>().add(
                          const OnboardingPreviousStep(),
                        ),
                  child: Text(tr('common.back')),
                ),
              ),
            if (!isFirst) const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isBusy || !canAdvance
                    ? null
                    : () => widget.onNextPressed(state),
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isLast ? Icons.send_outlined : Icons.arrow_forward),
                label: Text(
                  isLast ? tr('onboarding.submit') : tr('common.next'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: PremiumTokens.accent,
          strokeWidth: 3,
        ),
      ),
    );
  }
}
