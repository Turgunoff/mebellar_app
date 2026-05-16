import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:woody_app/customer/features/profile/cubit/profile_cubit.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockGoTrue extends Mock implements GoTrueClient {}

void main() {
  late _MockSupabase supabase;

  setUp(() => supabase = _MockSupabase());

  blocTest<ProfileCubit, ProfileState>(
    'applySignup emits the freshly-registered profile values',
    build: () => ProfileCubit(supabase),
    act: (cubit) => cubit.applySignup(
      name: 'Aziz Karimov',
      phone: '+998901234567',
      email: 'aziz@example.com',
    ),
    expect: () => [
      isA<ProfileState>()
          .having((s) => s.name, 'name', 'Aziz Karimov')
          .having((s) => s.phone, 'phone', '+998901234567')
          .having((s) => s.email, 'email', 'aziz@example.com'),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'fetch with no signed-in user emits a blank profile',
    build: () {
      final auth = _MockGoTrue();
      when(() => supabase.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(null);
      return ProfileCubit(supabase);
    },
    act: (cubit) => cubit.fetch(),
    expect: () => [const ProfileState()],
  );

  test('displayName falls back to email then to a placeholder', () {
    expect(
      const ProfileState(name: 'Aziz').displayName,
      'Aziz',
    );
    expect(
      const ProfileState(email: 'a@b.c').displayName,
      'a@b.c',
    );
    expect(const ProfileState().displayName, 'Ism kiritilmagan');
  });
}
