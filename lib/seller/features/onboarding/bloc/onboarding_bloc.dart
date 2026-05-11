import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/business_type.dart';
import '../../../../shared/models/onboarding_draft.dart';
import '../../../../shared/models/region.dart';
import '../../../../shared/models/verification_status.dart';
import '../../../../shared/repositories/seller_onboarding_repository.dart';

/// Linear wizard. Welcome and done are pure UI without inputs but still
/// participate in advance/back so the progress indicator renders correctly.
/// shopInfo and shopAddress are split intentionally — keeping them together
/// turns the screen into a long scrollable form and forced multilingual tabs
/// for the brand name. One concern per step is friendlier to fill out.
enum OnboardingStep {
  welcome,
  businessType,
  personalInfo,
  shopInfo,
  shopAddress,
  review,
  done;

  static const total = 7;
}

sealed class OnboardingEvent extends Equatable {
  const OnboardingEvent();
  @override
  List<Object?> get props => const [];
}

class OnboardingStarted extends OnboardingEvent {
  const OnboardingStarted();
}

class OnboardingNextStep extends OnboardingEvent {
  const OnboardingNextStep();
}

class OnboardingGoToStep extends OnboardingEvent {
  const OnboardingGoToStep(this.step);
  final OnboardingStep step;
  @override
  List<Object?> get props => [step];
}

class OnboardingPreviousStep extends OnboardingEvent {
  const OnboardingPreviousStep();
}

class OnboardingBusinessTypeChanged extends OnboardingEvent {
  const OnboardingBusinessTypeChanged(this.value);
  final BusinessType value;
  @override
  List<Object?> get props => [value];
}

class OnboardingPersonalInfoChanged extends OnboardingEvent {
  const OnboardingPersonalInfoChanged({
    this.legalName,
    this.contactPhone,
    this.contactEmail,
    this.telegramUsername,
  });
  final String? legalName;
  final String? contactPhone;
  final String? contactEmail;
  final String? telegramUsername;
  @override
  List<Object?> get props => [
    legalName,
    contactPhone,
    contactEmail,
    telegramUsername,
  ];
}

class OnboardingShopInfoChanged extends OnboardingEvent {
  const OnboardingShopInfoChanged({
    this.shopNameUz,
    this.shopNameRu,
    this.shopNameEn,
    this.shopDescriptionUz,
    this.shopDescriptionRu,
    this.shopDescriptionEn,
    this.streetLine,
    this.landmark,
    this.region,
    this.city,
    this.district,
    this.lat,
    this.lng,
    this.clearDistrict = false,
  });
  final String? shopNameUz;
  final String? shopNameRu;
  final String? shopNameEn;
  final String? shopDescriptionUz;
  final String? shopDescriptionRu;
  final String? shopDescriptionEn;
  final String? streetLine;
  final String? landmark;
  final Region? region;
  final Region? city;
  final Region? district;
  final bool clearDistrict;
  final double? lat;
  final double? lng;
  @override
  List<Object?> get props => [
    shopNameUz,
    shopNameRu,
    shopNameEn,
    shopDescriptionUz,
    shopDescriptionRu,
    shopDescriptionEn,
    streetLine,
    landmark,
    region?.id,
    city?.id,
    district?.id,
    clearDistrict,
    lat,
    lng,
  ];
}

class OnboardingVerifyChoiceChanged extends OnboardingEvent {
  const OnboardingVerifyChoiceChanged(this.verifyNow);
  final bool verifyNow;
  @override
  List<Object?> get props => [verifyNow];
}

class OnboardingSubmitted extends OnboardingEvent {
  const OnboardingSubmitted();
}

class OnboardingReset extends OnboardingEvent {
  const OnboardingReset();
}

enum OnboardingStatus {
  editing,
  submitting,
  submitted,
  navigateDocuments,
  failure,
}

class OnboardingState extends Equatable {
  const OnboardingState({
    this.status = OnboardingStatus.editing,
    this.step = OnboardingStep.welcome,
    this.draft = const OnboardingDraft(),
    this.resultStatus,
    this.error,
    this.shopId,
  });

  final OnboardingStatus status;
  final OnboardingStep step;
  final OnboardingDraft draft;
  final VerificationStatus? resultStatus;
  final String? error;
  final String? shopId; // Populated after successful submission

  bool get canAdvance {
    return switch (step) {
      OnboardingStep.welcome => true,
      OnboardingStep.businessType => draft.businessType != null,
      OnboardingStep.personalInfo =>
        (draft.legalName?.trim().isNotEmpty ?? false) &&
            (draft.contactPhone?.trim().length ?? 0) >= 9,
      OnboardingStep.shopInfo => draft.hasShopName,
      OnboardingStep.shopAddress =>
        draft.shopLat != null &&
            draft.shopLng != null &&
            (draft.shopStreetLine?.trim().isNotEmpty ?? false),
      OnboardingStep.review => true,
      OnboardingStep.done => false,
    };
  }

  OnboardingState copyWith({
    OnboardingStatus? status,
    OnboardingStep? step,
    OnboardingDraft? draft,
    VerificationStatus? resultStatus,
    String? error,
    bool clearError = false,
    String? shopId,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      step: step ?? this.step,
      draft: draft ?? this.draft,
      resultStatus: resultStatus ?? this.resultStatus,
      error: clearError ? null : (error ?? this.error),
      shopId: shopId ?? this.shopId,
    );
  }

  @override
  List<Object?> get props => [status, step, draft, resultStatus, error, shopId];
}

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc(this._repo) : super(const OnboardingState()) {
    on<OnboardingStarted>(_onStarted);
    on<OnboardingNextStep>(_onNext);
    on<OnboardingGoToStep>(_onGoToStep);
    on<OnboardingPreviousStep>(_onPrev);
    on<OnboardingBusinessTypeChanged>(_onBusinessType);
    on<OnboardingPersonalInfoChanged>(_onPersonal);
    on<OnboardingShopInfoChanged>(_onShop);
    on<OnboardingVerifyChoiceChanged>(_onVerify);
    on<OnboardingSubmitted>(_onSubmitted);
    on<OnboardingReset>(_onReset);
  }

  final SellerOnboardingRepository _repo;
  Timer? _saveDebounce;

  Future<void> _onStarted(
    OnboardingStarted event,
    Emitter<OnboardingState> emit,
  ) async {
    final draft = _repo.loadDraft();
    final resumeStep = OnboardingStep
        .values[draft.lastStep.clamp(0, OnboardingStep.values.length - 1)];
    emit(state.copyWith(draft: draft, step: resumeStep));
  }

  void _onNext(OnboardingNextStep event, Emitter<OnboardingState> emit) {
    if (!state.canAdvance) return;
    final nextIdx = state.step.index + 1;
    if (nextIdx >= OnboardingStep.values.length) return;
    final nextStep = OnboardingStep.values[nextIdx];
    final nextDraft = state.draft.copyWith(lastStep: nextIdx);
    emit(state.copyWith(step: nextStep, draft: nextDraft, clearError: true));
    _scheduleSave();
  }

  void _onGoToStep(OnboardingGoToStep event, Emitter<OnboardingState> emit) {
    final targetIndex = event.step.index;
    emit(
      state.copyWith(
        step: event.step,
        draft: state.draft.copyWith(lastStep: targetIndex),
        clearError: true,
      ),
    );
    _scheduleSave();
  }

  void _onPrev(OnboardingPreviousStep event, Emitter<OnboardingState> emit) {
    final prevIdx = state.step.index - 1;
    if (prevIdx < 0) return;
    final prevStep = OnboardingStep.values[prevIdx];
    final nextDraft = state.draft.copyWith(lastStep: prevIdx);
    emit(state.copyWith(step: prevStep, draft: nextDraft));
  }

  void _onBusinessType(
    OnboardingBusinessTypeChanged event,
    Emitter<OnboardingState> emit,
  ) {
    emit(
      state.copyWith(draft: state.draft.copyWith(businessType: event.value)),
    );
    _scheduleSave();
  }

  void _onPersonal(
    OnboardingPersonalInfoChanged event,
    Emitter<OnboardingState> emit,
  ) {
    emit(
      state.copyWith(
        draft: state.draft.copyWith(
          legalName: event.legalName,
          contactPhone: event.contactPhone,
          contactEmail: event.contactEmail,
          telegramUsername: event.telegramUsername,
        ),
      ),
    );
    _scheduleSave();
  }

  void _onShop(OnboardingShopInfoChanged event, Emitter<OnboardingState> emit) {
    emit(
      state.copyWith(
        draft: state.draft.copyWith(
          shopNameUz: event.shopNameUz,
          shopNameRu: event.shopNameRu,
          shopNameEn: event.shopNameEn,
          shopDescriptionUz: event.shopDescriptionUz,
          shopDescriptionRu: event.shopDescriptionRu,
          shopDescriptionEn: event.shopDescriptionEn,
          shopStreetLine: event.streetLine,
          shopLandmark: event.landmark,
          shopRegion: event.region,
          shopCity: event.city,
          shopDistrict: event.district,
          clearDistrict: event.clearDistrict,
          shopLat: event.lat,
          shopLng: event.lng,
        ),
      ),
    );
    _scheduleSave();
  }

  void _onVerify(
    OnboardingVerifyChoiceChanged event,
    Emitter<OnboardingState> emit,
  ) {
    emit(
      state.copyWith(draft: state.draft.copyWith(verifyNow: event.verifyNow)),
    );
    _scheduleSave();
  }

  Future<void> _onSubmitted(
    OnboardingSubmitted event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(status: OnboardingStatus.submitting, clearError: true));
    try {
      final result = await _repo.submit(state.draft);
      await _repo.clearDraft();
      emit(
        state.copyWith(
          status: OnboardingStatus.navigateDocuments,
          resultStatus: result.verificationStatus,
          shopId: result.shopId,
          step: OnboardingStep.done,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: OnboardingStatus.failure, error: e.toString()),
      );
    }
  }

  Future<void> _onReset(
    OnboardingReset event,
    Emitter<OnboardingState> emit,
  ) async {
    await _repo.clearDraft();
    emit(const OnboardingState());
  }

  /// Debounce Hive writes so we don't fsync on every keystroke. 350ms gives
  /// the user a small grace period to keep typing while still flushing
  /// before they background the app.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      _repo.saveDraft(state.draft);
    });
  }

  @override
  Future<void> close() async {
    _saveDebounce?.cancel();
    // Best-effort flush before disposal so a quick close doesn't drop the
    // last keystroke.
    await _repo.saveDraft(state.draft);
    return super.close();
  }
}
