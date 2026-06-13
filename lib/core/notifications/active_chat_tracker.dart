/// Tracks which chat thread (if any) the user is currently looking at, so a
/// foreground push for that same conversation can be suppressed — the open
/// thread already shows the incoming message live over the WebSocket, and a
/// drop-down notification on top of it is just noise (Telegram does the same).
///
/// Set by `ChatThreadScreen` on mount / unmount; read by `PushService` in the
/// foreground-message handler. A plain process-global singleton (not in GetIt)
/// because both the UI layer and the core push layer touch it, and it carries
/// no lifecycle of its own.
class ActiveChatTracker {
  ActiveChatTracker._();

  static final ActiveChatTracker instance = ActiveChatTracker._();

  String? _chatId;

  /// The chat thread currently on screen, or null when none is open.
  String? get activeChatId => _chatId;

  /// Mark [chatId] as the thread the user is viewing.
  void enter(String chatId) => _chatId = chatId;

  /// Clear the active thread — but only if [chatId] is still the one we hold,
  /// so a fast A→B→dispose(A) ordering can't wipe B's marker.
  void leave(String chatId) {
    if (_chatId == chatId) _chatId = null;
  }

  bool isViewing(String? chatId) =>
      chatId != null && chatId.isNotEmpty && _chatId == chatId;
}
