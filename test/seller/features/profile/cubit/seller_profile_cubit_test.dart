import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/auth/auth_repository.dart';
import 'package:woody_app/core/network/api_error.dart';
import 'package:woody_app/seller/features/profile/cubit/seller_profile_cubit.dart';
import 'package:woody_app/seller/features/profile/data/seller_identity_cache.dart';
import 'package:woody_app/shared/models/tariff.dart';
import 'package:woody_app/shared/models/verification_status.dart';
import 'package:woody_app/shared/repositories/seller_profile_repository.dart';

class _MockRepo extends Mock implements SellerProfileRepository {}

class _MockAuth extends Mock implements AuthRepository {}

class _MockCache extends Mock implements SellerIdentityCache {}

void main() {
  const uid = 'user-1';

  late _MockRepo repo;
  late _MockAuth auth;
  late _MockCache cache;

  setUpAll(() => registerFallbackValue(const SellerIdentitySnapshot()));

  setUp(() {
    repo = _MockRepo();
    auth = _MockAuth();
    cache = _MockCache();
    when(() => auth.currentUserId).thenReturn(uid);
    when(() => cache.write(any(), any())).thenAnswer((_) async {});
    // Shop + tariff are not the subject here — let them be "absent" (404) so
    // they never interfere with the verification assertions. The fetch is
    // async, so a failure surfaces as a rejected future (not a sync throw).
    when(() => repo.fetchShop())
        .thenAnswer((_) async => throw ApiError(status: 404, code: 'shop_not_found'));
    when(() => repo.fetchTariffCurrent())
        .thenAnswer((_) async => throw ApiError(status: 404, code: 'not_found'));
  });

  SellerIdentitySnapshot lastWritten() =>
      verify(() => cache.write(uid, captureAny())).captured.last
          as SellerIdentitySnapshot;

  test('a successful /seller/me surfaces the real verification status',
      () async {
    when(() => cache.read(uid)).thenReturn(null);
    when(() => repo.fetchMe()).thenAnswer(
      (_) async => {
        'verification_status': 'approved',
        'legal_name': 'Eldor',
        'shop_name': 'Mebel Shop',
      },
    );

    final cubit = SellerProfileCubit(repo, auth, cache);
    await cubit.load();

    expect(cubit.state.verificationStatus, VerificationStatus.approved);
    expect(cubit.state.isLoading, isFalse);
  });

  test(
    'a transient /seller/me failure (401) does NOT downgrade an approved '
    'seller, and does NOT poison the cache',
    () async {
      const cached = SellerIdentitySnapshot(
        shopName: 'Mebel Shop',
        sellerName: 'Eldor',
        verificationStatus: VerificationStatus.approved,
        plan: TariffPlan.free,
      );
      when(() => cache.read(uid)).thenReturn(cached);
      when(() => repo.fetchMe()).thenAnswer(
        (_) async => throw ApiError(status: 401, code: 'not_authenticated'),
      );

      final cubit = SellerProfileCubit(repo, auth, cache);
      await cubit.load();

      expect(
        cubit.state.verificationStatus,
        VerificationStatus.approved,
        reason: 'a transient 401 must keep the last-known approved status',
      );
      expect(
        lastWritten().verificationStatus,
        VerificationStatus.approved,
        reason: 'the cache must not be overwritten with none on a hiccup',
      );
    },
  );

  test('a 404 on /seller/me means there is no seller row yet → none',
      () async {
    when(() => cache.read(uid)).thenReturn(null);
    when(() => repo.fetchMe()).thenAnswer(
      (_) async => throw ApiError(status: 404, code: 'seller_profile_not_found'),
    );

    final cubit = SellerProfileCubit(repo, auth, cache);
    await cubit.load();

    expect(cubit.state.verificationStatus, VerificationStatus.none);
  });
}
