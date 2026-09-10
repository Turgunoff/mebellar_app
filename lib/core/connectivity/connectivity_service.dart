import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'package:woody_app/config/app_config.dart';
import 'package:woody_app/core/logging/app_logger.dart';

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
///   (instant link-state change) with a [ReachabilityProbe] (actual HTTP
///   pings) so a wifi-without-internet ("captive portal") doesn't fool the
///   app into thinking it's online.
/// - [MockConnectivityService] — tests and the in-app dev panel, which need
///   to flip status synchronously.
abstract class ConnectivityService {
  ConnectivityStatus get status;
  bool get isOnline => status == ConnectivityStatus.online;
  Stream<ConnectivityStatus> watch();

  /// Manual override — used by the dev panel to force either state. It skips
  /// the confirmation grace period [RealConnectivityService] applies to real
  /// probe failures.
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

/// Seam over `internet_connection_checker_plus`, so the offline-confirmation
/// logic in [RealConnectivityService] is testable without real HTTP.
abstract class ReachabilityProbe {
  /// Runs one round of checks right now.
  Future<bool> get isReachable;

  /// Emits on every *change* of the polled verdict.
  Stream<bool> get changes;

  /// How often to poll. We tighten this while offline (recover fast) and
  /// relax it while online (don't hammer our own `/health` from every
  /// installed app).
  void setPollInterval(Duration interval);

  Future<void> dispose();
}

/// Production probe.
///
/// Two deliberate departures from the package defaults, both of which caused
/// a false "no internet" banner on a merely *slow* link:
///
/// - **Our own API is the first host we ask.** The package's default hosts
///   (`pokeapi.co`, `jsonplaceholder.typicode.com`, …) can be slow or blocked
///   here while `api.woody.uz` answers fine — and the reverse case (our API
///   down, the rest of the internet up) is not something the banner should
///   claim is an internet outage either, hence the Cloudflare fallback.
/// - **8s per request, not the package's 3s.** A 3s HEAD loses the race on a
///   congested mobile link long before the app's own Dio timeouts (15s
///   connect / 30s receive) would give up.
///
/// Any HTTP status below 500 counts as reachable: our `/health` is a
/// GET-only FastAPI route and answers HEAD with 405, and a 405 still proves
/// the packets made a full round trip.
class InternetCheckerProbe implements ReachabilityProbe {
  InternetCheckerProbe({InternetConnection? checker})
    : _checker = checker ?? _build();

  static const _requestTimeout = Duration(seconds: 8);

  final InternetConnection _checker;

  static InternetConnection _build() {
    final host = AppConfig.woodyApiUrl.replaceAll(RegExp(r'/+$'), '');

    return InternetConnection.createInstance(
      useDefaultOptions: false,
      checkInterval: RealConnectivityService.onlinePollInterval,
      customCheckOptions: [
        if (host.isNotEmpty)
          InternetCheckOption(
            uri: Uri.parse('$host/api/v1/health'),
            timeout: _requestTimeout,
            responseStatusFn: (response) => response.statusCode < 500,
          ),
        InternetCheckOption(
          uri: Uri.parse('https://one.one.one.one'),
          timeout: _requestTimeout,
          responseStatusFn: (response) => response.statusCode < 500,
        ),
      ],
    );
  }

  @override
  Future<bool> get isReachable => _checker.hasInternetAccess;

  @override
  Stream<bool> get changes =>
      _checker.onStatusChange.map((s) => s == InternetStatus.connected);

  @override
  void setPollInterval(Duration interval) =>
      _checker.setIntervalAndResetTimer(interval);

  @override
  Future<void> dispose() async {}
}

/// Production implementation.
///
/// Pipeline:
///
/// 1. `connectivity_plus` emits a `ConnectivityResult` list whenever the
///    link layer changes (wifi up/down, cellular toggled, etc). If the
///    list reduces to `[none]` we flip to offline immediately — no point
///    pinging when there is no carrier.
/// 2. Otherwise the [ReachabilityProbe] verifies the link with short HTTP
///    requests. This catches the "captive wifi without DHCP" / "router up,
///    ISP down" cases.
/// 3. **A single failed probe never raises the banner.** Going offline is
///    confirmed by a second check after [offlineGrace]; only a sustained
///    failure is an outage. A slow link that loses one race stays silent.
///    Coming back online is emitted immediately — an unnecessary banner is
///    the expensive mistake here, not an unnecessary dismissal.
///
/// Both subscriptions and the confirmation timer are torn down by [dispose].
class RealConnectivityService implements ConnectivityService {
  RealConnectivityService({
    Connectivity? connectivity,
    ReachabilityProbe? probe,
    this.offlineGrace = _defaultOfflineGrace,
  }) : _connectivity = connectivity ?? Connectivity(),
       _probe = probe ?? InternetCheckerProbe() {
    _startup = _start();
  }

  /// How long to wait before re-checking a failed probe. Long enough that a
  /// slow round trip finishes, short enough that a real outage still surfaces
  /// while the user is looking at the screen.
  static const _defaultOfflineGrace = Duration(seconds: 4);

  /// Poll cadence while we believe we're online. Deliberately slow — this is
  /// a background heartbeat against our own `/health`, once per app instance.
  static const onlinePollInterval = Duration(seconds: 20);

  /// Poll cadence while the banner is up: recovery should feel instant.
  static const offlinePollInterval = Duration(seconds: 3);

  final Connectivity _connectivity;
  final ReachabilityProbe _probe;
  final Duration offlineGrace;
  final _controller = StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus _status = ConnectivityStatus.online;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<bool>? _reachSub;
  bool _hasCarrier = true;

  Timer? _confirmTimer;
  late final Future<void> _startup;

  /// Completes once the initial probe has run and both subscriptions are
  /// live. Only tests await it — production code just listens to [watch].
  @visibleForTesting
  Future<void> get started => _startup;

  /// Invalidates an in-flight confirmation whose verdict has been overtaken
  /// by a newer signal (carrier drop, recovery, dev-panel override).
  int _confirmToken = 0;

  Future<void> _start() async {
    // Seed the initial value so the first listener doesn't see a stale
    // `online` default while the platform channels are still warming up.
    try {
      final initialCarrier = await _connectivity.checkConnectivity();
      _hasCarrier = !_isNone(initialCarrier);
      if (!_hasCarrier) {
        _goOffline();
      } else if (!await _probe.isReachable) {
        // Cold boot on a slow link is exactly when the first probe times out;
        // confirm before painting a banner over the splash.
        _scheduleOfflineConfirmation();
      }
    } catch (e, st) {
      // First-launch race conditions on iOS sometimes throw before the
      // network extension is ready. Default to online and let the streams
      // correct it shortly after.
      appLog.handle(e, st, 'ConnectivityService: initial probe failed');
      _goOnline();
    }

    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      _hasCarrier = !_isNone(results);
      if (!_hasCarrier) {
        _goOffline();
      }
      // When a carrier appears we don't trust it immediately — wait for
      // the probe's verdict via _reachSub below.
    });

    _reachSub = _probe.changes.listen((reachable) {
      if (!_hasCarrier) {
        _goOffline();
        return;
      }
      if (reachable) {
        _goOnline();
      } else {
        _scheduleOfflineConfirmation();
      }
    });
  }

  bool _isNone(List<ConnectivityResult> results) {
    return results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
  }

  /// Re-checks once after [offlineGrace] and only then commits to offline.
  void _scheduleOfflineConfirmation() {
    if (_status == ConnectivityStatus.offline) return;
    if (_confirmTimer?.isActive ?? false) return;

    final token = ++_confirmToken;
    _confirmTimer = Timer(offlineGrace, () async {
      if (token != _confirmToken) return;
      if (!_hasCarrier) {
        _goOffline();
        return;
      }
      bool reachable;
      try {
        reachable = await _probe.isReachable;
      } catch (_) {
        reachable = false;
      }
      if (token != _confirmToken) return;
      reachable ? _goOnline() : _goOffline();
    });
  }

  void _goOnline() {
    _cancelConfirmation();
    _emit(ConnectivityStatus.online);
  }

  void _goOffline() {
    _cancelConfirmation();
    _emit(ConnectivityStatus.offline);
  }

  void _cancelConfirmation() {
    _confirmTimer?.cancel();
    _confirmTimer = null;
    _confirmToken++;
  }

  void _emit(ConnectivityStatus next) {
    if (_status == next) return;
    _status = next;
    _probe.setPollInterval(
      next == ConnectivityStatus.online
          ? onlinePollInterval
          : offlinePollInterval,
    );
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
    next == ConnectivityStatus.online ? _goOnline() : _goOffline();
  }

  @override
  Future<void> dispose() async {
    _cancelConfirmation();
    await _connSub?.cancel();
    await _reachSub?.cancel();
    await _probe.dispose();
    if (!_controller.isClosed) await _controller.close();
  }
}
