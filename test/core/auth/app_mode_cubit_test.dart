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
    // Default to an active session so the seller-mode boot tests below isolate
    // the approval guard; the logged-out tests override this to false.
    when(() => box.get('session_active')).thenReturn(true);
    when(
      () => box.put(any<dynamic>(), any<dynamic>()),
    ).thenAnswer((_) async {});
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

  test('boot guard demotes a persisted seller mode when logged out', () {
    // Approved seller, but no live session (logged out / 401-forced sign-out).
    when(() => box.get('app_mode')).thenReturn('seller');
    when(() => box.get('seller_approval_cached')).thenReturn(true);
    when(() => box.get('session_active')).thenReturn(false);
    final cubit = AppModeCubit(box);
    expect(cubit.state, AppMode.customer);
    cubit.close();
  });

  test('boot guard treats a missing session flag as logged out', () {
    when(() => box.get('app_mode')).thenReturn('seller');
    when(() => box.get('seller_approval_cached')).thenReturn(true);
    when(() => box.get('session_active')).thenReturn(null);
    final cubit = AppModeCubit(box);
    expect(cubit.state, AppMode.customer);
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

  blocTest<AppModeCubit, AppMode>(
    'demoteToCustomer() flips a seller-mode user back to customer on logout',
    build: () {
      when(() => box.get('app_mode')).thenReturn('seller');
      when(() => box.get('seller_approval_cached')).thenReturn(true);
      when(() => box.get('session_active')).thenReturn(true);
      return AppModeCubit(box);
    },
    act: (cubit) => cubit.demoteToCustomer(),
    expect: () => [AppMode.customer],
    verify: (_) {
      verify(() => box.put('session_active', false)).called(1);
      verify(() => box.put('app_mode', 'customer')).called(1);
    },
  );

  blocTest<AppModeCubit, AppMode>(
    'demoteToCustomer() only clears the flag when already in customer mode',
    build: () => AppModeCubit(box), // boots customer (nothing persisted)
    act: (cubit) => cubit.demoteToCustomer(),
    expect: () => const <AppMode>[],
    verify: (_) {
      verify(() => box.put('session_active', false)).called(1);
      verifyNever(() => box.put('app_mode', 'customer'));
    },
  );

  blocTest<AppModeCubit, AppMode>(
    'markSessionActive() re-promotes an approved seller demoted only for the '
    'missing session flag (first launch after the flag was introduced)',
    build: () {
      // Persisted seller + approval cached, but no session flag yet — the boot
      // guard demotes to customer. Once the restored session confirms, the
      // user should land back on seller.
      when(() => box.get('app_mode')).thenReturn('seller');
      when(() => box.get('seller_approval_cached')).thenReturn(true);
      when(() => box.get('session_active')).thenReturn(null);
      return AppModeCubit(box);
    },
    act: (cubit) => cubit.markSessionActive(),
    expect: () => [AppMode.seller],
    verify: (_) => verify(() => box.put('session_active', true)).called(1),
  );

  blocTest<AppModeCubit, AppMode>(
    'markSessionActive() does NOT re-promote when the preference is customer',
    build: () {
      when(() => box.get('app_mode')).thenReturn('customer');
      when(() => box.get('seller_approval_cached')).thenReturn(true);
      when(() => box.get('session_active')).thenReturn(null);
      return AppModeCubit(box);
    },
    act: (cubit) => cubit.markSessionActive(),
    expect: () => const <AppMode>[],
  );
}
