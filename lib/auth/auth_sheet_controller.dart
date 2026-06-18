import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:smart_auth/smart_auth.dart';

import '../core/auth/auth_repository.dart';
import '../core/di/service_locator.dart';
import '../core/i18n/app_locale_controller.dart';
import '../core/logging/talker.dart';
import '../core/network/api_error.dart';
import '../customer/features/profile/cubit/profile_cubit.dart';
import 'auth_error_messages.dart';
import 'sheets/auth_sheet_kit.dart';

/// Lightweight orchestrator for the phone-OTP sheet.
///
/// Owns the wizard step, three text controllers, the loading/error state and
/// the resend timer, plus the three Woody-backend actions (request OTP,
/// verify OTP, save profile). The widget stays a thin [ListenableBuilder]
/// shell — it wires [onCompleted] (→ pop the sheet) and [onMessage]
/// (→ show a SnackBar) since those need a `BuildContext`.
class AuthSheetController extends ChangeNotifier {
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();

  AuthStep _step = AuthStep.phone;
  bool _isLoading = false;
  String? _errorMessage;
  int _secondsRemaining = 0;
  Timer? _resendTimer;
  bool _disposed = false;

  /// Monotonic token for the active SMS-autofill listen. Each (re)arm bumps it
  /// so a superseded in-flight listen (e.g. the first SMS was slow and the user
  /// tapped "resend") bows out after its awaits instead of racing — and its
  /// teardown can't clobber the fresh listener.
  int _smsListenGeneration = 0;

  /// Last cooldown the server returned. We pass this to the resend timer
  /// instead of a hardcoded 120s so the UI matches the backend's policy.
  int _lastCooldown = 60;

  AuthStep get step => _step;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get secondsRemaining => _secondsRemaining;
  bool get canResend => _secondsRemaining == 0 && !_isLoading;

  VoidCallback? onCompleted;
  void Function(String message, {required bool isError})? onMessage;

  String get remainingLabel {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// E.164-formatted phone number derived from [phoneCtrl] — `+998` + the
  /// digits-only national number.
  String get currentPhone {
    final digits = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    return '+998$digits';
  }

  /// Human-readable destination string used inside the OTP step header
  /// (e.g. "+998 90 123 45 67").
  String get currentPhoneDisplay {
    final digits = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) return currentPhone;
    return '+998 ${digits.substring(0, 2)} '
        '${digits.substring(2, 5)} ${digits.substring(5, 7)} ${digits.substring(7, 9)}';
  }

  AuthRepository? get _repo =>
      sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null;

  /// Active UI language code (uz/ru/en) used to pick the OTP SMS template.
  /// Null when the locale controller isn't registered (tests/tooling) — the
  /// repository then falls back to the English template.
  String? _appLanguage() => sl.isRegistered<AppLocaleController>()
      ? sl<AppLocaleController>().value.languageCode
      : null;

  // ---- Step actions ------------------------------------------------------

  Future<void> sendOtp({bool isResend = false}) async {
    talker.info('Button pressed: Kodni olish (isResend=$isResend)');
    if (_isLoading) return;
    final digits = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) {
      _setError("Telefon raqamni to'liq kiriting");
      return;
    }
    final repo = _repo;
    if (repo == null) {
      _setError("Server sozlanmagan. Ilovani qayta ishga tushiring");
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    _notify();
    final phone = currentPhone;
    talker.info('Requesting OTP for: ${_maskPhone(phone)}');
    try {
      final cooldown = await repo.requestOtp(
        phone,
        appLanguage: _appLanguage(),
      );
      _lastCooldown = cooldown > 0 ? cooldown : 60;
      talker.info('✓ OTP requested ok (cooldown=$cooldown s)');
      // Start listening for the incoming SMS so the code auto-fills (Android
      // SMS Retriever — zero-tap; the Eskiz template ends with our own app-
      // signature hash). Fire-and-forget; manual entry is always the fallback.
      unawaited(_listenForSmsCode());
      otpCtrl.clear();
      _startResendTimer();
      _step = AuthStep.otp;
      _notify();
      if (isResend) _showInfo('Kod qaytadan yuborildi');
    } on ApiError catch (e, st) {
      talker.handle(e, st, 'Failed to request OTP');
      _setError(authErrorMessageFromApi(e));
      if (e.isRateLimited && e.retryAfterSeconds != null) {
        _secondsRemaining = e.retryAfterSeconds!;
        _startResendCountdown();
      }
    } catch (e, st) {
      talker.handle(e, st, 'Failed to request OTP');
      _setError("Kodni yuborib bo'lmadi. Internet aloqasini tekshiring");
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> verifyOtp() async {
    talker.info('Button pressed: Tasdiqlash');
    if (_isLoading) return;
    final code = otpCtrl.text.trim();
    if (code.length < 4) {
      _setError("To'liq kodni kiriting");
      return;
    }
    final repo = _repo;
    if (repo == null) {
      _setError('Server sozlanmagan');
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    _notify();
    final phone = currentPhone;
    talker.info('Verifying OTP for: ${_maskPhone(phone)}');
    try {
      await repo.verifyOtp(phone, code);
      _resendTimer?.cancel();
      // After token write, check whether the user has a profile already.
      // No name → step 3; otherwise complete and pop.
      try {
        final me = await repo.fetchMe();
        if (me.hasProfile) {
          onCompleted?.call();
        } else {
          _step = AuthStep.profile;
          _notify();
        }
      } on ApiError catch (e, st) {
        // Profile lookup failure shouldn't block sign-in — fall through to
        // the profile step so the user can fill it in.
        talker.handle(
          e,
          st,
          'verifyOtp: /me failed; defaulting to profile step',
        );
        _step = AuthStep.profile;
        _notify();
      }
    } on ApiError catch (e, st) {
      talker.handle(e, st, 'Failed to verify OTP');
      _setError(authErrorMessageFromApi(e));
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
    if (_isLoading) return;
    final name = nameCtrl.text.trim();
    if (name.length < 2) {
      _setError("Ism va familiyangizni to'liq kiriting");
      return;
    }
    final repo = _repo;
    if (repo == null) {
      _setError('Server sozlanmagan');
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final me = await repo.updateProfile(fullName: name);
      talker.info('✓ Profile updated');
      if (sl.isRegistered<ProfileCubit>()) {
        sl<ProfileCubit>().applySignup(
          name: me.fullName ?? name,
          phone: me.phone ?? currentPhone,
        );
      }
      onCompleted?.call();
    } on ApiError catch (e, st) {
      talker.handle(e, st, 'Failed to save profile');
      _setError(authErrorMessageFromApi(e));
    } catch (e, st) {
      talker.handle(e, st, 'Failed to save profile');
      _setError("Saqlab bo'lmadi");
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void goBack() {
    if (_isLoading) return;
    if (_step == AuthStep.otp) {
      _resendTimer?.cancel();
      _step = AuthStep.phone;
      _secondsRemaining = 0;
      _errorMessage = null;
      _notify();
    }
  }

  void cancelResendTimer() => _resendTimer?.cancel();

  /// 11-char SMS Retriever hash for the Play App Signing key (derived from the
  /// `com.mebellar.app` App signing key certificate). The Eskiz OTP template
  /// ends with this exact string. If Play's signing key is ever rotated this
  /// must be regenerated — otherwise the match below silently fails and every
  /// build just falls back to the User Consent dialog.
  static const String _playAppSignatureHash = 'mH1HhnJpGqi';

  /// Android OTP autofill, choosing the API by this build's app-signature hash:
  ///
  ///  * **Play-installed builds** — the signature is the Play App Signing key
  ///    ([_playAppSignatureHash]), the same hash the Eskiz OTP template ends
  ///    with, so [getSmsWithRetrieverApi] hands us the code silently — zero-tap.
  ///  * **Debug / sideloaded-release builds** — a different signing key, so the
  ///    silent Retriever would never fire. They fall back to the hash-free
  ///    [getSmsWithUserConsentApi], which shows the system "read this message?"
  ///    dialog before filling.
  ///
  /// Either path fills [otpCtrl] (→ trips the pin-field listener → auto-submit).
  /// No-op on iOS — there, QuickType fills it via the field's
  /// `AutofillHints.oneTimeCode` inside an `AutofillGroup`.
  Future<void> _listenForSmsCode() async {
    if (!Platform.isAndroid) return;
    // A prior request may have left a listener armed (the first SMS was slow
    // and the user tapped "resend"). Tear it down first so this fresh listen
    // isn't a no-op against the still-registered receiver — otherwise the
    // resent code never auto-fills. Removing an unarmed listener is a no-op.
    await SmartAuth.instance.removeSmsRetrieverApiListener();
    await SmartAuth.instance.removeUserConsentApiListener();
    if (_disposed) return;
    final generation = ++_smsListenGeneration;
    try {
      final sig = await SmartAuth.instance.getAppSignature();
      if (_disposed || generation != _smsListenGeneration) return;
      final res = sig.data == _playAppSignatureHash
          ? await SmartAuth.instance.getSmsWithRetrieverApi()
          : await SmartAuth.instance.getSmsWithUserConsentApi();
      if (_disposed || generation != _smsListenGeneration) return;
      final code = res.data?.code;
      if (code != null && code.length >= 4) {
        otpCtrl.text = code; // trips _PinField's listener → auto-submit
      }
    } catch (_) {
      // Best-effort autofill — the user can always type the code by hand.
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  // ---- Helpers -----------------------------------------------------------

  void _startResendTimer() {
    _secondsRemaining = _lastCooldown;
    _startResendCountdown();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
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

  void _setError(String msg) {
    // Errors render inline only (AuthErrorBanner on phone/profile, the pin
    // field's own message on the OTP step). No SnackBar — it duplicated the
    // banner. `onMessage` is reserved for transient info (e.g. "code resent").
    _errorMessage = msg;
    _notify();
  }

  void _showInfo(String msg) => onMessage?.call(msg, isError: false);

  // Phone numbers are PII; talker forwards to Crashlytics, so never log the
  // full E.164 value. Keep the country prefix + last two digits for debugging.
  String _maskPhone(String p) => p.length <= 4
      ? '***'
      : '${p.substring(0, 4)}***${p.substring(p.length - 2)}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _resendTimer?.cancel();
    if (Platform.isAndroid) {
      // Either listener may be the active one (depends on the signature match
      // in _listenForSmsCode), so tear both down — removing an unregistered
      // listener is a harmless no-op.
      unawaited(SmartAuth.instance.removeSmsRetrieverApiListener());
      unawaited(SmartAuth.instance.removeUserConsentApiListener());
    }
    phoneCtrl.dispose();
    otpCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }
}
