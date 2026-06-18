import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/network/payme_client.dart';
import '../../../../shared/repositories/payment_cards_repository.dart';

enum AddCardStep { form, code, done }

class AddCardState extends Equatable {
  const AddCardState({
    this.step = AddCardStep.form,
    this.submitting = false,
    this.token,
    this.maskedNumber,
    this.maskedPhone,
    this.error,
  });

  final AddCardStep step;
  final bool submitting;

  /// Payme token from `cards.create`/`verify`. Held in memory only for the
  /// duration of the flow, then handed to the backend — never persisted here.
  final String? token;
  final String? maskedNumber;

  /// Masked phone the OTP went to (from `cards.get_verify_code`).
  final String? maskedPhone;
  final String? error;

  AddCardState copyWith({
    AddCardStep? step,
    bool? submitting,
    String? token,
    String? maskedNumber,
    String? maskedPhone,
    String? error,
    bool clearError = false,
  }) => AddCardState(
    step: step ?? this.step,
    submitting: submitting ?? this.submitting,
    token: token ?? this.token,
    maskedNumber: maskedNumber ?? this.maskedNumber,
    maskedPhone: maskedPhone ?? this.maskedPhone,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    step,
    submitting,
    token,
    maskedNumber,
    maskedPhone,
    error,
  ];
}

/// Drives the secure add-card flow:
///   form → cards.create → cards.get_verify_code → (SMS) → cards.verify →
///   POST /customer/payment-cards → done.
///
/// The raw PAN + expiry go ONLY to [PaymeClient] (Payme servers); the backend
/// receives the resulting token + masked number, nothing more.
class AddCardCubit extends Cubit<AddCardState> {
  AddCardCubit({required PaymeClient payme, required PaymentCardsRepository repo})
    : _payme = payme,
      _repo = repo,
      super(const AddCardState());

  final PaymeClient _payme;
  final PaymentCardsRepository _repo;

  /// Step 1+2: tokenise the card, then ask Payme to SMS a verification code.
  /// `number` may carry spaces and `expire` may be `MM/YY` — both are
  /// normalised here so the UI controllers can stay human-friendly.
  Future<void> startCard({required String number, required String expire}) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, clearError: true));
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final exp = expire.replaceAll(RegExp(r'\D'), ''); // MMYY
    try {
      final card = await _payme.createCard(number: digits, expire: exp);
      final challenge = await _payme.getVerifyCode(card.token);
      if (isClosed) return;
      emit(
        state.copyWith(
          step: AddCardStep.code,
          submitting: false,
          token: card.token,
          maskedNumber: card.maskedNumber,
          maskedPhone: challenge.phone,
        ),
      );
    } on PaymeException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(submitting: false, error: _paymeMessage(e, fallbackKey: 'payment.err_card')),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(submitting: false, error: apiErrorMessage(e)));
    }
  }

  /// Step 3: confirm the SMS code, then persist the verified token on the
  /// backend (which re-validates it via cards.check).
  Future<bool> submitCode(String code) async {
    if (state.submitting || state.token == null) return false;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final verified = await _payme.verifyCard(token: state.token!, code: code);
      // The verify response carries the final (possibly rotated) token + the
      // authoritative masked number.
      await _repo.add(
        token: verified.token,
        maskedNumber: verified.maskedNumber.isNotEmpty
            ? verified.maskedNumber
            : (state.maskedNumber ?? ''),
      );
      if (isClosed) return false;
      emit(state.copyWith(step: AddCardStep.done, submitting: false));
      return true;
    } on PaymeException catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(submitting: false, error: _paymeMessage(e, fallbackKey: 'payment.err_sms_code')),
      );
      return false;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(submitting: false, error: apiErrorMessage(e)));
      return false;
    }
  }

  /// Return to the card-entry step (back from the SMS step), keeping the token
  /// so the user doesn't re-key the card if they only mistyped the code.
  void backToForm() {
    if (state.submitting) return;
    emit(state.copyWith(step: AddCardStep.form, clearError: true));
  }

  /// Re-send the SMS code from the code step (token already exists).
  Future<void> resendCode() async {
    final token = state.token;
    if (token == null || state.submitting) return;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final challenge = await _payme.getVerifyCode(token);
      if (isClosed) return;
      emit(state.copyWith(submitting: false, maskedPhone: challenge.phone));
    } on PaymeException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(submitting: false, error: _paymeMessage(e, fallbackKey: 'payment.err_sms_send')),
      );
    }
  }

  String _paymeMessage(PaymeException e, {required String fallbackKey}) {
    // Payme's own message is localised + user-readable; prefer it, fall back to
    // our generic per-step copy when it's empty/opaque.
    final msg = e.message.trim();
    if (msg.isEmpty || msg == 'payme_error') return tr(fallbackKey);
    return msg;
  }
}
