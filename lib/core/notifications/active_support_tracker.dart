/// Tracks whether the customer is currently looking at the support thread, so
/// a foreground push for support can be suppressed — the open thread already
/// shows the incoming message live over the WebSocket, and a drop-down on top
/// of it is just noise (mirrors [ActiveChatTracker], but support is a single
/// per-user thread so a boolean is enough — no chat id to key on).
///
/// Set by `SupportChatScreen` on mount / unmount; read by `PushService` in the
/// foreground-message handler. A plain process-global singleton (not in GetIt)
/// because both the UI layer and the core push layer touch it.
class ActiveSupportTracker {
  ActiveSupportTracker._();

  static final ActiveSupportTracker instance = ActiveSupportTracker._();

  bool _active = false;

  /// True while the support thread is on screen.
  bool get isViewing => _active;

  void enter() => _active = true;

  void leave() => _active = false;
}
