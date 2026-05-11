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

  Future<void> _onRequested(
    ServicesRequested event,
    Emitter<ServicesState> emit,
  ) async {
    emit(state.copyWith(status: ServicesStatus.loading, clearError: true));
    try {
      final list = await _repo.list();
      emit(state.copyWith(status: ServicesStatus.ready, configs: list));
    } catch (e) {
      emit(state.copyWith(status: ServicesStatus.failure, error: e.toString()));
    }
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
    try {
      final saved = await _repo.save(state.configs);
      emit(state.copyWith(status: ServicesStatus.saved, configs: saved));
    } catch (e) {
      emit(state.copyWith(status: ServicesStatus.failure, error: e.toString()));
    }
  }
}
