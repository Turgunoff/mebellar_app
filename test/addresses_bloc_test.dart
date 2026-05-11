import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/profile/addresses/bloc/addresses_bloc.dart';
import 'package:woody_app/shared/mock/mock_address_repository.dart';
import 'package:woody_app/shared/mock/mock_orders_data.dart';
import 'package:woody_app/shared/models/address.dart';

void main() {
  group('AddressesBloc (mock repository)', () {
    blocTest<AddressesBloc, AddressesState>(
      'fetch -> 2 seeded addresses',
      build: () => AddressesBloc(MockAddressRepository()),
      act: (bloc) => bloc.add(const AddressesRequested()),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state.status, AddressesStatus.ready);
        expect(bloc.state.addresses.length, 2);
        expect(bloc.state.defaultAddress, isNotNull);
      },
    );

    blocTest<AddressesBloc, AddressesState>(
      'set default reassigns the default flag',
      build: () => AddressesBloc(MockAddressRepository()),
      act: (bloc) async {
        bloc.add(const AddressesRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        // Promote the second address (currently non-default) to default.
        final second = bloc.state.addresses[1];
        bloc.add(AddressDefaultSet(second.id));
        await Future<void>.delayed(const Duration(milliseconds: 700));
      },
      verify: (bloc) {
        expect(
          bloc.state.addresses.where((a) => a.isDefault).length,
          1,
          reason: 'Exactly one default address at any time',
        );
        expect(bloc.state.addresses[1].isDefault, isTrue);
      },
    );

    blocTest<AddressesBloc, AddressesState>(
      'create -> appends new address',
      build: () => AddressesBloc(MockAddressRepository()),
      act: (bloc) async {
        bloc.add(const AddressesRequested());
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(AddressCreated(_sampleAddress()));
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      verify: (bloc) {
        expect(bloc.state.addresses.length, 3);
      },
    );
  });
}

Address _sampleAddress() => Address(
      id: 'addr-tmp',
      label: 'Yangi',
      recipientName: 'Test User',
      phone: '+998 99 999 99 99',
      region: MockOrdersData.tashkentCity,
      city: MockOrdersData.tashkentCity,
      district: MockOrdersData.chilanzar,
      streetLine: 'Mustaqillik 100',
    );
