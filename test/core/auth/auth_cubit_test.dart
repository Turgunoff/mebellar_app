import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/auth/auth_cubit.dart';
import 'package:woody_app/core/network/token_store.dart';

/// In-memory TokenStore double — bypasses flutter_secure_storage so the
/// cubit can be exercised without a platform channel.
class _FakeTokenStore implements TokenStore {
  final _controller = StreamController<TokenPair?>.broadcast();
  TokenPair? _current;

  @override
  Stream<TokenPair?> get changes => _controller.stream;

  @override
  TokenPair? get current => _current;

  @override
  Future<TokenPair?> read() async => _current;

  @override
  Future<void> write(TokenPair pair) async {
    _current = pair;
    _controller.add(pair);
  }

  @override
  Future<void> clear() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

// Pre-generated JWT with payload {"sub":"user-1"} and base64Url-encoded
// header + signature. Signature is irrelevant — `jwtClaim` deliberately
// does not verify it. Build script: see `core/network/jwt_utils.dart`.
const _kTokenForUser1 =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyLTEifQ.signature';

void main() {
  test('empty TokenStore leaves the cubit unauthenticated', () async {
    final store = _FakeTokenStore();
    final cubit = AuthCubit(tokens: store);
    await Future.microtask(() {});
    expect(cubit.state, const AppAuthUnauthenticated());
    await cubit.close();
    await store.dispose();
  });

  test('writing a token pair transitions to authenticated with sub claim',
      () async {
    final store = _FakeTokenStore();
    final cubit = AuthCubit(tokens: store);
    final states = <AppAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await store.write(
      const TokenPair(accessToken: _kTokenForUser1, refreshToken: 'r'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(states.last, const AppAuthAuthenticated('user-1'));
    await sub.cancel();
    await cubit.close();
    await store.dispose();
  });

  test('clearing the store transitions back to unauthenticated', () async {
    final store = _FakeTokenStore();
    await store.write(
      const TokenPair(accessToken: _kTokenForUser1, refreshToken: 'r'),
    );
    final cubit = AuthCubit(tokens: store);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, const AppAuthAuthenticated('user-1'));

    await store.clear();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, const AppAuthUnauthenticated());

    await cubit.close();
    await store.dispose();
  });
}
