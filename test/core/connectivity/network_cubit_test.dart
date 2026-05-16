import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/connectivity/connectivity_service.dart';
import 'package:woody_app/core/connectivity/network_cubit.dart';

/// Holds the service for the current `blocTest` so `act` can drive it — the
/// cubit deliberately exposes no service handle of its own.
late MockConnectivityService _service;

void main() {
  test('seeds online from the connectivity service snapshot', () {
    final service = MockConnectivityService(); // defaults to online
    final cubit = NetworkCubit(service);
    expect(cubit.state, NetworkStatus.online);
    cubit.close();
    service.dispose();
  });

  blocTest<NetworkCubit, NetworkStatus>(
    'reflects offline -> online transitions from the service stream',
    build: () {
      _service = MockConnectivityService();
      return NetworkCubit(_service);
    },
    act: (cubit) {
      _service.overrideStatus(ConnectivityStatus.offline);
      _service.overrideStatus(ConnectivityStatus.online);
    },
    expect: () => [NetworkStatus.offline, NetworkStatus.online],
    tearDown: () => _service.dispose(),
  );

  blocTest<NetworkCubit, NetworkStatus>(
    'does not re-emit when the status is unchanged',
    build: () {
      _service = MockConnectivityService();
      return NetworkCubit(_service);
    },
    act: (cubit) {
      _service.overrideStatus(ConnectivityStatus.offline);
      _service.overrideStatus(ConnectivityStatus.offline);
    },
    expect: () => [NetworkStatus.offline],
    tearDown: () => _service.dispose(),
  );
}
