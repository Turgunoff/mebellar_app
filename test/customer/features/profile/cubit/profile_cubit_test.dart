import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/auth/auth_repository.dart';
import 'package:woody_app/customer/features/profile/cubit/profile_cubit.dart';
import 'package:woody_app/shared/models/me.dart';
import 'package:woody_app/shared/models/verification_status.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository auth;

  setUp(() => auth = _MockAuthRepository());

  blocTest<ProfileCubit, ProfileState>(
    'applySignup emits the freshly-registered profile values',
    build: () {
      when(() => auth.currentUserId).thenReturn('u1');
      return ProfileCubit(auth);
    },
    act: (cubit) =>
        cubit.applySignup(name: 'Aziz Karimov', phone: '+998901234567'),
    expect: () => [
      isA<ProfileState>()
          .having((s) => s.id, 'id', 'u1')
          .having((s) => s.name, 'name', 'Aziz Karimov')
          .having((s) => s.phone, 'phone', '+998901234567'),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'fetch with no signed-in user emits a blank profile',
    build: () {
      when(() => auth.currentUserId).thenReturn(null);
      return ProfileCubit(auth);
    },
    act: (cubit) => cubit.fetch(),
    expect: () => [const ProfileState()],
  );

  blocTest<ProfileCubit, ProfileState>(
    'fetch seeds identity from the JWT then resolves the /me profile',
    build: () {
      when(() => auth.currentUserId).thenReturn('u1');
      when(() => auth.currentUserPhone).thenReturn('+998901112233');
      when(() => auth.fetchMe()).thenAnswer(
        (_) async => const Me(
          id: 'u1',
          phone: '+998901112233',
          fullName: 'Aziz Karimov',
          avatarUrl: 'https://cdn/x.png',
        ),
      );
      return ProfileCubit(auth);
    },
    act: (cubit) => cubit.fetch(),
    expect: () => [
      isA<ProfileState>()
          .having((s) => s.id, 'id', 'u1')
          .having((s) => s.phone, 'phone', '+998901112233')
          .having((s) => s.isLoading, 'isLoading', true),
      isA<ProfileState>()
          .having((s) => s.name, 'name', 'Aziz Karimov')
          .having((s) => s.avatarUrl, 'avatarUrl', 'https://cdn/x.png')
          .having((s) => s.isLoading, 'isLoading', false),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'updateProfile sends name/email/avatar and emits the returned profile',
    build: () {
      when(
        () => auth.updateProfile(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          avatarUrl: any(named: 'avatarUrl'),
        ),
      ).thenAnswer(
        (_) async => const Me(
          id: 'u1',
          phone: '+998901112233',
          fullName: 'Aziz Karimov',
          email: 'aziz@example.com',
          avatarUrl: 'https://pub.r2.dev/u1/9.jpg',
        ),
      );
      return ProfileCubit(auth);
    },
    act: (cubit) => cubit.updateProfile(
      name: 'Aziz Karimov',
      email: 'aziz@example.com',
      avatarUrl: 'https://pub.r2.dev/u1/9.jpg',
    ),
    expect: () => [
      isA<ProfileState>()
          .having((s) => s.name, 'name', 'Aziz Karimov')
          .having((s) => s.email, 'email', 'aziz@example.com')
          .having(
            (s) => s.avatarUrl,
            'avatarUrl',
            'https://pub.r2.dev/u1/9.jpg',
          ),
    ],
    verify: (_) {
      verify(
        () => auth.updateProfile(
          fullName: 'Aziz Karimov',
          email: 'aziz@example.com',
          avatarUrl: 'https://pub.r2.dev/u1/9.jpg',
        ),
      ).called(1);
    },
  );

  blocTest<ProfileCubit, ProfileState>(
    'dismissRejectedBanner flips the flag so the CTA banner takes over',
    build: () {
      when(() => auth.currentUserId).thenReturn('u1');
      return ProfileCubit(auth);
    },
    act: (cubit) => cubit.dismissRejectedBanner(),
    expect: () => [
      isA<ProfileState>().having(
        (s) => s.rejectedBannerDismissed,
        'rejectedBannerDismissed',
        true,
      ),
    ],
  );

  test('displayName falls back to a placeholder when no name is set', () {
    expect(const ProfileState(name: 'Aziz').displayName, 'Aziz');
    expect(const ProfileState().displayName, 'Ism kiritilmagan');
  });

  test('secondaryLine surfaces the phone, or null when empty', () {
    expect(
      const ProfileState(phone: '+998901112233').secondaryLine,
      '+998901112233',
    );
    expect(const ProfileState().secondaryLine, isNull);
  });

  test('isSignedIn reflects a non-empty id', () {
    expect(const ProfileState(id: 'u1').isSignedIn, isTrue);
    expect(const ProfileState().isSignedIn, isFalse);
  });

  test('seller status maps from the /me seller profile', () {
    const approved = ProfileState(
      sellerVerificationStatus: VerificationStatus.approved,
    );
    expect(approved.isSellerApproved, isTrue);
    expect(approved.isSellerRejected, isFalse);
  });
}
