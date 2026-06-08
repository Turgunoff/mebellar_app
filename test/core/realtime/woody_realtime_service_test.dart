import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/realtime/woody_realtime_service.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// A [RealtimeConnection] the test drives by hand — emit frames, close, or
/// fail the handshake without any real socket.
class _FakeConnection implements RealtimeConnection {
  _FakeConnection({Object? handshakeError}) {
    if (handshakeError != null) {
      _ready.completeError(handshakeError);
    } else {
      _ready.complete();
    }
  }

  final _ready = Completer<void>();
  final _frames = StreamController<dynamic>();
  bool closed = false;
  Uri? uri;
  String? accessToken;

  void emit(dynamic frame) => _frames.add(frame);
  Future<void> done() => _frames.close();

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<dynamic> get stream => _frames.stream;

  @override
  Future<void> close() async {
    closed = true;
    if (!_frames.isClosed) await _frames.close();
  }
}

void main() {
  late _MockSecureStorage storage;
  late TokenStore store;

  setUp(() async {
    storage = _MockSecureStorage();
    final mem = <String, String>{};
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((i) async => mem[i.namedArguments[#key] as String]);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((i) async {
      mem[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((i) async {
      mem.remove(i.namedArguments[#key] as String);
    });
    store = TokenStore(storage);
    await store.write(
      const TokenPair(accessToken: 'ACCESS', refreshToken: 'REFRESH'),
    );
  });

  // Builds the service with an injected connector that records each dial and
  // hands back a fresh [_FakeConnection]; `connections` keeps them in order.
  ({WoodyRealtimeService service, List<_FakeConnection> connections}) make({
    Object? handshakeError,
  }) {
    final connections = <_FakeConnection>[];
    final service = WoodyRealtimeService(
      tokens: store,
      baseUrlOverride: 'https://api.woody.test',
      connector: (uri, {required accessToken}) {
        final conn = _FakeConnection(handshakeError: handshakeError)
          ..uri = uri
          ..accessToken = accessToken;
        connections.add(conn);
        return conn;
      },
    );
    return (service: service, connections: connections);
  }

  test('dials the WS path with NO token in the URL — auth rides the token '
      'the connector forwards to the Authorization header', () async {
    final h = make();
    await h.service.start();

    final conn = h.connections.single;
    expect(conn.uri!.scheme, 'wss');
    expect(conn.uri!.path, '/api/v1/realtime/ws');
    expect(conn.uri!.queryParameters.containsKey('token'), isFalse);
    expect(conn.uri!.query, isEmpty);
    // Production routes this into the `Authorization: Bearer` header.
    expect(conn.accessToken, 'ACCESS');

    await h.service.dispose();
  });

  test('start is idempotent — a second call does not redial', () async {
    final h = make();
    await h.service.start();
    await h.service.start();
    expect(h.connections, hasLength(1));
    expect(h.service.isConnected, isTrue);
    await h.service.dispose();
  });

  test('routes inbound frames by type and ignores malformed ones', () async {
    final h = make();
    await h.service.start();

    final chat = <RealtimeEvent>[];
    final all = <RealtimeEvent>[];
    final subA = h.service.eventsOfType('chat_message').listen(chat.add);
    final subB = h.service.events.listen(all.add);

    h.connections.single
      ..emit(jsonEncode({
        'type': 'chat_message',
        'data': {'text': 'hi'},
      }))
      ..emit(jsonEncode({'type': 'order_status_changed', 'data': {}}))
      ..emit('not-json') // malformed: ignored, must not throw
      ..emit(jsonEncode({'no_type': true})) // no type: ignored
      ..emit(jsonEncode('a-bare-string')); // not an object: ignored
    await Future<void>.delayed(Duration.zero);

    expect(all.map((e) => e.type), ['chat_message', 'order_status_changed']);
    expect(chat, hasLength(1));
    expect(chat.single.data['text'], 'hi');

    await subA.cancel();
    await subB.cancel();
    await h.service.dispose();
  });

  test('stop tears the connection down and closes it', () async {
    final h = make();
    await h.service.start();
    expect(h.service.isConnected, isTrue);

    await h.service.stop();

    expect(h.service.isConnected, isFalse);
    expect(h.connections.single.closed, isTrue);
    await h.service.dispose();
  });

  test('a server-side close drops the connection (and schedules a retry)',
      () async {
    final h = make();
    await h.service.start();

    await h.connections.single.done(); // stream closes → onDone
    await Future<void>.delayed(Duration.zero);

    expect(h.service.isConnected, isFalse);
    // stop() cancels the pending reconnect timer so the test leaves none.
    await h.service.stop();
    await h.service.dispose();
  });

  test('a failed handshake stays quiet and leaves the socket disconnected',
      () async {
    final h = make(handshakeError: StateError('ws unavailable'));
    await h.service.start();
    await Future<void>.delayed(Duration.zero);

    expect(h.service.isConnected, isFalse);
    expect(h.connections, hasLength(1)); // dialed once, then backs off
    await h.service.stop();
    await h.service.dispose();
  });
}
