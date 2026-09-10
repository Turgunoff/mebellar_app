import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/connectivity/connectivity_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

/// Drives [RealConnectivityService] without touching the network: the test
/// decides what a probe returns and when the probe stream ticks.
class _FakeProbe implements ReachabilityProbe {
  bool reachable = true;

  /// Makes the next N direct probes fail regardless of [reachable] — models
  /// a slow link losing the race on the cold-boot check.
  int failNextProbes = 0;

  Duration? lastInterval;

  final _controller = StreamController<bool>.broadcast();

  void tick(bool value) {
    reachable = value;
    _controller.add(value);
  }

  @override
  Future<bool> get isReachable async {
    if (failNextProbes > 0) {
      failNextProbes--;
      return false;
    }
    return reachable;
  }

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  void setPollInterval(Duration interval) => lastInterval = interval;

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

/// The grace period used by the tests that need it to *elapse*. Short enough
/// to keep the suite fast.
const _shortGrace = Duration(milliseconds: 40);

/// Used by the tests that assert something happens **without** waiting for
/// confirmation: anything observed inside [_waitFor]'s window provably skipped
/// the grace period.
const _neverElapsingGrace = Duration(seconds: 30);

/// Polls until [condition] holds. Deterministic where a fixed `delayed` is
/// flaky — a loaded CI machine just takes a few more turns.
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Waits long enough that a [_shortGrace] confirmation would have fired.
Future<void> _pastGrace() =>
    Future<void>.delayed(_shortGrace * 3 + const Duration(milliseconds: 40));

void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> linkChanges;
  late _FakeProbe probe;
  late RealConnectivityService service;

  setUp(() {
    connectivity = _MockConnectivity();
    linkChanges = StreamController<List<ConnectivityResult>>.broadcast();
    probe = _FakeProbe();
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => linkChanges.stream);
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
  });

  tearDown(() async {
    await service.dispose();
    await linkChanges.close();
    await probe.dispose();
  });

  /// Builds the service and waits until its async `_start` has wired up both
  /// subscriptions, so a `tick` in the test body is never dropped.
  Future<RealConnectivityService> booted({Duration grace = _shortGrace}) async {
    service = RealConnectivityService(
      connectivity: connectivity,
      probe: probe,
      offlineGrace: grace,
    );
    await service.started;
    return service;
  }

  test('one failed probe does not raise the banner on a slow link', () async {
    await booted();

    final seen = <ConnectivityStatus>[];
    service.watch().listen(seen.add);

    // The probe lost the race once — but the link answers again before the
    // grace period elapses, so the user never sees the offline banner.
    probe.tick(false);
    probe.reachable = true;
    await _pastGrace();

    expect(seen, isEmpty);
    expect(service.status, ConnectivityStatus.online);
  });

  test('sustained failure flips to offline after the grace period', () async {
    await booted();

    final seen = <ConnectivityStatus>[];
    service.watch().listen(seen.add);

    probe.tick(false);
    await _waitFor(() => seen.isNotEmpty);

    expect(seen, [ConnectivityStatus.offline]);
    expect(service.status, ConnectivityStatus.offline);
  });

  test('losing the carrier goes offline immediately, no grace', () async {
    await booted(grace: _neverElapsingGrace);

    final seen = <ConnectivityStatus>[];
    service.watch().listen(seen.add);

    linkChanges.add([ConnectivityResult.none]);
    await _waitFor(() => seen.isNotEmpty);

    expect(seen, [ConnectivityStatus.offline]);
  });

  test('reachability returning flips back to online', () async {
    await booted();

    probe.tick(false);
    await _waitFor(() => service.status == ConnectivityStatus.offline);
    expect(service.status, ConnectivityStatus.offline);

    final seen = <ConnectivityStatus>[];
    service.watch().listen(seen.add);

    // No confirmation on the way back — an unnecessary banner is the
    // expensive mistake, not an unnecessary dismissal.
    probe.tick(true);
    await _waitFor(() => seen.isNotEmpty);

    expect(seen, [ConnectivityStatus.online]);
  });

  test('a failed cold-boot probe is confirmed before the banner', () async {
    // Boot probe failed, but the link is actually fine — the re-check clears
    // it and the banner never appears.
    probe.failNextProbes = 1;
    await booted();
    await _pastGrace();

    expect(service.status, ConnectivityStatus.online);
  });

  test('polls harder while offline and backs off once online', () async {
    await booted();

    probe.tick(false);
    await _waitFor(() => service.status == ConnectivityStatus.offline);
    final offlineInterval = probe.lastInterval;

    probe.tick(true);
    await _waitFor(() => service.status == ConnectivityStatus.online);
    final onlineInterval = probe.lastInterval;

    expect(offlineInterval, isNotNull);
    expect(onlineInterval, isNotNull);
    expect(offlineInterval!, lessThan(onlineInterval!));
  });

  test('the dev-panel override bypasses the grace period', () async {
    await booted(grace: _neverElapsingGrace);

    final seen = <ConnectivityStatus>[];
    service.watch().listen(seen.add);

    service.overrideStatus(ConnectivityStatus.offline);
    await _waitFor(() => seen.isNotEmpty);

    expect(seen, [ConnectivityStatus.offline]);
  });
}
