import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cache_service.dart';

enum CacheStatus { initial, calculating, ready, clearing }

class AppCacheState extends Equatable {
  const AppCacheState({this.status = CacheStatus.initial, this.sizeBytes});

  final CacheStatus status;

  /// Last computed cache size in bytes; null until the first calculation lands.
  final int? sizeBytes;

  bool get isBusy =>
      status == CacheStatus.calculating || status == CacheStatus.clearing;

  /// Trailing-slot label, or null while the size is still unknown so the UI can
  /// show its loading affordance. Anything under 1 MB collapses to "< 1 MB",
  /// which is also what an emptied cache reads as.
  String? get sizeLabel {
    final b = sizeBytes;
    if (b == null) return null;
    return formatCacheBytes(b);
  }

  AppCacheState copyWith({CacheStatus? status, int? sizeBytes}) =>
      AppCacheState(
        status: status ?? this.status,
        sizeBytes: sizeBytes ?? this.sizeBytes,
      );

  @override
  List<Object?> get props => [status, sizeBytes];
}

/// Human-readable cache size. Sub-megabyte values (including an emptied cache)
/// read as "< 1 MB"; otherwise MB with one decimal, switching to GB past 1024.
String formatCacheBytes(int bytes) {
  const mb = 1024 * 1024;
  const gb = mb * 1024;
  if (bytes < mb) return '< 1 MB';
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  final mbValue = bytes / mb;
  // Drop the decimal once we're into double digits to keep the label compact.
  return '${mbValue.toStringAsFixed(mbValue >= 10 ? 0 : 1)} MB';
}

/// Global, shared owner of the disposable-cache size + clear flow. Registered
/// once in the root DI scope and provided above Phoenix, so the customer and
/// seller settings screens drive (and reflect) the exact same state.
class AppCacheCubit extends Cubit<AppCacheState> {
  AppCacheCubit(this._service) : super(const AppCacheState());

  final CacheService _service;

  /// Recomputes the on-disk cache size. Skipped while a clear is in flight
  /// (the clear recomputes on its own when it finishes).
  Future<void> calculate() async {
    if (state.status == CacheStatus.clearing) return;
    emit(state.copyWith(status: CacheStatus.calculating));
    try {
      final bytes = await _service.sizeBytes();
      if (isClosed) return;
      emit(AppCacheState(status: CacheStatus.ready, sizeBytes: bytes));
    } catch (_) {
      if (isClosed) return;
      // Keep the previous size on screen rather than flashing an error.
      emit(state.copyWith(status: CacheStatus.ready));
    }
  }

  /// Clears the disposable caches, then recomputes the size so every listening
  /// screen updates to the emptied state immediately.
  Future<void> clearCache() async {
    if (state.status == CacheStatus.clearing) return;
    emit(state.copyWith(status: CacheStatus.clearing));
    try {
      await _service.clear();
    } catch (_) {
      // Best-effort — fall through to recompute whatever remains.
    }
    final bytes = await _service.sizeBytes();
    if (isClosed) return;
    emit(AppCacheState(status: CacheStatus.ready, sizeBytes: bytes));
  }
}
