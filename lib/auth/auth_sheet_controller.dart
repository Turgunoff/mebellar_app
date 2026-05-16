import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/service_locator.dart';
import '../core/logging/talker.dart';
import '../customer/features/profile/cubit/profile_cubit.dart';
import 'sheets/auth_sheet_kit.dart';

const int _resendSeconds = 120;

/// Lightweight orchestrator for the passwordless email-OTP sheet.
///
/// Owns the wizard step, the four text controllers, the loading/error state
/// and the resend timer, plus the three Supabase actions. The widget stays a
/// thin [ListenableBuilder] shell — it wires [onCompleted] (→ pop the sheet)
/// and [onMessage] (→ show a SnackBar) since those need a `BuildContext`.
class AuthSheetController extends ChangeNotifier {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();

  AuthStep _step = AuthStep.email;
  bool _isLoading = false;
  String? _errorMessage;
  int _secondsRemaining = 0;
  Timer? _resendTimer;
  bool _disposed = false;

  AuthStep get step => _step;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get secondsRemaining => _secondsRemaining;
  bool get canResend => _secondsRemaining == 0 && !_isLoading;

  /// Fired when authentication (and any new-user profile capture) completes.
  VoidCallback? onCompleted;

  /// Fired to surface a transient message as a SnackBar.
  void Function(String message, {required bool isError})? onMessage;

  String get remainingLabel {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  SupabaseClient? get _supabase =>
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null;

  // ---- Step actions ------------------------------------------------------

  Future<void> sendOtp({bool isResend = false}) async {
    talker.info('Button pressed: Kodni olish (isResend=$isResend)');
    if (_isLoading) {
      talker.warning('sendOtp ignored: already loading');
      return;
    }
    final email = emailCtrl.text.trim();
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
    _isLoading = true;
    _errorMessage = null;
    _notify();
    talker.info('Sending OTP request to: $email');
    try {
      // emailRedirectTo intentionally omitted — without it Supabase sends a
      // 6-digit OTP rather than a magic-link URL, matching this UI.
      await client.auth.signInWithOtp(email: email);
      talker.info('✓ OTP sent successfully to $email');
      otpCtrl.clear();
      _startResendTimer();
      _step = AuthStep.otp;
      _notify();
      if (isResend) _showInfo('Kod qaytadan yuborildi');
    } on AuthException catch (e, st) {
      talker.handle(e, st, 'Failed to send OTP (AuthException)');
      _setError(e.message);
    } catch (e, st) {
      talker.handle(e, st, 'Failed to send OTP');
      _setError("Kodni yuborib bo'lmadi. Internet aloqasini tekshiring");
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> verifyOtp() async {
    talker.info('Button pressed: Tasdiqlash');
    if (_isLoading) {
      talker.warning('verifyOtp ignored: already loading');
      return;
    }
    final email = emailCtrl.text.trim();
    final token = otpCtrl.text.trim();
    if (token.length != 6) {
      _setError('6 xonali kodni kiriting');
      return;
    }
    final client = _supabase;
    if (client == null) {
      _setError('Server sozlanmagan');
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    _notify();
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
      _resendTimer?.cancel();
      if (fullName != null && fullName.isNotEmpty) {
        onCompleted?.call();
      } else {
        _step = AuthStep.profile;
        _notify();
      }
    } on AuthException catch (e, st) {
      talker.handle(e, st, 'Failed to verify OTP (AuthException)');
      _setError(e.message);
    } catch (e, st) {
      talker.handle(e, st, 'Failed to verify OTP');
      _setError("Kod noto'g'ri yoki muddati o'tgan");
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> saveProfile() async {
    talker.info('Button pressed: Saqlash va kirish');
    if (_isLoading) {
      talker.warning('saveProfile ignored: already loading');
      return;
    }
    final name = nameCtrl.text.trim();
    final digits = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
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
    _isLoading = true;
    _errorMessage = null;
    _notify();
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
      // Push the new profile into the global cubit BEFORE completing so that
      // ProfileScreen rebuilds with the correct data the instant the sheet
      // closes — no separate fetch needed, and no race with userUpdated.
      if (sl.isRegistered<ProfileCubit>()) {
        sl<ProfileCubit>().applySignup(
          name: name,
          phone: phone,
          email: client.auth.currentUser?.email ?? '',
        );
      }
      onCompleted?.call();
    } on AuthException catch (e, st) {
      talker.handle(e, st, 'Failed to save profile (AuthException)');
      _setError(e.message);
    } catch (e, st) {
      talker.handle(e, st, 'Failed to save profile');
      _setError("Saqlab bo'lmadi");
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Back-navigation from the OTP step to the email step. Step 3 has no back —
  /// by then the user is already authenticated.
  void goBack() {
    if (_isLoading) return;
    if (_step == AuthStep.otp) {
      _resendTimer?.cancel();
      _step = AuthStep.email;
      _secondsRemaining = 0;
      _errorMessage = null;
      _notify();
    }
  }

  /// Stops the resend countdown — call before the widget pops the sheet.
  void cancelResendTimer() => _resendTimer?.cancel();

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  // ---- Helpers -----------------------------------------------------------

  void _startResendTimer() {
    _resendTimer?.cancel();
    _secondsRemaining = _resendSeconds;
    _notify();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        t.cancel();
        _secondsRemaining = 0;
      } else {
        _secondsRemaining--;
      }
      _notify();
    });
  }

  bool _isValidEmail(String value) {
    if (value.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  /// Surfaces an error inline (banner state) and via [onMessage] (SnackBar).
  void _setError(String msg) {
    _errorMessage = msg;
    _notify();
    onMessage?.call(msg, isError: true);
  }

  void _showInfo(String msg) => onMessage?.call(msg, isError: false);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _resendTimer?.cancel();
    emailCtrl.dispose();
    otpCtrl.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }
}
