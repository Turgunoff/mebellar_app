import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:woody_app/core/auth/auth_cubit.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSession extends Mock implements Session {}

class _MockUser extends Mock implements User {}

void main() {
  test('a null Supabase client leaves the cubit unauthenticated', () {
    // The offline / unit-test build wires AuthCubit with a null client.
    final cubit = AuthCubit(null);
    expect(cubit.state, const AppAuthUnauthenticated());
    cubit.close();
  });

  test('an existing session is restored as authenticated at construction',
      () {
    final supabase = _MockSupabase();
    final auth = _MockGoTrue();
    final session = _MockSession();
    final user = _MockUser();
    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentSession).thenReturn(session);
    when(() => session.user).thenReturn(user);
    when(() => user.id).thenReturn('user-1');
    when(() => auth.onAuthStateChange)
        .thenAnswer((_) => const Stream<AuthState>.empty());

    final cubit = AuthCubit(supabase);
    expect(cubit.state, const AppAuthAuthenticated('user-1'));
    cubit.close();
  });

  test('no current session leaves the cubit unauthenticated', () {
    final supabase = _MockSupabase();
    final auth = _MockGoTrue();
    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentSession).thenReturn(null);
    when(() => auth.onAuthStateChange)
        .thenAnswer((_) => const Stream<AuthState>.empty());

    final cubit = AuthCubit(supabase);
    expect(cubit.state, const AppAuthUnauthenticated());
    cubit.close();
  });
}
