import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/service_locator.dart';
import '../core/logging/talker.dart';
import '../customer/features/profile/cubit/profile_cubit.dart';

const _terracotta = Color(0xFFC27A5F);
const _terracottaDeep = Color(0xFFB85C38);
const _surface = Color(0xFFFFFFFF);
const _fieldFill = Color(0xFFFAFAFA);
const _textPrimary = Color(0xFF1D1D1D);
const _textSecondary = Color(0xFF757575);
const _border = Color(0xFFEAEAEA);
const _danger = Color(0xFFEF4444);

const _resendSeconds = 120;

/// Opens the passwordless email-OTP authentication flow as a bottom sheet.
///
/// Resolves to `true` when the user completed sign-in (and any first-time
/// profile capture for new users); `false` if the sheet was dismissed before
/// authentication finished. Supabase's auth state stream is the source of
/// truth for session — callers typically just rebuild on the stream and use
/// the boolean only to decide post-success navigation.
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

enum _Step { email, otp, profile }

class _AuthBottomSheet extends StatefulWidget {
  const _AuthBottomSheet();

  @override
  State<_AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<_AuthBottomSheet> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  _Step _step = _Step.email;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  SupabaseClient? get _supabase =>
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null;

  // ---- Step actions ------------------------------------------------------

  Future<void> _sendOtp({bool isResend = false}) async {
    talker.info('Button pressed: Kodni olish (isResend=$isResend)');
    if (_isLoading) {
      talker.warning('_sendOtp ignored: already loading');
      return;
    }
    final email = _emailCtrl.text.trim();
    if (!_isValidEmail(email)) {
      _setError("To'g'ri email manzilini kiriting");
      return;
    }
    final client = _supabase;
    if (client == null) {
      _setError("Server sozlanmagan. Iltimos, ilovani qayta ishga tushiring");
      talker.warning('signInWithOtp aborted: SupabaseClient not registered');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    talker.info('Sending OTP request to: $email');
    try {
      // emailRedirectTo intentionally omitted — without it Supabase sends a
      // 6-digit OTP rather than a magic-link URL, matching this UI.
      await client.auth.signInWithOtp(email: email);
      talker.info('✓ OTP sent successfully to $email');
      _otpCtrl.clear();
      _startResendTimer();
      if (!mounted) return;
      setState(() => _step = _Step.otp);
      if (isResend) _showInfo('Kod qaytadan yuborildi');
    } on AuthException catch (e, st) {
      talker.handle(e, st, 'Failed to send OTP (AuthException)');
      _setError(e.message);
    } catch (e, st) {
      talker.handle(e, st, 'Failed to send OTP');
      _setError("Kodni yuborib bo'lmadi. Internet aloqasini tekshiring");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    talker.info('Button pressed: Tasdiqlash');
    if (_isLoading) {
      talker.warning('_verifyOtp ignored: already loading');
      return;
    }
    final email = _emailCtrl.text.trim();
    final token = _otpCtrl.text.trim();
    if (token.length != 6) {
      _setError('6 xonali kodni kiriting');
      return;
    }
    final client = _supabase;
    if (client == null) {
      _setError('Server sozlanmagan');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    talker.info('Verifying OTP for: $email');
    try {
      final response = await client.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: token,
      );
      final fullName =
          (response.user?.userMetadata?['full_name'] as String?)?.trim();
      talker.info('✓ OTP verified for $email (returning user: '
          '${fullName != null && fullName.isNotEmpty})');
      if (!mounted) return;
      _resendTimer?.cancel();
      if (fullName != null && fullName.isNotEmpty) {
        Navigator.of(context, rootNavigator: true).pop(true);
      } else {
        setState(() => _step = _Step.profile);
      }
    } on AuthException catch (e, st) {
      talker.handle(e, st, 'Failed to verify OTP (AuthException)');
      _setError(e.message);
    } catch (e, st) {
      talker.handle(e, st, 'Failed to verify OTP');
      _setError("Kod noto'g'ri yoki muddati o'tgan");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    talker.info('Button pressed: Saqlash va kirish');
    if (_isLoading) {
      talker.warning('_saveProfile ignored: already loading');
      return;
    }
    final name = _nameCtrl.text.trim();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (name.length < 2) {
      _setError("Ism va familiyangizni to'liq kiriting");
      return;
    }
    if (digits.length != 9) {
      _setError("Telefon raqamni to'liq kiriting");
      return;
    }
    final phone = '+998$digits';
    final client = _supabase;
    if (client == null) {
      _setError('Server sozlanmagan');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    talker.info('Saving profile metadata for new user');
    try {
      await client.auth.updateUser(
        UserAttributes(data: {'full_name': name, 'phone': phone}),
      );
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.from('profiles').upsert({
          'id': userId,
          'full_name': name,
          'phone': phone,
        });
      }
      talker.info('✓ Profile metadata and public.profiles updated');
      // Push the new profile into the global cubit BEFORE popping so that
      // ProfileScreen rebuilds with the correct data the instant the sheet
      // closes — no separate fetch needed, and no race with userUpdated.
      if (sl.isRegistered<ProfileCubit>()) {
        sl<ProfileCubit>().applySignup(
          name: name,
          phone: phone,
          email: client.auth.currentUser?.email ?? '',
        );
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(true);
    } on AuthException catch (e, st) {
      talker.handle(e, st, 'Failed to save profile (AuthException)');
      _setError(e.message);
    } catch (e, st) {
      talker.handle(e, st, 'Failed to save profile');
      _setError("Saqlab bo'lmadi");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- Timer -------------------------------------------------------------

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        t.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String get _remainingLabel {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---- Helpers -----------------------------------------------------------

  bool _isValidEmail(String value) {
    if (value.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  /// Surfaces an error in two places: an inline banner inside the sheet (so
  /// it's visible even when the SnackBar would render behind the modal) and
  /// a SnackBar via the root ScaffoldMessenger as a fallback.
  void _setError(String msg) {
    if (!mounted) return;
    setState(() => _errorMessage = msg);
    _showSnack(msg, _danger);
  }

  void _showInfo(String msg) => _showSnack(msg, _terracotta);

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _onAbort() {
    _resendTimer?.cancel();
    Navigator.of(context).pop(false);
  }

  void _onBackTapped() {
    if (_isLoading) return;
    if (_step == _Step.otp) {
      _resendTimer?.cancel();
      setState(() {
        _step = _Step.email;
        _secondsRemaining = 0;
        _errorMessage = null;
      });
    }
    // Step 3 has no back: the user is already authenticated by then; going
    // back wouldn't undo the session, so we just don't expose a back arrow.
  }

  // ---- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Grabber(),
                  const SizedBox(height: 8),
                  _SheetHeader(
                    step: _step,
                    onBack: _step == _Step.otp ? _onBackTapped : null,
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
                      key: ValueKey(_step),
                      child: _buildBody(),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(
                      message: _errorMessage!,
                      onDismiss: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.email:
        return _EmailStep(
          controller: _emailCtrl,
          busy: _isLoading,
          onSubmit: () => _sendOtp(),
        );
      case _Step.otp:
        return _OtpStep(
          email: _emailCtrl.text.trim(),
          controller: _otpCtrl,
          busy: _isLoading,
          onSubmit: _verifyOtp,
          remainingLabel: _remainingLabel,
          canResend: _secondsRemaining == 0 && !_isLoading,
          onResend: () => _sendOtp(isResend: true),
        );
      case _Step.profile:
        return _ProfileStep(
          nameController: _nameCtrl,
          phoneController: _phoneCtrl,
          busy: _isLoading,
          onSubmit: _saveProfile,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Header / chrome
// ---------------------------------------------------------------------------

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: _border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.step, this.onBack, this.onClose});

  final _Step step;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _IconBtn(
                icon: Icons.arrow_back_rounded,
                onTap: onBack!,
              ),
            ),
          if (onClose != null)
            Align(
              alignment: Alignment.centerRight,
              child: _IconBtn(
                icon: Icons.close_rounded,
                onTap: onClose!,
              ),
            ),
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final active = i == step.index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? _terracotta : _border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _fieldFill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: _textPrimary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Email
// ---------------------------------------------------------------------------

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tizimga kirish', style: _titleStyle()),
        const SizedBox(height: 8),
        Text(
          'Email manzilingizni kiriting. Tasdiqlash kodini yuboramiz.',
          style: _subtitleStyle(),
        ),
        const SizedBox(height: 24),
        _Label('Email'),
        const SizedBox(height: 8),
        _OutlinedField(
          controller: controller,
          hintText: 'siz@misol.uz',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          enabled: !busy,
          autofocus: true,
          onSubmitted: (_) => busy ? null : onSubmit(),
        ),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: 'Kodni olish',
          busy: busy,
          onTap: busy ? null : onSubmit,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — OTP
// ---------------------------------------------------------------------------

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.email,
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.remainingLabel,
    required this.canResend,
    required this.onResend,
  });

  final String email;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final String remainingLabel;
  final bool canResend;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Kodni kiriting', style: _titleStyle()),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: _subtitleStyle(),
            children: [
              const TextSpan(text: '6 xonali kod '),
              TextSpan(
                text: email,
                style: _subtitleStyle().copyWith(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' manziliga yuborildi.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _PinField(
          controller: controller,
          enabled: !busy,
          onCompleted: onSubmit,
        ),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: 'Tasdiqlash',
          busy: busy,
          onTap: busy ? null : onSubmit,
        ),
        const SizedBox(height: 14),
        Center(
          child: canResend
              ? TextButton(
                  onPressed: onResend,
                  style: TextButton.styleFrom(
                    foregroundColor: _terracotta,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Kodni qayta yuborish',
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _terracotta,
                    ),
                  ),
                )
              : Text(
                  'Kodni qayta yuborish ($remainingLabel)',
                  style: TextStyle(fontFamily: AppFonts.seller, 
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PinField extends StatefulWidget {
  const _PinField({
    required this.controller,
    required this.enabled,
    required this.onCompleted,
  });

  static const int length = 6;

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onCompleted;

  @override
  State<_PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<_PinField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handle);
    _focus.addListener(_handleFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handle);
    _focus.removeListener(_handleFocus);
    _focus.dispose();
    super.dispose();
  }

  void _handle() {
    setState(() {});
    if (widget.controller.text.length == _PinField.length) {
      widget.onCompleted();
    }
  }

  void _handleFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          // Source-of-truth input. Visually invisible (transparent text + no
          // cursor + no border) but receives keystrokes and IME paste, which
          // a row of N TextFields cannot do reliably.
          Positioned.fill(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: _PinField.length,
              showCursor: false,
              cursorWidth: 0,
              style: const TextStyle(color: Colors.transparent, height: 0.01),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_PinField.length, (i) {
                final filled = i < value.length;
                final isCursor = i == value.length && _focus.hasFocus;
                final ch = filled ? value[i] : '';
                return _PinBox(
                  digit: ch,
                  active: isCursor,
                  filled: filled,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinBox extends StatelessWidget {
  const _PinBox({
    required this.digit,
    required this.active,
    required this.filled,
  });

  final String digit;
  final bool active;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || filled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 48,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? _surface : _fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? _terracotta : _border,
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: Text(
        digit,
        style: TextStyle(fontFamily: AppFonts.seller, 
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Profile (new user)
// ---------------------------------------------------------------------------

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.nameController,
    required this.phoneController,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tanishing, siz kimsiz?', style: _titleStyle()),
        const SizedBox(height: 8),
        Text(
          'Tizimda sizga murojaat qilishimiz uchun.',
          style: _subtitleStyle(),
        ),
        const SizedBox(height: 24),
        _Label('Ism va familiya'),
        const SizedBox(height: 8),
        _OutlinedField(
          controller: nameController,
          hintText: 'Aliyev Akmal',
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          enabled: !busy,
          autofocus: true,
        ),
        const SizedBox(height: 18),
        _Label('Telefon raqami'),
        const SizedBox(height: 8),
        _PhoneField(controller: phoneController, enabled: !busy),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: 'Saqlash va kirish',
          busy: busy,
          onTap: busy ? null : onSubmit,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
            child: Text(
              '+998',
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
          Container(width: 1, height: 24, color: _border),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
                _UzPhoneFormatter(),
              ],
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: InputBorder.none,
                hintText: '90 123 45 67',
                hintStyle: TextStyle(fontFamily: AppFonts.seller, 
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// Formats raw 9-digit national numbers as `XX XXX XX XX`. The formatter
/// preserves only digits in the underlying value, so callers should still
/// strip non-digits when reading [TextEditingController.text] for the API.
class _UzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 9; i++) {
      if (i == 2 || i == 5 || i == 7) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared field / button atoms
// ---------------------------------------------------------------------------

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontFamily: AppFonts.seller, 
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _OutlinedField extends StatelessWidget {
  const _OutlinedField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: TextStyle(fontFamily: AppFonts.seller, 
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: _fieldFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintText: hintText,
        hintStyle: TextStyle(fontFamily: AppFonts.seller, 
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: _textSecondary,
        ),
        border: border(_border, 1),
        enabledBorder: border(_border, 1),
        focusedBorder: border(_terracotta, 1.6),
        disabledBorder: border(_border, 1),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return SizedBox(
      height: 54,
      child: Material(
        color: disabled
            ? _terracotta.withValues(alpha: 0.55)
            : _terracotta,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: _terracottaDeep.withValues(alpha: 0.3),
          highlightColor: _terracottaDeep.withValues(alpha: 0.15),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline error banner — anchored inside the sheet so the message stays
// visible even when a SnackBar would render behind the modal route.
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: _danger.withValues(alpha: 0.08),
        border: Border.all(color: _danger.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _danger,
                height: 1.35,
              ),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: _danger, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typography helpers
// ---------------------------------------------------------------------------

TextStyle _titleStyle() => TextStyle(fontFamily: AppFonts.seller, 
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: _textPrimary,
      letterSpacing: -0.3,
      height: 1.2,
    );

TextStyle _subtitleStyle() => TextStyle(fontFamily: AppFonts.seller, 
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: _textSecondary,
      height: 1.45,
    );
