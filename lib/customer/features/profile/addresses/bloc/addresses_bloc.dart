import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/models/address.dart';
import '../../../../../shared/repositories/address_repository.dart';

sealed class AddressesEvent extends Equatable {
  const AddressesEvent();
  @override
  List<Object?> get props => const [];
}

class AddressesRequested extends AddressesEvent {
  const AddressesRequested();
}

class AddressCreated extends AddressesEvent {
  const AddressCreated(this.address);
  final Address address;
  @override
  List<Object?> get props => [address];
}

class AddressUpdated extends AddressesEvent {
  const AddressUpdated(this.address);
  final Address address;
  @override
  List<Object?> get props => [address];
}

class AddressDeleted extends AddressesEvent {
  const AddressDeleted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class AddressDefaultSet extends AddressesEvent {
  const AddressDefaultSet(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

enum AddressesStatus { initial, loading, ready, mutating, failure }

class AddressesState extends Equatable {
  const AddressesState({
    this.status = AddressesStatus.initial,
    this.addresses = const [],
    this.error,
  });

  final AddressesStatus status;
  final List<Address> addresses;
  final String? error;

  Address? get defaultAddress {
    if (addresses.isEmpty) return null;
    return addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => addresses.first,
    );
  }

  AddressesState copyWith({
    AddressesStatus? status,
    List<Address>? addresses,
    String? error,
    bool clearError = false,
  }) {
    return AddressesState(
      status: status ?? this.status,
      addresses: addresses ?? this.addresses,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, addresses, error];
}

class AddressesBloc extends Bloc<AddressesEvent, AddressesState> {
  AddressesBloc(this._repo) : super(const AddressesState()) {
    on<AddressesRequested>(_onRequested);
    on<AddressCreated>(_onCreated);
    on<AddressUpdated>(_onUpdated);
    on<AddressDeleted>(_onDeleted);
    on<AddressDefaultSet>(_onDefault);
  }

  final AddressRepository _repo;

  Future<void> _onRequested(
    AddressesRequested event,
    Emitter<AddressesState> emit,
  ) async {
    emit(state.copyWith(status: AddressesStatus.loading, clearError: true));
    try {
      final list = await _repo.list();
      emit(state.copyWith(status: AddressesStatus.ready, addresses: list));
    } catch (e) {
      emit(state.copyWith(
          status: AddressesStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCreated(
    AddressCreated event,
    Emitter<AddressesState> emit,
  ) async {
    emit(state.copyWith(status: AddressesStatus.mutating, clearError: true));
    try {
      await _repo.create(event.address);
      final list = await _repo.list();
      emit(state.copyWith(status: AddressesStatus.ready, addresses: list));
    } catch (e) {
      emit(state.copyWith(
          status: AddressesStatus.ready, error: e.toString()));
    }
  }

  Future<void> _onUpdated(
    AddressUpdated event,
    Emitter<AddressesState> emit,
  ) async {
    emit(state.copyWith(status: AddressesStatus.mutating, clearError: true));
    try {
      await _repo.update(event.address);
      final list = await _repo.list();
      emit(state.copyWith(status: AddressesStatus.ready, addresses: list));
    } catch (e) {
      emit(state.copyWith(
          status: AddressesStatus.ready, error: e.toString()));
    }
  }

  Future<void> _onDeleted(
    AddressDeleted event,
    Emitter<AddressesState> emit,
  ) async {
    final previous = state.addresses;
    emit(state.copyWith(
      status: AddressesStatus.mutating,
      addresses: previous.where((a) => a.id != event.id).toList(),
    ));
    try {
      await _repo.delete(event.id);
      final list = await _repo.list();
      emit(state.copyWith(status: AddressesStatus.ready, addresses: list));
    } catch (e) {
      emit(state.copyWith(
        status: AddressesStatus.ready,
        addresses: previous,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onDefault(
    AddressDefaultSet event,
    Emitter<AddressesState> emit,
  ) async {
    emit(state.copyWith(status: AddressesStatus.mutating, clearError: true));
    try {
      await _repo.setDefault(event.id);
      final list = await _repo.list();
      emit(state.copyWith(status: AddressesStatus.ready, addresses: list));
    } catch (e) {
      emit(state.copyWith(
          status: AddressesStatus.ready, error: e.toString()));
    }
  }
}
