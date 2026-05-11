import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'connectivity_service.dart';

/// What the overlay banner should show right now.
///
/// `initial`  — cold boot, before the connectivity service has produced its
///              first verdict; the banner stays hidden.
/// `online`   — actual internet is reachable.
/// `offline`  — no carrier or the reachability check failed.
enum NetworkStatus { initial, online, offline }

/// Global single-source-of-truth for "are we online?".
///
/// Wraps [ConnectivityService] in a Bloc-friendly surface so widgets can
/// `BlocConsumer` / `context.watch` without reaching into GetIt. The
/// transition from offline → online is left to the UI to celebrate (the
/// banner shows a green "restored" pill for ~2s before hiding); this cubit
/// only owns the raw truth.
class NetworkCubit extends Cubit<NetworkStatus> {
  NetworkCubit(this._service) : super(NetworkStatus.initial) {
    // Seed from the service's current snapshot so consumers that read state
    // before the first stream tick get the right value.
    _maybeEmit(_fromService(_service.status));
    _sub = _service.watch().listen((status) {
      _maybeEmit(_fromService(status));
    });
  }

  final ConnectivityService _service;
  StreamSubscription<ConnectivityStatus>? _sub;

  static NetworkStatus _fromService(ConnectivityStatus s) =>
      s == ConnectivityStatus.online
          ? NetworkStatus.online
          : NetworkStatus.offline;

  void _maybeEmit(NetworkStatus next) {
    if (state == next) return;
    emit(next);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
