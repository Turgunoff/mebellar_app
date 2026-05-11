import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/tariff.dart';
import '../../../../shared/repositories/tariff_repository.dart';

sealed class TariffUpgradeEvent extends Equatable {
  const TariffUpgradeEvent();
  @override
  List<Object?> get props => const [];
}

class TariffUpgradeStarted extends TariffUpgradeEvent {
  const TariffUpgradeStarted({required this.plan, required this.period});
  final TariffPlan plan;
  final BillingPeriod period;
  @override
  List<Object?> get props => [plan, period];
}

class TariffUpgradeScreenshotPicked extends TariffUpgradeEvent {
  const TariffUpgradeScreenshotPicked({
    required this.file,
    required this.fileExtension,
  });
  final File file;
  final String fileExtension;
  @override
  List<Object?> get props => [file.path, fileExtension];
}

class TariffUpgradeSubmitted extends TariffUpgradeEvent {
  const TariffUpgradeSubmitted();
}

class TariffUpgradeReset extends TariffUpgradeEvent {
  const TariffUpgradeReset();
}

enum TariffUpgradeFlowStatus {
  idle,
  uploading,
  ready,
  submitting,
  submitted,
  failure,
}

class TariffUpgradeState extends Equatable {
  const TariffUpgradeState({
    this.status = TariffUpgradeFlowStatus.idle,
    this.plan,
    this.period = BillingPeriod.monthly,
    this.localScreenshotPath,
    this.uploadedScreenshotUrl,
    this.subscription,
    this.error,
  });

  final TariffUpgradeFlowStatus status;
  final TariffPlan? plan;
  final BillingPeriod period;
  final String? localScreenshotPath;
  final String? uploadedScreenshotUrl;
  final TariffSubscription? subscription;
  final String? error;

  bool get canSubmit =>
      uploadedScreenshotUrl != null &&
      plan != null &&
      status == TariffUpgradeFlowStatus.ready;

  int get amount => plan?.priceFor(period) ?? 0;

  TariffUpgradeState copyWith({
    TariffUpgradeFlowStatus? status,
    TariffPlan? plan,
    BillingPeriod? period,
    String? localScreenshotPath,
    String? uploadedScreenshotUrl,
    TariffSubscription? subscription,
    String? error,
    bool clearError = false,
    bool clearLocalScreenshot = false,
    bool clearUploadedScreenshot = false,
  }) {
    return TariffUpgradeState(
      status: status ?? this.status,
      plan: plan ?? this.plan,
      period: period ?? this.period,
      localScreenshotPath: clearLocalScreenshot
          ? null
          : (localScreenshotPath ?? this.localScreenshotPath),
      uploadedScreenshotUrl: clearUploadedScreenshot
          ? null
          : (uploadedScreenshotUrl ?? this.uploadedScreenshotUrl),
      subscription: subscription ?? this.subscription,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        plan,
        period,
        localScreenshotPath,
        uploadedScreenshotUrl,
        subscription,
        error,
      ];
}

class TariffUpgradeBloc
    extends Bloc<TariffUpgradeEvent, TariffUpgradeState> {
  TariffUpgradeBloc(this._repo) : super(const TariffUpgradeState()) {
    on<TariffUpgradeStarted>((event, emit) {
      emit(TariffUpgradeState(
        status: TariffUpgradeFlowStatus.idle,
        plan: event.plan,
        period: event.period,
      ));
    });
    on<TariffUpgradeScreenshotPicked>(_onScreenshotPicked);
    on<TariffUpgradeSubmitted>(_onSubmitted);
    on<TariffUpgradeReset>((_, emit) => emit(const TariffUpgradeState()));
  }

  final TariffRepository _repo;

  Future<void> _onScreenshotPicked(
    TariffUpgradeScreenshotPicked event,
    Emitter<TariffUpgradeState> emit,
  ) async {
    emit(state.copyWith(
      status: TariffUpgradeFlowStatus.uploading,
      localScreenshotPath: event.file.path,
      clearError: true,
      clearUploadedScreenshot: true,
    ));
    try {
      final url = await _repo.uploadPaymentScreenshot(
        file: event.file,
        fileExtension: event.fileExtension,
      );
      emit(state.copyWith(
        status: TariffUpgradeFlowStatus.ready,
        uploadedScreenshotUrl: url,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TariffUpgradeFlowStatus.failure,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onSubmitted(
    TariffUpgradeSubmitted event,
    Emitter<TariffUpgradeState> emit,
  ) async {
    final plan = state.plan;
    final url = state.uploadedScreenshotUrl;
    if (plan == null || url == null) return;
    emit(state.copyWith(
        status: TariffUpgradeFlowStatus.submitting, clearError: true));
    try {
      final subscription = await _repo.upgrade(TariffUpgradeInput(
        plan: plan,
        period: state.period,
        amount: state.amount,
        paymentScreenshotUrl: url,
      ));
      emit(state.copyWith(
        status: TariffUpgradeFlowStatus.submitted,
        subscription: subscription,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TariffUpgradeFlowStatus.failure,
        error: e.toString(),
      ));
    }
  }
}
