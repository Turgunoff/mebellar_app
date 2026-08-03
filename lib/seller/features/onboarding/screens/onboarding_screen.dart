import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../auth/auth_bottom_sheet.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../../../shared/repositories/seller_onboarding_repository.dart';
import '../bloc/onboarding_bloc.dart';
import '../widgets/business_type_step.dart';
import '../widgets/document_upload_step.dart';
import '../widgets/done_step.dart';
import '../widgets/personal_info_step.dart';
import '../widgets/review_step.dart';
import '../widgets/shop_address_step.dart';
import '../widgets/shop_info_step.dart';
import '../widgets/step_indicator.dart';
import '../widgets/welcome_step.dart';
import 'seller_contract_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingBloc(
        sl<SellerOnboardingRepository>(),
        analytics: sl<AnalyticsService>(),
      )..add(const OnboardingStarted()),
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
      case OnboardingStep.documentUpload:
        return state.canAdvance;
      case OnboardingStep.businessType:
      case OnboardingStep.welcome:
      case OnboardingStep.review:
      case OnboardingStep.contract:
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

    // Backend submission fires from SellerContractScreen after scroll-to-accept.
    // documentUpload only advances into the contract step.
    if (state.step == OnboardingStep.businessType && !state.canAdvance) {
      return;
    }
    if (state.step == OnboardingStep.documentUpload && !state.canAdvance) {
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
    await showAuthScreen(context);
    if (!mounted) return;
    if (_isAuthenticated()) {
      context.read<OnboardingBloc>().add(const OnboardingNextStep());
    }
  }

  bool _isAuthenticated() {
    return sl.isRegistered<AuthRepository>() &&
        sl<AuthRepository>().isAuthenticated;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.error != null && state.status == OnboardingStatus.failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        final isDone = state.step == OnboardingStep.done;
        final isContract = state.step == OnboardingStep.contract;
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
              // The top close (X) button AND the Android system back/swipe both
              // EXIT the whole onboarding flow — back to the ProfileScreen that
              // launched it — instead of stepping back through the form. Only
              // the bottom "Back" button moves one step back now. No data is
              // cleared on exit: OnboardingBloc.close() flushes the Hive draft
              // on disposal, so reopening resumes exactly where the user left
              // off.
              canPop: true,
              child: Scaffold(
                // Default is true, but pin it explicitly: the form steps rely on
                // the body resizing so the keyboard-aware action bar (see
                // _BottomBar) can sit directly above the keyboard.
                resizeToAvoidBottomInset: true,
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: tr('common.close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text(tr('onboarding.title')),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(12),
                    child: OnboardingStepIndicator(
                      currentStep: state.step.index,
                      totalSteps: OnboardingStep.total - 1,
                    ),
                  ),
                ),
                body: GestureDetector(
                  // Tap anywhere outside the inputs to dismiss the keyboard.
                  // opaque so taps on the empty space between the form and the
                  // action bar still register; taps on a TextField win the arena
                  // and focus it as usual.
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const WelcomeStep(),
                      const BusinessTypeStep(),
                      PersonalInfoStep(formKey: _personalFormKey),
                      ShopInfoStep(formKey: _shopFormKey),
                      const ShopAddressStep(),
                      ReviewStep(
                        onEditStep: (step) => context
                            .read<OnboardingBloc>()
                            .add(OnboardingGoToStep(step)),
                      ),
                      const DocumentUploadStep(),
                      const SellerContractScreen(),
                      const DoneStep(),
                    ],
                  ),
                ),
                bottomNavigationBar: (isDone || isContract)
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
    final canAdvance = switch (state.step) {
      OnboardingStep.businessType => state.canAdvance,
      OnboardingStep.shopAddress => state.canAdvance,
      OnboardingStep.documentUpload => state.canAdvance,
      OnboardingStep.welcome => true,
      OnboardingStep.personalInfo => true,
      OnboardingStep.shopInfo => true,
      OnboardingStep.review => true,
      OnboardingStep.contract => false,
      OnboardingStep.done => false,
    };
    final isBusy = state.status == OnboardingStatus.submitting;

    final (String label, IconData icon) = switch (state.step) {
      OnboardingStep.review => (
        tr('onboarding.go_to_documents'),
        Iconsax.arrow_right_3_copy,
      ),
      OnboardingStep.documentUpload => (
        tr('onboarding.go_to_contract'),
        Iconsax.arrow_right_3_copy,
      ),
      _ => (tr('common.next'), Iconsax.arrow_right_3_copy),
    };

    // Fixed height ensures the Back and Next buttons never disagree, even
    // when localized labels are short on one side and long on the other.
    // Labels are forced to one line; FittedBox scales the text down if the
    // translation still doesn't fit at a glance.
    const double buttonHeight = 52;

    // Lift the action bar above the keyboard. A bottomNavigationBar is pinned
    // to the physical bottom and the keyboard overlays it by default, so without
    // this the Back/Next buttons hide behind the keyboard. viewInsets.bottom
    // tracks the keyboard height frame-by-frame, so the bar slides up in sync;
    // when the keyboard is closed it's 0 and SafeArea handles the home indicator.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (!isFirst)
                Expanded(
                  child: SizedBox(
                    height: buttonHeight,
                    child: OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : () => context.read<OnboardingBloc>().add(
                              const OnboardingPreviousStep(),
                            ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tr('common.back'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!isFirst) const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: FilledButton.icon(
                    onPressed: isBusy || !canAdvance
                        ? null
                        : () => widget.onNextPressed(state),
                    // While submitting the _FullScreenLoader overlay is already
                    // up — a second spinner inside the button reads as two
                    // competing loaders, so the button just sits disabled.
                    icon: Icon(icon),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
