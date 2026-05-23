import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
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
///
/// documentUpload sits between review and done so KYC document selection is
/// part of the wizard's state machine rather than an external route. The
/// backend submission fires when leaving documentUpload, not review.
enum OnboardingStep {
  welcome,
  businessType,
  personalInfo,
  shopInfo,
  shopAddress,
  review,
  documentUpload,
  done;

  static const total = 8;
}

/// Document ids required to complete onboarding, derived from business type.
/// Mirrors the seller-side KYC checklist surfaced in the documentUpload step.
/// Passport is collected as two separate sides — front + back — so the
/// reviewer can read both the photo page and the address page.
List<String> requiredDocumentIdsFor(BusinessType type) {
  return switch (type) {
    BusinessType.individual => const ['passport_front', 'passport_back'],
    BusinessType.selfEmployed => const [
      'passport_front',
      'passport_back',
      'certificate',
    ],
    BusinessType.llc || BusinessType.corporation => const [
      'passport_front',
      'passport_back',
      'guvohnoma',
      'inn',
    ],
  };
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

class OnboardingDocumentPicked extends OnboardingEvent {
  const OnboardingDocumentPicked({required this.documentId, this.filePath});
  final String documentId;

  /// `null` clears the picked file for this document id.
  final String? filePath;

  @override
  List<Object?> get props => [documentId, filePath];
}

class OnboardingSubmitted extends OnboardingEvent {
  const OnboardingSubmitted();
}

class OnboardingReset extends OnboardingEvent {
  const OnboardingReset();
}

enum OnboardingStatus { editing, submitting, submitted, failure }

class OnboardingState extends Equatable {
  const OnboardingState({
    this.status = OnboardingStatus.editing,
    this.step = OnboardingStep.welcome,
    this.draft = const OnboardingDraft(),
    this.documentFiles = const {},
    this.resultStatus,
    this.error,
    this.shopId,
  });

  final OnboardingStatus status;
  final OnboardingStep step;
  final OnboardingDraft draft;

  /// Picked KYC file paths keyed by document id (see [requiredDocumentIdsFor]).
  /// Held in state so canAdvance for documentUpload can gate the submit button.
  final Map<String, String> documentFiles;
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
      OnboardingStep.documentUpload => _allRequiredDocumentsPicked,
      OnboardingStep.done => false,
    };
  }

  bool get _allRequiredDocumentsPicked {
    final type = draft.businessType;
    if (type == null) return false;
    return requiredDocumentIdsFor(type).every(documentFiles.containsKey);
  }

  OnboardingState copyWith({
    OnboardingStatus? status,
    OnboardingStep? step,
    OnboardingDraft? draft,
    Map<String, String>? documentFiles,
    VerificationStatus? resultStatus,
    String? error,
    bool clearError = false,
    String? shopId,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      step: step ?? this.step,
      draft: draft ?? this.draft,
      documentFiles: documentFiles ?? this.documentFiles,
      resultStatus: resultStatus ?? this.resultStatus,
      error: clearError ? null : (error ?? this.error),
      shopId: shopId ?? this.shopId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    step,
    draft,
    documentFiles,
    resultStatus,
    error,
    shopId,
  ];
}

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc(this._repo, {AnalyticsService? analytics})
      : _analytics = analytics,
        super(const OnboardingState()) {
    on<OnboardingStarted>(_onStarted);
    on<OnboardingNextStep>(_onNext);
    on<OnboardingGoToStep>(_onGoToStep);
    on<OnboardingPreviousStep>(_onPrev);
    on<OnboardingBusinessTypeChanged>(_onBusinessType);
    on<OnboardingPersonalInfoChanged>(_onPersonal);
    on<OnboardingShopInfoChanged>(_onShop);
    on<OnboardingVerifyChoiceChanged>(_onVerify);
    on<OnboardingDocumentPicked>(_onDocumentPicked);
    on<OnboardingSubmitted>(_onSubmitted);
    on<OnboardingReset>(_onReset);
  }

  final SellerOnboardingRepository _repo;
  final AnalyticsService? _analytics;
  Timer? _saveDebounce;
  bool _trackedStart = false;

  Future<void> _onStarted(
    OnboardingStarted event,
    Emitter<OnboardingState> emit,
  ) async {
    var draft = _repo.loadDraft();

    // Local Hive draft is wiped at successful submit time, so for a
    // resubmit-after-rejection flow the wizard would otherwise open blank.
    // Fall through to the server's last-known answers when local is empty.
    if (draft.isEmpty) {
      final remote = await _repo.loadRemoteDraft();
      if (remote != null) {
        draft = remote;
        // Pre-fill arrives only via the rejected path. Start the user at the
        // review step so they can scan + edit instead of re-walking welcome.
        draft = draft.copyWith(lastStep: OnboardingStep.review.index);
      }
    }

    final resumeStep = OnboardingStep
        .values[draft.lastStep.clamp(0, OnboardingStep.values.length - 1)];
    emit(state.copyWith(draft: draft, step: resumeStep));
    // Funnel start — fire once per OnboardingBloc instance so resuming
    // a draft after an app reopen doesn't double-count the start.
    if (!_trackedStart) {
      _trackedStart = true;
      unawaited(_analytics?.sellerOnboardingStarted());
    }
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

  void _onDocumentPicked(
    OnboardingDocumentPicked event,
    Emitter<OnboardingState> emit,
  ) {
    final next = Map<String, String>.from(state.documentFiles);
    if (event.filePath == null) {
      next.remove(event.documentId);
    } else {
      next[event.documentId] = event.filePath!;
    }
    emit(state.copyWith(documentFiles: next));
  }

  Future<void> _onSubmitted(
    OnboardingSubmitted event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(status: OnboardingStatus.submitting, clearError: true));
    try {
      // Forward the picked passport image paths so the repository can upload
      // them to storage and persist their paths on the sellers row. Keys
      // match the document ids emitted by the documentUpload step.
      final result = await _repo.submit(
        state.draft,
        passportFrontPath: state.documentFiles['passport_front'],
        passportBackPath: state.documentFiles['passport_back'],
      );
      await _repo.clearDraft();
      emit(
        state.copyWith(
          status: OnboardingStatus.submitted,
          resultStatus: result.verificationStatus,
          shopId: result.shopId,
          step: OnboardingStep.done,
        ),
      );
      unawaited(_analytics?.sellerOnboardingCompleted());
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
