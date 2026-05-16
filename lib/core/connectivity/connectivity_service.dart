import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'package:woody_app/core/logging/talker.dart';

/// Connection state surfaced to UI. We deliberately keep it boolean — the
/// banner doesn't care whether the user is on wifi or cellular, only whether
/// requests are likely to succeed.
enum ConnectivityStatus { online, offline }

/// Connectivity supervisor used by the global offline banner + offline-first
/// cache fallback in repositories.
///
/// Two implementations:
///
/// - [RealConnectivityService] — production: combines `connectivity_plus`
///   (instant link-state change) with `internet_connection_checker_plus`
///   (actual HEAD-pings) so a wifi-without-internet ("captive portal")
///   doesn't fool the app into thinking it's online.
/// - [MockConnectivityService] — tests and the in-app dev panel, which need
///   to flip status synchronously.
abstract class ConnectivityService {
  ConnectivityStatus get status;
  bool get isOnline => status == ConnectivityStatus.online;
  Stream<ConnectivityStatus> watch();

  /// Manual override — used by the dev panel and when the API client itself
  /// detects a network error so the banner appears even without a fresh
  /// `connectivity_plus` event.
  void overrideStatus(ConnectivityStatus next);

  Future<void> dispose();
}

class MockConnectivityService implements ConnectivityService {
  MockConnectivityService();

  ConnectivityStatus _status = ConnectivityStatus.online;
  final _controller = StreamController<ConnectivityStatus>.broadcast();

  @override
  ConnectivityStatus get status => _status;

  @override
  bool get isOnline => _status == ConnectivityStatus.online;

  @override
  Stream<ConnectivityStatus> watch() => _controller.stream;

  @override
  void overrideStatus(ConnectivityStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

/// Production implementation.
///
/// Pipeline:
///
/// 1. `connectivity_plus` emits a `ConnectivityResult` list whenever the
///    link layer changes (wifi up/down, cellular toggled, etc). If the
///    list reduces to `[none]` we flip to offline immediately — no point
///    pinging when there is no carrier.
/// 2. Otherwise we ask `internet_connection_checker_plus` to verify the
///    link with short HEAD requests to reliable hosts. This catches the
///    "captive wifi without DHCP" / "router up, ISP down" cases.
/// 3. The merged result is debounced and broadcast through [watch].
///
/// Both subscriptions are torn down by [dispose].
class RealConnectivityService implements ConnectivityService {
  RealConnectivityService({
    Connectivity? connectivity,
    InternetConnection? checker,
  }) : _connectivity = connectivity ?? Connectivity(),
       _checker = checker ?? InternetConnection() {
    _start();
  }

  final Connectivity _connectivity;
  final InternetConnection _checker;
  final _controller = StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus _status = ConnectivityStatus.online;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<InternetStatus>? _netSub;
  bool _hasCarrier = true;

  Future<void> _start() async {
    // Seed the initial value so the first listener doesn't see a stale
    // `online` default while the platform channels are still warming up.
    try {
      final initialCarrier = await _connectivity.checkConnectivity();
      _hasCarrier = !_isNone(initialCarrier);
      final initialReachable = _hasCarrier
          ? await _checker.hasInternetAccess
          : false;
      _emit(
        initialReachable
            ? ConnectivityStatus.online
            : ConnectivityStatus.offline,
      );
    } catch (e, st) {
      // First-launch race conditions on iOS sometimes throw before the
      // network extension is ready. Default to online and let the streams
      // correct it shortly after.
      talker.handle(e, st, 'ConnectivityService: initial probe failed');
      _emit(ConnectivityStatus.online);
    }

    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      _hasCarrier = !_isNone(results);
      if (!_hasCarrier) {
        _emit(ConnectivityStatus.offline);
      }
      // When a carrier appears we don't trust it immediately — wait for
      // the internet checker's verdict via _netSub below.
    });

    _netSub = _checker.onStatusChange.listen((status) {
      if (!_hasCarrier) {
        _emit(ConnectivityStatus.offline);
        return;
      }
      _emit(
        status == InternetStatus.connected
            ? ConnectivityStatus.online
            : ConnectivityStatus.offline,
      );
    });
  }

  bool _isNone(List<ConnectivityResult> results) {
    return results.isEmpty || results.every((r) => r == ConnectivityResult.none);
  }

  void _emit(ConnectivityStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  @override
  ConnectivityStatus get status => _status;

  @override
  bool get isOnline => _status == ConnectivityStatus.online;

  @override
  Stream<ConnectivityStatus> watch() => _controller.stream;

  @override
  void overrideStatus(ConnectivityStatus next) {
    _emit(next);
  }

  @override
  Future<void> dispose() async {
    await _connSub?.cancel();
    await _netSub?.cancel();
    if (!_controller.isClosed) await _controller.close();
  }
}
