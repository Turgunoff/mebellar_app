import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/category_model.dart';
import '../../../../shared/repositories/supabase_category_repository.dart';

sealed class CategoriesEvent extends Equatable {
  const CategoriesEvent();
  @override
  List<Object?> get props => const [];
}

class CategoriesRequested extends CategoriesEvent {
  const CategoriesRequested();
}

enum CategoriesStatus { initial, loading, ready, failure }

class CategoriesState extends Equatable {
  const CategoriesState({
    this.status = CategoriesStatus.initial,
    this.categories = const [],
    this.error,
  });

  final CategoriesStatus status;
  final List<CategoryModel> categories;
  final String? error;

  CategoriesState copyWith({
    CategoriesStatus? status,
    List<CategoryModel>? categories,
    String? error,
    bool clearError = false,
  }) {
    return CategoriesState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, categories, error];
}

class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  CategoriesBloc(this._source) : super(const CategoriesState()) {
    on<CategoriesRequested>(_onRequested);
  }

  final CategoryDataSource _source;

  Future<void> _onRequested(
    CategoriesRequested event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(state.copyWith(status: CategoriesStatus.loading, clearError: true));
    try {
      final categories = await _source.list();
      emit(state.copyWith(
        status: CategoriesStatus.ready,
        categories: categories,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CategoriesStatus.failure,
        error: e.toString(),
      ));
    }
  }
}
