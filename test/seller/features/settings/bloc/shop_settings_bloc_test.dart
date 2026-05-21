import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/settings/bloc/services_bloc.dart';
import 'package:woody_app/seller/features/settings/bloc/shop_settings_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_seller_services_repository.dart';
import '../../../../fixtures/mocks/mock/mock_shop_settings_repository.dart';
import 'package:woody_app/shared/models/shop_service.dart';
import 'package:woody_app/shared/models/shop_settings.dart';

void main() {
  group('ShopSettingsBloc (mock repository)', () {
    blocTest<ShopSettingsBloc, ShopSettingsState>(
      'fetch -> seeded shop settings',
      build: () => ShopSettingsBloc(MockShopSettingsRepository()),
      act: (bloc) => bloc.add(const ShopSettingsRequested()),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state.status, ShopSettingsStatus.ready);
        expect(bloc.state.settings, isNotNull);
        expect(bloc.state.settings!.visibility, ShopVisibility.public);
      },
    );

    blocTest<ShopSettingsBloc, ShopSettingsState>(
      'visibility toggle marks shop hidden — customer catalog must skip it',
      build: () => ShopSettingsBloc(MockShopSettingsRepository()),
      act: (bloc) async {
        bloc.add(const ShopSettingsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(const ShopSettingsVisibilityChanged(ShopVisibility.hidden));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ShopSettingsSaved());
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      verify: (bloc) {
        expect(bloc.state.settings!.visibility, ShopVisibility.hidden);
        expect(bloc.state.status, ShopSettingsStatus.saved);
      },
    );

    blocTest<ShopSettingsBloc, ShopSettingsState>(
      'brand color change updates the snapshot',
      build: () => ShopSettingsBloc(MockShopSettingsRepository()),
      act: (bloc) async {
        bloc.add(const ShopSettingsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(const ShopSettingsBrandColorChanged('#FF5733'));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.settings!.brandColor, '#FF5733');
      },
    );
  });

  group('ServicesBloc (mock repository)', () {
    blocTest<ServicesBloc, ServicesState>(
      'fetch -> seeded service configs',
      build: () => ServicesBloc(MockSellerServicesRepository()),
      act: (bloc) => bloc.add(const ServicesRequested()),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state.status, ServicesStatus.ready);
        expect(bloc.state.configs.length, 6);
        // Default seed enables free_delivery, assembly, warranty.
        expect(
          bloc.state.configFor(ShopService.freeDelivery)?.enabled,
          isTrue,
        );
      },
    );

    blocTest<ServicesBloc, ServicesState>(
      'toggling a service flips the enabled flag',
      build: () => ServicesBloc(MockSellerServicesRepository()),
      act: (bloc) async {
        bloc.add(const ServicesRequested());
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(const ServiceToggled(
          service: ShopService.installment,
          enabled: true,
        ));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(
          bloc.state.configFor(ShopService.installment)?.enabled,
          isTrue,
        );
      },
    );
  });
}
