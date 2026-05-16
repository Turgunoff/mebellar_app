import 'package:flutter/material.dart';

import '../core/theme/app_fonts.dart';
import 'auth_sheet_controller.dart';
import 'sheets/auth_error_banner.dart';
import 'sheets/auth_sheet_header.dart';
import 'sheets/auth_sheet_kit.dart';
import 'sheets/email_step.dart';
import 'sheets/otp_step.dart';
import 'sheets/profile_step.dart';

/// Opens the passwordless email-OTP authentication flow as a bottom sheet.
///
/// Resolves to `true` when the user completed sign-in (and any first-time
/// profile capture for new users); `false` if the sheet was dismissed before
/// authentication finished. Supabase's auth state stream is the source of
/// truth for session — callers typically just rebuild on the stream and use
/// the boolean only to decide post-success navigation.
///
/// ROADMAP B.4 — the original 1,154-line file was split: the three wizard
/// steps live under `auth/sheets/`, the flow logic in [AuthSheetController].
Future<bool> showAuthBottomSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _AuthBottomSheet(),
  );
  return result ?? false;
}

class _AuthBottomSheet extends StatefulWidget {
  const _AuthBottomSheet();

  @override
  State<_AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<_AuthBottomSheet> {
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
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AuthGrabber(),
                      const SizedBox(height: 8),
                      AuthSheetHeader(
                        step: _controller.step,
                        onBack: _controller.step == AuthStep.otp
                            ? _controller.goBack
                            : null,
                        onClose: _onAbort,
                      ),
                      const SizedBox(height: 18),
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
                      if (_controller.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        AuthErrorBanner(
                          message: _controller.errorMessage!,
                          onDismiss: _controller.clearError,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.step) {
      case AuthStep.email:
        return EmailStep(
          controller: _controller.emailCtrl,
          busy: _controller.isLoading,
          onSubmit: () => _controller.sendOtp(),
        );
      case AuthStep.otp:
        return OtpStep(
          email: _controller.emailCtrl.text.trim(),
          controller: _controller.otpCtrl,
          busy: _controller.isLoading,
          onSubmit: _controller.verifyOtp,
          remainingLabel: _controller.remainingLabel,
          canResend: _controller.canResend,
          onResend: () => _controller.sendOtp(isResend: true),
        );
      case AuthStep.profile:
        return ProfileStep(
          nameController: _controller.nameCtrl,
          phoneController: _controller.phoneCtrl,
          busy: _controller.isLoading,
          onSubmit: _controller.saveProfile,
        );
    }
  }
}
