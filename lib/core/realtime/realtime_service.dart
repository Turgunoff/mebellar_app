import 'package:supabase_flutter/supabase_flutter.dart';

/// Row payload Supabase delivers on a postgres change (`newRecord` /
/// `oldRecord`).
typedef RealtimeRow = Map<String, dynamic>;

/// Equality filter applied to a realtime table subscription — mirrors the
/// `column=eq.value` filters the legacy listeners hand-built into channel
/// names (`'public:orders:shop_id=eq.$shopId'`).
class RealtimeFilter {
  const RealtimeFilter.eq(this.column, this.value)
      : type = PostgresChangeFilterType.eq;

  final PostgresChangeFilterType type;
  final String column;
  final Object value;

  PostgresChangeFilter toSupabase() =>
      PostgresChangeFilter(type: type, column: column, value: value);
}

/// Handle to one live channel, returned by [RealtimeService.subscribe].
///
/// Call [close] to drop just this channel; or let [RealtimeService.disposeAll]
/// take every channel down with the owning DI scope.
class RealtimeSubscription {
  RealtimeSubscription._(this.channelName, this._close);

  /// Inert handle for offline / mock builds with no Supabase client.
  RealtimeSubscription._noop(this.channelName) : _close = (() async {});

  final String channelName;
  final Future<void> Function() _close;
  bool _closed = false;

  bool get isClosed => _closed;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _close();
  }
}

/// Standardises the Supabase realtime channel lifecycle.
///
/// Feature services (`NewOrdersListener`, `OrderTrackingService`, the upcoming
/// `SupabaseSellerOrderRepository`) currently each hand-roll
/// `client.channel(...).subscribe()` / `unsubscribe()` pairs — easy to leak.
/// They should instead borrow channels from a scope-owned [RealtimeService]
/// and let [disposeAll] run from the DI scope's dispose callback. That closes
/// the ROADMAP B.7 "audit realtime channel disposal" gap by construction.
class RealtimeService {
  RealtimeService(this._client);

  final SupabaseClient? _client;
  final Map<String, RealtimeChannel> _channels = {};
  bool _disposed = false;

  /// `false` on offline / mock builds where no Supabase project is configured.
  bool get isAvailable => _client != null;
  bool get isDisposed => _disposed;

  /// Number of channels currently held open — useful for leak assertions in
  /// tests and the B.7 disposal audit.
  int get openChannelCount => _channels.length;

  /// Opens a channel for [table] and wires the supplied postgres-change
  /// callbacks. Only the events with a non-null callback are registered.
  ///
  /// Throws a [StateError] on a duplicate [channelName] (a silent shadow is a
  /// classic realtime leak) or after [disposeAll].
  RealtimeSubscription subscribe({
    required String channelName,
    required String table,
    String schema = 'public',
    RealtimeFilter? filter,
    void Function(RealtimeRow row)? onInsert,
    void Function(RealtimeRow oldRow, RealtimeRow newRow)? onUpdate,
    void Function(RealtimeRow oldRow)? onDelete,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  }) {
    if (_disposed) {
      throw StateError('RealtimeService used after disposeAll()');
    }
    final client = _client;
    if (client == null) {
      // No realtime backend — hand back an inert handle so callers written
      // against the live path need no null branches.
      return RealtimeSubscription._noop(channelName);
    }
    if (_channels.containsKey(channelName)) {
      throw StateError('Realtime channel "$channelName" is already open');
    }

    final channel = client.channel(channelName);

    void bind(PostgresChangeEvent event) {
      channel.onPostgresChanges(
        event: event,
        schema: schema,
        table: table,
        filter: filter?.toSupabase(),
        callback: (payload) {
          switch (payload.eventType) {
            case PostgresChangeEvent.insert:
              onInsert?.call(payload.newRecord);
            case PostgresChangeEvent.update:
              onUpdate?.call(payload.oldRecord, payload.newRecord);
            case PostgresChangeEvent.delete:
              onDelete?.call(payload.oldRecord);
            case PostgresChangeEvent.all:
              break;
          }
        },
      );
    }

    if (onInsert != null) bind(PostgresChangeEvent.insert);
    if (onUpdate != null) bind(PostgresChangeEvent.update);
    if (onDelete != null) bind(PostgresChangeEvent.delete);

    channel.subscribe(onStatus);
    _channels[channelName] = channel;
    return RealtimeSubscription._(channelName, () => _remove(channelName));
  }

  Future<void> _remove(String channelName) async {
    final channel = _channels.remove(channelName);
    if (channel != null) {
      await _client?.removeChannel(channel);
    }
  }

  /// Tears down every open channel. Idempotent — safe to wire directly into a
  /// `GetIt` scope dispose callback (`dispose: (s) => s.disposeAll()`).
  Future<void> disposeAll() async {
    if (_disposed) return;
    _disposed = true;
    final channels = _channels.values.toList(growable: false);
    _channels.clear();
    for (final channel in channels) {
      await _client?.removeChannel(channel);
    }
  }
}
