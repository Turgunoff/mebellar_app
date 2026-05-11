import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/multilingual_text.dart';
import '../../../../shared/models/region.dart';
import '../../../../shared/models/shop_settings.dart';
import '../../../../shared/models/working_hours.dart';
import '../../../../shared/repositories/shop_settings_repository.dart';

sealed class ShopSettingsEvent extends Equatable {
  const ShopSettingsEvent();
  @override
  List<Object?> get props => const [];
}

class ShopSettingsRequested extends ShopSettingsEvent {
  const ShopSettingsRequested();
}

class ShopSettingsBasicsChanged extends ShopSettingsEvent {
  const ShopSettingsBasicsChanged({
    this.nameUz,
    this.nameRu,
    this.nameEn,
    this.descriptionUz,
    this.descriptionRu,
    this.descriptionEn,
    this.contactPhone,
    this.contactEmail,
    this.telegramUsername,
  });
  final String? nameUz;
  final String? nameRu;
  final String? nameEn;
  final String? descriptionUz;
  final String? descriptionRu;
  final String? descriptionEn;
  final String? contactPhone;
  final String? contactEmail;
  final String? telegramUsername;
  @override
  List<Object?> get props => [
        nameUz,
        nameRu,
        nameEn,
        descriptionUz,
        descriptionRu,
        descriptionEn,
        contactPhone,
        contactEmail,
        telegramUsername,
      ];
}

class ShopSettingsBrandColorChanged extends ShopSettingsEvent {
  const ShopSettingsBrandColorChanged(this.hex);
  final String hex;
  @override
  List<Object?> get props => [hex];
}

class ShopSettingsAddressChanged extends ShopSettingsEvent {
  const ShopSettingsAddressChanged({
    this.region,
    this.city,
    this.district,
    this.streetLine,
    this.lat,
    this.lng,
    this.clearDistrict = false,
  });
  final Region? region;
  final Region? city;
  final Region? district;
  final String? streetLine;
  final double? lat;
  final double? lng;
  final bool clearDistrict;
  @override
  List<Object?> get props => [
        region?.id,
        city?.id,
        district?.id,
        streetLine,
        lat,
        lng,
      ];
}

class ShopSettingsHoursChanged extends ShopSettingsEvent {
  const ShopSettingsHoursChanged({required this.day, required this.hours});
  final DayOfWeek day;
  final DayHours hours;
  @override
  List<Object?> get props => [day, hours];
}

class ShopSettingsVisibilityChanged extends ShopSettingsEvent {
  const ShopSettingsVisibilityChanged(this.visibility);
  final ShopVisibility visibility;
  @override
  List<Object?> get props => [visibility];
}

class ShopSettingsAssetUploaded extends ShopSettingsEvent {
  const ShopSettingsAssetUploaded({
    required this.kind,
    required this.file,
    required this.fileExtension,
  });
  final String kind;
  final File file;
  final String fileExtension;
  @override
  List<Object?> get props => [kind, file.path];
}

class ShopSettingsSaved extends ShopSettingsEvent {
  const ShopSettingsSaved();
}

enum ShopSettingsStatus { initial, loading, ready, saving, saved, failure }

class ShopSettingsState extends Equatable {
  const ShopSettingsState({
    this.status = ShopSettingsStatus.initial,
    this.settings,
    this.error,
    this.uploadingKind,
  });

  final ShopSettingsStatus status;
  final ShopSettings? settings;
  final String? error;

  /// Non-null while a logo or cover upload is in flight (`'logo'`/`'cover'`).
  final String? uploadingKind;

  ShopSettingsState copyWith({
    ShopSettingsStatus? status,
    ShopSettings? settings,
    String? error,
    bool clearError = false,
    String? uploadingKind,
    bool clearUploadingKind = false,
  }) {
    return ShopSettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      error: clearError ? null : (error ?? this.error),
      uploadingKind:
          clearUploadingKind ? null : (uploadingKind ?? this.uploadingKind),
    );
  }

  @override
  List<Object?> get props => [status, settings, error, uploadingKind];
}

class ShopSettingsBloc extends Bloc<ShopSettingsEvent, ShopSettingsState> {
  ShopSettingsBloc(this._repo) : super(const ShopSettingsState()) {
    on<ShopSettingsRequested>(_onRequested);
    on<ShopSettingsBasicsChanged>(_onBasics);
    on<ShopSettingsBrandColorChanged>(_onColor);
    on<ShopSettingsAddressChanged>(_onAddress);
    on<ShopSettingsHoursChanged>(_onHours);
    on<ShopSettingsVisibilityChanged>(_onVisibility);
    on<ShopSettingsAssetUploaded>(_onAsset);
    on<ShopSettingsSaved>(_onSaved);
  }

  final ShopSettingsRepository _repo;
  Timer? _saveDebounce;

  Future<void> _onRequested(
    ShopSettingsRequested event,
    Emitter<ShopSettingsState> emit,
  ) async {
    emit(state.copyWith(status: ShopSettingsStatus.loading, clearError: true));
    try {
      final settings = await _repo.get();
      emit(state.copyWith(
          status: ShopSettingsStatus.ready, settings: settings));
    } catch (e) {
      emit(state.copyWith(
          status: ShopSettingsStatus.failure, error: e.toString()));
    }
  }

  void _onBasics(
    ShopSettingsBasicsChanged event,
    Emitter<ShopSettingsState> emit,
  ) {
    final s = state.settings;
    if (s == null) return;
    final next = s.copyWith(
      name: MultilingualText(
        uz: event.nameUz ?? s.name.uz,
        ru: event.nameRu ?? s.name.ru,
        en: event.nameEn ?? s.name.en,
      ),
      description: MultilingualText(
        uz: event.descriptionUz ?? s.description.uz,
        ru: event.descriptionRu ?? s.description.ru,
        en: event.descriptionEn ?? s.description.en,
      ),
      contactPhone: event.contactPhone,
      contactEmail: event.contactEmail,
      telegramUsername: event.telegramUsername,
    );
    emit(state.copyWith(settings: next));
  }

  void _onColor(
    ShopSettingsBrandColorChanged event,
    Emitter<ShopSettingsState> emit,
  ) {
    final s = state.settings;
    if (s == null) return;
    emit(state.copyWith(settings: s.copyWith(brandColor: event.hex)));
  }

  void _onAddress(
    ShopSettingsAddressChanged event,
    Emitter<ShopSettingsState> emit,
  ) {
    final s = state.settings;
    if (s == null) return;
    emit(state.copyWith(
      settings: s.copyWith(
        region: event.region,
        city: event.city,
        district: event.district,
        clearDistrict: event.clearDistrict,
        streetLine: event.streetLine,
        lat: event.lat,
        lng: event.lng,
      ),
    ));
  }

  void _onHours(
    ShopSettingsHoursChanged event,
    Emitter<ShopSettingsState> emit,
  ) {
    final s = state.settings;
    if (s == null) return;
    emit(state.copyWith(
      settings: s.copyWith(
        workingHours: s.workingHours.setDay(event.day, event.hours),
      ),
    ));
  }

  void _onVisibility(
    ShopSettingsVisibilityChanged event,
    Emitter<ShopSettingsState> emit,
  ) {
    final s = state.settings;
    if (s == null) return;
    emit(state.copyWith(settings: s.copyWith(visibility: event.visibility)));
  }

  Future<void> _onAsset(
    ShopSettingsAssetUploaded event,
    Emitter<ShopSettingsState> emit,
  ) async {
    final s = state.settings;
    if (s == null) return;
    emit(state.copyWith(uploadingKind: event.kind, clearError: true));
    try {
      final url = await _repo.uploadAsset(
        kind: event.kind,
        file: event.file,
        fileExtension: event.fileExtension,
      );
      final next = event.kind == 'logo'
          ? s.copyWith(logoUrl: url)
          : s.copyWith(coverUrl: url);
      emit(state.copyWith(settings: next, clearUploadingKind: true));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), clearUploadingKind: true));
    }
  }

  Future<void> _onSaved(
    ShopSettingsSaved event,
    Emitter<ShopSettingsState> emit,
  ) async {
    final s = state.settings;
    if (s == null) return;
    emit(state.copyWith(status: ShopSettingsStatus.saving, clearError: true));
    try {
      final saved = await _repo.save(s);
      emit(state.copyWith(
          status: ShopSettingsStatus.saved, settings: saved));
    } catch (e) {
      emit(state.copyWith(
          status: ShopSettingsStatus.failure, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    _saveDebounce?.cancel();
    return super.close();
  }
}
