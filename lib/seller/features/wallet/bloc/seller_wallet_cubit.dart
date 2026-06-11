import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/talker.dart';
import '../../../../shared/models/seller_wallet.dart';
import '../../../../shared/repositories/seller_wallet_repository.dart';
import '../../../../shared/repositories/tariff_repository.dart';

enum WalletStatus { loading, ready, failure }

enum TopUpStatus { idle, submitting, success, failure }

/// Single-state cubit for the wallet screen: balance/debt snapshot, the
/// payment card details (reused from the tariff flow — same till), and the
/// top-up submission lifecycle.
class SellerWalletCubit extends Cubit<SellerWalletState> {
  SellerWalletCubit(this._wallet, {TariffRepository? tariffs})
    : _tariffs = tariffs,
      super(const SellerWalletState());

  final SellerWalletRepository _wallet;
  final TariffRepository? _tariffs;

  Future<void> load() async {
    emit(state.copyWith(status: WalletStatus.loading, clearError: true));
    try {
      final wallet = await _wallet.fetch(recent: 30);
      if (isClosed) return;
      emit(state.copyWith(status: WalletStatus.ready, wallet: wallet));
    } catch (e, st) {
      talker.handle(e, st, 'SellerWalletCubit.load');
      if (isClosed) return;
      emit(
        state.copyWith(status: WalletStatus.failure, error: e.toString()),
      );
      return;
    }
    // Card details are a nicety — their failure must not break the screen.
    final tariffs = _tariffs;
    if (tariffs == null || state.instructions != null) return;
    final result = await tariffs.paymentInstructions();
    final instructions = result.valueOrNull;
    if (isClosed || instructions == null) return;
    emit(state.copyWith(instructions: instructions));
  }

  Future<void> refresh() => load();

  /// Uploads the screenshot, files the top-up request, then re-reads the
  /// wallet so the pending badge appears with server truth.
  Future<void> submitTopUp({
    required int amount,
    required File screenshot,
    required String fileExtension,
  }) async {
    if (state.topUpStatus == TopUpStatus.submitting) return;
    emit(state.copyWith(topUpStatus: TopUpStatus.submitting, clearError: true));
    try {
      final path = await _wallet.uploadPaymentScreenshot(
        file: screenshot,
        fileExtension: fileExtension,
      );
      await _wallet.submitTopUp(amount: amount, paymentScreenshotPath: path);
      final wallet = await _wallet.fetch(recent: 30);
      if (isClosed) return;
      emit(
        state.copyWith(
          topUpStatus: TopUpStatus.success,
          status: WalletStatus.ready,
          wallet: wallet,
        ),
      );
    } catch (e, st) {
      talker.handle(e, st, 'SellerWalletCubit.submitTopUp');
      if (isClosed) return;
      emit(
        state.copyWith(topUpStatus: TopUpStatus.failure, error: e.toString()),
      );
    }
  }

  /// Returns the snackbar machinery to idle after the UI consumed a
  /// success/failure transition.
  void acknowledgeTopUpResult() {
    emit(state.copyWith(topUpStatus: TopUpStatus.idle, clearError: true));
  }
}

class SellerWalletState extends Equatable {
  const SellerWalletState({
    this.status = WalletStatus.loading,
    this.wallet = const SellerWallet(),
    this.instructions,
    this.topUpStatus = TopUpStatus.idle,
    this.error,
  });

  final WalletStatus status;
  final SellerWallet wallet;
  final TariffPaymentInstructions? instructions;
  final TopUpStatus topUpStatus;
  final String? error;

  SellerWalletState copyWith({
    WalletStatus? status,
    SellerWallet? wallet,
    TariffPaymentInstructions? instructions,
    TopUpStatus? topUpStatus,
    String? error,
    bool clearError = false,
  }) {
    return SellerWalletState(
      status: status ?? this.status,
      wallet: wallet ?? this.wallet,
      instructions: instructions ?? this.instructions,
      topUpStatus: topUpStatus ?? this.topUpStatus,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, wallet, instructions, topUpStatus, error];
}
