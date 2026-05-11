import 'dart:async';

/// Connection state surfaced to UI. We deliberately keep it boolean — the
/// banner doesn't care whether the user is on wifi or cellular, only whether
/// requests are likely to succeed.
enum ConnectivityStatus { online, offline }

/// Connectivity supervisor used by the offline banner + offline-first cache
/// fallback in repositories. Sprint 11 ships a mock-driven implementation
/// (`MockConnectivityService`) so the simulator screen can flip the state on
/// demand. A production variant wired to `connectivity_plus` will be added
/// once we run real-device QA in Sprint 12.
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
