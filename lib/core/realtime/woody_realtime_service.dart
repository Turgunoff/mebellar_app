import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/app_config.dart';
import '../logging/talker.dart';
import '../network/token_store.dart';

/// WebSocket-backed realtime fan-out for api.woody.uz.
///
/// One physical connection per app instance — the server multiplexes
/// per-user events on `user:<id>:events`. Inbound frames are JSON envelopes
/// `{type, data}`; this service routes by `type` so feature blocs subscribe
/// to typed streams without each one re-implementing the WS wiring.
///
/// Reconnect uses exponential-backoff-with-jitter (1 s → 30 s cap) so a
/// dropped server doesn't thrash the client. The hello frame from the
/// server confirms the JWT is valid; on receive failures the loop retries
/// silently. Sign-out clears the token, which causes the next reconnect
/// attempt to skip the dial — the auth layer drives `start`/`stop`.
class WoodyRealtimeService {
  WoodyRealtimeService({required TokenStore tokens}) : _tokens = tokens;

  final TokenStore _tokens;

  final _events = StreamController<RealtimeEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _reconnectTimer;
  bool _running = false;
  int _backoffStep = 0;

  /// Stream of every inbound event. Most callers should use [eventsOfType]
  /// for a typed slice instead.
  Stream<RealtimeEvent> get events => _events.stream;

  /// Pre-filtered stream for one event type (`chat_message`,
  /// `order_status_changed`, etc.). Matches against
  /// `RealtimeEvent.type`.
  Stream<RealtimeEvent> eventsOfType(String type) =>
      _events.stream.where((e) => e.type == type);

  bool get isConnected => _channel != null && _channelSub != null;

  /// Open the connection. Idempotent. Backs off and retries on transient
  /// failures. Call once after sign-in completes; the auth cubit watches
  /// [TokenStore.changes] and calls [stop] on sign-out.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _connect();
  }

  /// Tear down the connection and stop reconnecting. Safe to call multiple
  /// times.
  Future<void> stop() async {
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _channelSub?.cancel();
    _channelSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Closing an already-closed channel is fine.
    }
    _channel = null;
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }

  Future<void> _connect() async {
    if (!_running) return;
    final base = AppConfig.woodyApiUrl;
    if (base.isEmpty) {
      // No backend configured — bail out silently. The auth flow is gated
      // on `hasWoodyApi` anyway, so this branch protects unit tests.
      return;
    }
    final pair = await _tokens.read();
    if (pair == null) {
      // Not signed in — wait for a token to land. AuthCubit listens for
      // sign-in and re-invokes start, which retries this path.
      _running = false;
      return;
    }

    final wsUrl = _toWsUrl(base, pair.accessToken);
    try {
      final channel = WebSocketChannel.connect(wsUrl);
      _channel = channel;
      _channelSub = channel.stream.listen(
        _onMessage,
        onDone: _onDone,
        onError: _onError,
        cancelOnError: false,
      );
      _backoffStep = 0;
    } catch (e, st) {
      talker.handle(e, st, 'WoodyRealtimeService: connect failed');
      _scheduleReconnect();
    }
  }

  Uri _toWsUrl(String base, String token) {
    final stripped = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final asWs = stripped
        .replaceFirst(RegExp(r'^https://'), 'wss://')
        .replaceFirst(RegExp(r'^http://'), 'ws://');
    return Uri.parse('$asWs/api/v1/realtime/ws?token=$token');
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final type = decoded['type'];
      if (type is! String) return;
      _events.add(
        RealtimeEvent(
          type: type,
          data: decoded['data'] is Map<String, dynamic>
              ? decoded['data'] as Map<String, dynamic>
              : const {},
          raw: decoded,
        ),
      );
    } catch (e, st) {
      talker.handle(e, st, 'WoodyRealtimeService: malformed frame');
    }
  }

  void _onDone() {
    _channel = null;
    _channelSub = null;
    _scheduleReconnect();
  }

  void _onError(Object error, StackTrace stack) {
    talker.handle(error, stack, 'WoodyRealtimeService: stream error');
    _channel = null;
    _channelSub = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_running) return;
    _reconnectTimer?.cancel();
    final base = min(1 << _backoffStep, 30);
    final jitter = Random().nextDouble() * 0.5 + 0.75; // 0.75..1.25x
    final delay = Duration(milliseconds: (base * 1000 * jitter).round());
    _backoffStep = (_backoffStep + 1).clamp(0, 5);
    _reconnectTimer = Timer(delay, () {
      unawaited(_connect());
    });
  }
}

/// Typed envelope. `data` is the deserialised payload object; `raw` carries
/// the entire JSON frame for forward-compat fields the typed parsers don't
/// know about yet.
class RealtimeEvent {
  const RealtimeEvent({
    required this.type,
    required this.data,
    required this.raw,
  });

  final String type;
  final Map<String, dynamic> data;
  final Map<String, dynamic> raw;
}
