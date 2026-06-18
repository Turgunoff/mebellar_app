import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_error_messages.dart';
import '../../../../shared/repositories/payment_cards_repository.dart';

enum PaymentCardsStatus { initial, loading, ready, failure }

class PaymentCardsState extends Equatable {
  const PaymentCardsState({
    this.status = PaymentCardsStatus.initial,
    this.cards = const [],
    this.error,
  });

  final PaymentCardsStatus status;
  final List<SavedCard> cards;
  final String? error;

  bool get hasCards => cards.isNotEmpty;

  PaymentCardsState copyWith({
    PaymentCardsStatus? status,
    List<SavedCard>? cards,
    String? error,
    bool clearError = false,
  }) => PaymentCardsState(
    status: status ?? this.status,
    cards: cards ?? this.cards,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [status, cards, error];
}

/// Owns the customer's saved-card list — load, refresh after an add, and
/// remove. The add *flow* lives in [AddCardCubit]; this cubit just reloads
/// when it completes.
class PaymentCardsCubit extends Cubit<PaymentCardsState> {
  PaymentCardsCubit(this._repo) : super(const PaymentCardsState());

  final PaymentCardsRepository _repo;

  Future<void> load({bool refresh = false}) async {
    final silent = refresh && state.cards.isNotEmpty;
    if (!silent) {
      emit(state.copyWith(status: PaymentCardsStatus.loading, clearError: true));
    }
    try {
      final cards = await _repo.list();
      if (isClosed) return;
      emit(state.copyWith(status: PaymentCardsStatus.ready, cards: cards));
    } catch (e) {
      if (isClosed) return;
      if (silent) return;
      emit(
        state.copyWith(
          status: PaymentCardsStatus.failure,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  /// Optimistically drops the card, then reconciles with the server. On failure
  /// the list is reloaded so a half-removed row can't linger.
  Future<void> remove(String cardId) async {
    final previous = state.cards;
    emit(
      state.copyWith(
        cards: previous.where((c) => c.id != cardId).toList(growable: false),
        clearError: true,
      ),
    );
    try {
      await _repo.remove(cardId);
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(cards: previous, error: apiErrorMessage(e)));
    }
  }
}
