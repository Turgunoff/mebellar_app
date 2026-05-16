import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/business_type.dart';
import '../../../../shared/models/verification_document.dart';
import '../../../../shared/models/verification_status.dart';
import '../../../../shared/repositories/seller_verification_repository.dart';

sealed class VerificationEvent extends Equatable {
  const VerificationEvent();
  @override
  List<Object?> get props => const [];
}

class VerificationRequested extends VerificationEvent {
  const VerificationRequested({required this.businessType, required this.status});
  final BusinessType? businessType;
  final VerificationStatus status;
  @override
  List<Object?> get props => [businessType, status];
}

class VerificationDocumentUploadStarted extends VerificationEvent {
  const VerificationDocumentUploadStarted({
    required this.type,
    required this.file,
    required this.fileExtension,
  });
  final VerificationDocumentType type;
  final File file;
  final String fileExtension;
  @override
  List<Object?> get props => [type, file.path, fileExtension];
}

class VerificationDocumentRemoved extends VerificationEvent {
  const VerificationDocumentRemoved(this.type);
  final VerificationDocumentType type;
  @override
  List<Object?> get props => [type];
}

class VerificationSubmitted extends VerificationEvent {
  const VerificationSubmitted();
}

class _VerificationDocumentsChanged extends VerificationEvent {
  const _VerificationDocumentsChanged(this.documents);
  final List<VerificationDocument> documents;
  @override
  List<Object?> get props => [documents];
}

class _VerificationStatusChanged extends VerificationEvent {
  const _VerificationStatusChanged(this.status);
  final VerificationStatus status;
  @override
  List<Object?> get props => [status];
}

enum VerificationFlowStatus { idle, submitting, submitted, failure }

class VerificationState extends Equatable {
  const VerificationState({
    this.status = VerificationStatus.none,
    this.businessType,
    this.documents = const [],
    this.flowStatus = VerificationFlowStatus.idle,
    this.error,
  });

  final VerificationStatus status;
  final BusinessType? businessType;
  final List<VerificationDocument> documents;
  final VerificationFlowStatus flowStatus;
  final String? error;

  /// Documents the seller is *required* to submit, given the business type.
  List<VerificationDocumentType> get requiredDocuments {
    final base = VerificationDocumentType.values
        .where((t) => t.requiredForAll)
        .toList();
    if (businessType?.requiresBusinessDocs ?? false) {
      base.add(VerificationDocumentType.businessCertificate);
      base.add(VerificationDocumentType.taxId);
    }
    return base;
  }

  bool get canSubmit {
    if (!status.canSubmit) return false;
    final required = requiredDocuments;
    return required.every((t) =>
        documents.any((d) => d.type == t && d.isUploaded && !d.uploading));
  }

  VerificationDocument? documentFor(VerificationDocumentType type) {
    for (final d in documents) {
      if (d.type == type) return d;
    }
    return null;
  }

  VerificationState copyWith({
    VerificationStatus? status,
    BusinessType? businessType,
    List<VerificationDocument>? documents,
    VerificationFlowStatus? flowStatus,
    String? error,
    bool clearError = false,
  }) {
    return VerificationState(
      status: status ?? this.status,
      businessType: businessType ?? this.businessType,
      documents: documents ?? this.documents,
      flowStatus: flowStatus ?? this.flowStatus,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [status, businessType, documents, flowStatus, error];
}

class VerificationBloc extends Bloc<VerificationEvent, VerificationState> {
  VerificationBloc(this._repo) : super(const VerificationState()) {
    on<VerificationRequested>(_onRequested);
    on<VerificationDocumentUploadStarted>(_onUpload);
    on<VerificationDocumentRemoved>(_onRemove);
    on<VerificationSubmitted>(_onSubmitted);
    on<_VerificationDocumentsChanged>((e, emit) =>
        emit(state.copyWith(documents: e.documents)));
    on<_VerificationStatusChanged>(
        (e, emit) => emit(state.copyWith(status: e.status)));

    _docsSub = _repo
        .watchDocuments()
        .listen((docs) => add(_VerificationDocumentsChanged(docs)));
    _statusSub = _repo
        .watchStatus()
        .listen((s) => add(_VerificationStatusChanged(s)));
  }

  final SellerVerificationRepository _repo;
  StreamSubscription<List<VerificationDocument>>? _docsSub;
  StreamSubscription<VerificationStatus>? _statusSub;

  Future<void> _onRequested(
    VerificationRequested event,
    Emitter<VerificationState> emit,
  ) async {
    emit(state.copyWith(
      businessType: event.businessType,
      status: event.status,
      documents: _repo.documents,
    ));
  }

  Future<void> _onUpload(
    VerificationDocumentUploadStarted event,
    Emitter<VerificationState> emit,
  ) async {
    final result = await _repo.uploadDocument(
      type: event.type,
      file: event.file,
      fileExtension: event.fileExtension,
    );
    result.fold(
      ok: (_) {},
      err: (failure) => emit(state.copyWith(error: failure.message)),
    );
  }

  Future<void> _onRemove(
    VerificationDocumentRemoved event,
    Emitter<VerificationState> emit,
  ) async {
    final result = await _repo.removeDocument(event.type);
    result.fold(
      ok: (_) {},
      err: (failure) => emit(state.copyWith(error: failure.message)),
    );
  }

  Future<void> _onSubmitted(
    VerificationSubmitted event,
    Emitter<VerificationState> emit,
  ) async {
    emit(state.copyWith(
      flowStatus: VerificationFlowStatus.submitting,
      clearError: true,
    ));
    final result = await _repo.submit();
    result.fold(
      ok: (newStatus) => emit(state.copyWith(
        flowStatus: VerificationFlowStatus.submitted,
        status: newStatus,
      )),
      err: (failure) => emit(state.copyWith(
        flowStatus: VerificationFlowStatus.failure,
        error: failure.message,
      )),
    );
  }

  @override
  Future<void> close() async {
    await _docsSub?.cancel();
    await _statusSub?.cancel();
    return super.close();
  }
}
