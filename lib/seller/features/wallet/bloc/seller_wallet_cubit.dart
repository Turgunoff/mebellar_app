import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../shared/models/seller_wallet.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../../../../shared/repositories/seller_wallet_repository.dart';

enum WalletStatus { loading, ready, failure }

enum DepositStatus { idle, starting, failure }

enum ManualTopUpStatus { idle, submitting, failure }

/// Single-state cubit for the wallet screen: the balance/debt snapshot and the
/// automated top-up (deposit) lifecycle. A top-up opens a Payme/Click deep-link;
/// the balance is credited by the webhook and reconciled when the seller returns
/// — [reconcileDeposit] polls the deposit status and refreshes the balance the
/// instant it settles.
class SellerWalletCubit extends Cubit<SellerWalletState> {
  SellerWalletCubit(this._wallet) : super(const SellerWalletState());

  final SellerWalletRepository _wallet;

  /// The in-flight top-up id, kept in memory so [reconcileDeposit] can refresh
  /// the balance on return. Cold-start recovery is the global
  /// PaymentRecoveryGate's job (it reads the persisted marker), and a fresh
  /// screen open re-fetches the balance anyway, so this need not survive a kill.
  String? _pendingDepositId;

  Future<void> load() async {
    emit(state.copyWith(status: WalletStatus.loading, clearError: true));
    try {
      final wallet = await _wallet.fetch(recent: 30);
      if (isClosed) return;
      emit(state.copyWith(status: WalletStatus.ready, wallet: wallet));
    } catch (e, st) {
      appLog.handle(e, st, 'SellerWalletCubit.load');
      if (isClosed) return;
      emit(state.copyWith(status: WalletStatus.failure, error: e.toString()));
    }
  }

  Future<void> refresh() => load();

  /// Opens a self-serve top-up: creates the deposit intent and returns the
  /// checkout deep-link for the caller to launch (the caller also registers the
  /// pending-payment marker). Returns null on failure (a snackbar is surfaced
  /// via [DepositStatus.failure]).
  Future<CheckoutLink?> startDeposit({
    required int amount,
    required PaymentProvider provider,
  }) async {
    if (state.depositStatus == DepositStatus.starting) return null;
    emit(
      state.copyWith(depositStatus: DepositStatus.starting, clearError: true),
    );
    try {
      final link = await _wallet.createDeposit(
        amount: amount,
        provider: provider,
      );
      _pendingDepositId = link.reference;
      if (isClosed) return link;
      emit(state.copyWith(depositStatus: DepositStatus.idle));
      return link;
    } catch (e, st) {
      appLog.handle(e, st, 'SellerWalletCubit.startDeposit');
      if (isClosed) return null;
      emit(
        state.copyWith(
          depositStatus: DepositStatus.failure,
          error: apiErrorMessage(e),
        ),
      );
      return null;
    }
  }

  /// Called when the app returns to the foreground after a top-up hand-off: poll
  /// the deposit status (the webhook may lag the return) and refresh the balance
  /// the instant it settles, so the wallet reflects the new amount immediately.
  /// Read-only — it never touches the persisted marker the recovery gate owns.
  Future<void> reconcileDeposit() async {
    final depositId = _pendingDepositId;
    if (depositId == null) return;
    for (var attempt = 0; attempt < 5; attempt++) {
      String? status;
      try {
        status = await _wallet.depositStatus(depositId);
      } catch (_) {
        status = null;
      }
      if (isClosed) return;
      if (status == 'paid' || status == 'cancelled') {
        _pendingDepositId = null;
        if (status == 'paid') await load();
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    // Window closed without a settled status — refresh once, best effort.
    _pendingDepositId = null;
    if (!isClosed) await load();
  }

  /// Returns the deposit machinery to idle after the UI consumed a failure.
  void acknowledgeDepositResult() {
    emit(state.copyWith(depositStatus: DepositStatus.idle, clearError: true));
  }

  /// Manual card transfer: uploads are done by the UI; this submits the pending
  /// moderation row. Returns the created top-up on success (wallet reloads so
  /// the pending banner stays in sync).
  Future<WalletTopUp?> submitManualTopup({
    required int amount,
    required String paymentScreenshotPath,
  }) async {
    if (state.manualTopUpStatus == ManualTopUpStatus.submitting) return null;
    emit(
      state.copyWith(
        manualTopUpStatus: ManualTopUpStatus.submitting,
        clearError: true,
      ),
    );
    try {
      final topUp = await _wallet.submitManualTopup(
        amount: amount,
        paymentScreenshotPath: paymentScreenshotPath,
      );
      if (isClosed) return null;
      await load();
      if (isClosed) return null;
      emit(state.copyWith(manualTopUpStatus: ManualTopUpStatus.idle));
      return topUp;
    } catch (e, st) {
      appLog.handle(e, st, 'SellerWalletCubit.submitManualTopup');
      if (isClosed) return null;
      emit(
        state.copyWith(
          manualTopUpStatus: ManualTopUpStatus.failure,
          error: apiErrorMessage(e),
        ),
      );
      return null;
    }
  }

  void acknowledgeManualTopUpResult() {
    emit(
      state.copyWith(
        manualTopUpStatus: ManualTopUpStatus.idle,
        clearError: true,
      ),
    );
  }
}

class SellerWalletState extends Equatable {
  const SellerWalletState({
    this.status = WalletStatus.loading,
    this.wallet = const SellerWallet(),
    this.depositStatus = DepositStatus.idle,
    this.manualTopUpStatus = ManualTopUpStatus.idle,
    this.error,
  });

  final WalletStatus status;
  final SellerWallet wallet;
  final DepositStatus depositStatus;
  final ManualTopUpStatus manualTopUpStatus;
  final String? error;

  SellerWalletState copyWith({
    WalletStatus? status,
    SellerWallet? wallet,
    DepositStatus? depositStatus,
    ManualTopUpStatus? manualTopUpStatus,
    String? error,
    bool clearError = false,
  }) {
    return SellerWalletState(
      status: status ?? this.status,
      wallet: wallet ?? this.wallet,
      depositStatus: depositStatus ?? this.depositStatus,
      manualTopUpStatus: manualTopUpStatus ?? this.manualTopUpStatus,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    status,
    wallet,
    depositStatus,
    manualTopUpStatus,
    error,
  ];
}
