import 'package:flutter/material.dart';

import '../core/theme/app_fonts.dart';
import 'auth_sheet_controller.dart';
import 'sheets/auth_error_banner.dart';
import 'sheets/auth_sheet_header.dart';
import 'sheets/auth_sheet_kit.dart';
import 'sheets/otp_step.dart';
import 'sheets/phone_step.dart';
import 'sheets/profile_step.dart';

/// Opens the passwordless phone-OTP authentication flow as a full screen.
///
/// Resolves to `true` when the user completed sign-in (and any first-time
/// profile capture for new users); `false` if the screen was closed (header
/// X or system back) before authentication finished. The Woody auth state
/// stream is the source of truth for session — callers typically just rebuild
/// on the stream and use the boolean only to decide post-success navigation.
///
/// Presented as a full-screen modal route on the ROOT navigator (so it covers
/// the bottom tab bar), not a bottom sheet. Closed via the header's X button.
Future<bool> showAuthScreen(BuildContext context) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => const _AuthScreen(),
    ),
  );
  return result ?? false;
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen();

  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  late final AuthSheetController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AuthSheetController()
      ..onCompleted = _handleCompleted
      ..onMessage = _handleMessage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCompleted() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
  }

  void _handleMessage(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: isError ? kDanger : kTerracotta,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _onAbort() {
    _controller.cancelResendTimer();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // System back / swipe acts like the header X — cancel and close.
        if (!didPop) _onAbort();
      },
      child: Scaffold(
        backgroundColor: t.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthSheetHeader(
                      step: _controller.step,
                      onBack: _controller.step == AuthStep.otp
                          ? _controller.goBack
                          : null,
                      onClose: _onAbort,
                    ),
                    const SizedBox(height: 28),
                    // Scrolls so the keyboard never overflows the content.
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.05, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey(_controller.step),
                                child: _buildBody(),
                              ),
                            ),
                            // OTP step shows its error inline under the pins,
                            // so the banner is for the phone/profile steps only.
                            if (_controller.errorMessage != null &&
                                _controller.step != AuthStep.otp) ...[
                              const SizedBox(height: 14),
                              AuthErrorBanner(
                                message: _controller.errorMessage!,
                                onDismiss: _controller.clearError,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.step) {
      case AuthStep.phone:
        return PhoneStep(
          controller: _controller.phoneCtrl,
          busy: _controller.isLoading,
          onSubmit: () => _controller.sendOtp(),
        );
      case AuthStep.otp:
        return OtpStep(
          destination: _controller.currentPhoneDisplay,
          controller: _controller.otpCtrl,
          busy: _controller.isLoading,
          onSubmit: _controller.verifyOtp,
          remainingLabel: _controller.remainingLabel,
          canResend: _controller.canResend,
          onResend: () => _controller.sendOtp(isResend: true),
          errorMessage: _controller.errorMessage,
        );
      case AuthStep.profile:
        return ProfileStep(
          nameController: _controller.nameCtrl,
          busy: _controller.isLoading,
          onSubmit: _controller.saveProfile,
        );
    }
  }
}
