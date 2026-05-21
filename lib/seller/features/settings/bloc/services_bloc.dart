import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/shop_service.dart';
import '../../../../shared/models/shop_service_config.dart';
import '../../../../shared/repositories/seller_services_repository.dart';

sealed class ServicesEvent extends Equatable {
  const ServicesEvent();
  @override
  List<Object?> get props => const [];
}

class ServicesRequested extends ServicesEvent {
  const ServicesRequested();
}

class ServiceToggled extends ServicesEvent {
  const ServiceToggled({required this.service, required this.enabled});
  final ShopService service;
  final bool enabled;
  @override
  List<Object?> get props => [service.code, enabled];
}

class ServiceConfigChanged extends ServicesEvent {
  const ServiceConfigChanged(this.config);
  final ShopServiceConfig config;
  @override
  List<Object?> get props => [config];
}

class ServicesSaved extends ServicesEvent {
  const ServicesSaved();
}

enum ServicesStatus { initial, loading, ready, saving, saved, failure }

class ServicesState extends Equatable {
  const ServicesState({
    this.status = ServicesStatus.initial,
    this.configs = const [],
    this.error,
  });

  final ServicesStatus status;
  final List<ShopServiceConfig> configs;
  final String? error;

  ShopServiceConfig? configFor(ShopService service) {
    for (final c in configs) {
      if (c.service.code == service.code) return c;
    }
    return null;
  }

  ServicesState copyWith({
    ServicesStatus? status,
    List<ShopServiceConfig>? configs,
    String? error,
    bool clearError = false,
  }) {
    return ServicesState(
      status: status ?? this.status,
      configs: configs ?? this.configs,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, configs, error];
}

class ServicesBloc extends Bloc<ServicesEvent, ServicesState> {
  ServicesBloc(this._repo) : super(const ServicesState()) {
    on<ServicesRequested>(_onRequested);
    on<ServiceToggled>(_onToggled);
    on<ServiceConfigChanged>(_onConfigChanged);
    on<ServicesSaved>(_onSaved);
  }

  final SellerServicesRepository _repo;

  /// Every service the UI knows about. The DB only stores rows for services
  /// the seller has touched at least once, so on first load (or for any
  /// service the seller has never opened) the list comes back missing
  /// those service codes — the UI then renders empty cards under each
  /// section title. We seed the missing entries with a default-disabled
  /// config so every section has a tile to render.
  static const List<ShopService> _allServices = [
    ShopService.freeDelivery,
    ShopService.express,
    ShopService.assembly,
    ShopService.warranty,
    ShopService.installment,
    ShopService.customOrder,
  ];

  /// Merges DB-fetched configs with defaults for the services the seller
  /// has never configured. Preserves the order in [_allServices] so the
  /// section grouping stays stable across saves.
  List<ShopServiceConfig> _withDefaults(List<ShopServiceConfig> fromDb) {
    final byCode = {for (final c in fromDb) c.service.code: c};
    return [
      for (final service in _allServices)
        byCode[service.code] ??
            ShopServiceConfig(service: service, enabled: false),
    ];
  }

  Future<void> _onRequested(
    ServicesRequested event,
    Emitter<ServicesState> emit,
  ) async {
    emit(state.copyWith(status: ServicesStatus.loading, clearError: true));
    final result = await _repo.list();
    result.fold(
      ok: (list) => emit(state.copyWith(
        status: ServicesStatus.ready,
        configs: _withDefaults(list),
      )),
      err: (failure) => emit(
        state.copyWith(status: ServicesStatus.failure, error: failure.message),
      ),
    );
  }

  void _onToggled(ServiceToggled event, Emitter<ServicesState> emit) {
    final next = state.configs.map((c) {
      if (c.service.code == event.service.code) {
        return c.copyWith(enabled: event.enabled);
      }
      return c;
    }).toList();
    emit(state.copyWith(configs: next));
  }

  void _onConfigChanged(
    ServiceConfigChanged event,
    Emitter<ServicesState> emit,
  ) {
    final next = state.configs.map((c) {
      if (c.service.code == event.config.service.code) return event.config;
      return c;
    }).toList();
    emit(state.copyWith(configs: next));
  }

  Future<void> _onSaved(
    ServicesSaved event,
    Emitter<ServicesState> emit,
  ) async {
    emit(state.copyWith(status: ServicesStatus.saving, clearError: true));
    final result = await _repo.save(state.configs);
    result.fold(
      ok: (saved) =>
          emit(state.copyWith(status: ServicesStatus.saved, configs: saved)),
      err: (failure) => emit(
        state.copyWith(status: ServicesStatus.failure, error: failure.message),
      ),
    );
  }
}
