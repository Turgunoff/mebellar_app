import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/seller/features/settings/bloc/services_bloc.dart';
import 'package:woody_app/shared/models/shop_service.dart';
import 'package:woody_app/shared/models/shop_service_config.dart';
import 'package:woody_app/shared/repositories/seller_services_repository.dart';

class _MockServicesRepo extends Mock implements SellerServicesRepository {}

ShopServiceConfig _config({bool enabled = false}) =>
    ShopServiceConfig(service: ShopService.freeDelivery, enabled: enabled);

void main() {
  late _MockServicesRepo repo;

  setUpAll(() => registerFallbackValue(const <ShopServiceConfig>[]));
  setUp(() => repo = _MockServicesRepo());

  group('ServicesRequested', () {
    blocTest<ServicesBloc, ServicesState>(
      'Ok result emits [loading, ready] with the config list',
      build: () {
        when(repo.list).thenAnswer((_) async => Ok([_config()]));
        return ServicesBloc(repo);
      },
      act: (bloc) => bloc.add(const ServicesRequested()),
      expect: () => [
        isA<ServicesState>()
            .having((s) => s.status, 'status', ServicesStatus.loading),
        isA<ServicesState>()
            .having((s) => s.status, 'status', ServicesStatus.ready)
            .having((s) => s.configs.length, 'configs', 1),
      ],
    );

    blocTest<ServicesBloc, ServicesState>(
      'Err result emits [loading, failure] carrying the failure message',
      build: () {
        when(repo.list).thenAnswer(
          (_) async => const Err<List<ShopServiceConfig>>(
            ServerFailure(message: 'services unavailable'),
          ),
        );
        return ServicesBloc(repo);
      },
      act: (bloc) => bloc.add(const ServicesRequested()),
      expect: () => [
        isA<ServicesState>()
            .having((s) => s.status, 'status', ServicesStatus.loading),
        isA<ServicesState>()
            .having((s) => s.status, 'status', ServicesStatus.failure)
            .having((s) => s.error, 'error', 'services unavailable'),
      ],
    );
  });

  group('ServicesSaved', () {
    blocTest<ServicesBloc, ServicesState>(
      'Ok result emits [saving, saved]',
      build: () {
        when(() => repo.save(any()))
            .thenAnswer((_) async => Ok([_config(enabled: true)]));
        return ServicesBloc(repo);
      },
      seed: () => ServicesState(
        status: ServicesStatus.ready,
        configs: [_config(enabled: true)],
      ),
      act: (bloc) => bloc.add(const ServicesSaved()),
      expect: () => [
        isA<ServicesState>()
            .having((s) => s.status, 'status', ServicesStatus.saving),
        isA<ServicesState>()
            .having((s) => s.status, 'status', ServicesStatus.saved),
      ],
    );

    blocTest<ServicesBloc, ServicesState>(
      'Err result emits [saving, failure]',
      build: () {
        when(() => repo.save(any())).thenAnswer(
          (_) async => const Err<List<ShopServiceConfig>>(
            NetworkFailure(message: 'no connection'),
          ),
        );
        return ServicesBloc(repo);
      },
      seed: () => ServicesState(
        status: ServicesStatus.ready,
        configs: [_config()],
      ),
      act: (bloc) => bloc.add(const ServicesSaved()),
      expect: () => [
        isA<ServicesState>()
            .having((s) => s.status, 'status', ServicesStatus.saving),
        isA<ServicesState>()
            .having((s) => s.status, 'status', ServicesStatus.failure)
            .having((s) => s.error, 'error', 'no connection'),
      ],
    );
  });

  blocTest<ServicesBloc, ServicesState>(
    'ServiceToggled flips the enabled flag of the matching config in place',
    build: () => ServicesBloc(repo),
    seed: () => ServicesState(
      status: ServicesStatus.ready,
      configs: [_config()],
    ),
    act: (bloc) => bloc.add(
      const ServiceToggled(service: ShopService.freeDelivery, enabled: true),
    ),
    expect: () => [
      isA<ServicesState>().having(
        (s) => s.configFor(ShopService.freeDelivery)?.enabled,
        'enabled',
        true,
      ),
    ],
  );
}
