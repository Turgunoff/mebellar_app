import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/config/app_mode.dart';
import 'package:woody_app/core/auth/app_mode_cubit.dart';

class _MockBox extends Mock implements Box {}

void main() {
  late _MockBox box;

  setUp(() {
    box = _MockBox();
    when(() => box.get('app_mode')).thenReturn(null);
    when(() => box.get('seller_approval_cached')).thenReturn(false);
    when(() => box.put(any<dynamic>(), any<dynamic>()))
        .thenAnswer((_) async {});
  });

  test('boots into customer mode when nothing is persisted', () {
    final cubit = AppModeCubit(box);
    expect(cubit.state, AppMode.customer);
    cubit.close();
  });

  test('boot guard downgrades a persisted seller mode without approval', () {
    when(() => box.get('app_mode')).thenReturn('seller');
    when(() => box.get('seller_approval_cached')).thenReturn(false);
    final cubit = AppModeCubit(box);
    // Persisted preference is `seller`, but the cached approval flag is
    // false — the security guard demotes the session to customer.
    expect(cubit.state, AppMode.customer);
    cubit.close();
  });

  test('boot honors a persisted seller mode when approval is cached', () {
    when(() => box.get('app_mode')).thenReturn('seller');
    when(() => box.get('seller_approval_cached')).thenReturn(true);
    final cubit = AppModeCubit(box);
    expect(cubit.state, AppMode.seller);
    cubit.close();
  });

  blocTest<AppModeCubit, AppMode>(
    'switchMode(seller) emits seller and persists the choice',
    build: () => AppModeCubit(box),
    act: (cubit) => cubit.switchMode(AppMode.seller),
    expect: () => [AppMode.seller],
    verify: (_) => verify(() => box.put('app_mode', 'seller')).called(1),
  );

  blocTest<AppModeCubit, AppMode>(
    'switchMode to the current mode is a no-op',
    build: () => AppModeCubit(box),
    act: (cubit) => cubit.switchMode(AppMode.customer),
    expect: () => const <AppMode>[],
  );

  blocTest<AppModeCubit, AppMode>(
    'recordSellerApproval(false) demotes a seller-mode user to customer',
    build: () {
      when(() => box.get('app_mode')).thenReturn('seller');
      when(() => box.get('seller_approval_cached')).thenReturn(true);
      return AppModeCubit(box);
    },
    act: (cubit) => cubit.recordSellerApproval(false),
    expect: () => [AppMode.customer],
  );
}
