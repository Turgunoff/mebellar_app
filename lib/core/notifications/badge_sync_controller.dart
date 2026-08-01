import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../config/app_mode.dart';
import '../../shared/models/chat.dart';
import '../../shared/repositories/chat_repository.dart';
import '../../shared/repositories/notifications_data_source.dart';
import '../auth/app_mode_cubit.dart';
import '../network/token_store.dart';
import '../realtime/woody_realtime_service.dart';
import 'app_badge_service.dart';

/// Keeps the OS launcher badge in lock-step with the in-app unread total
/// (notifications + chats) while the app is alive — the authoritative source of
/// truth that supersedes the naive +1 tally the FCM background isolate keeps
/// while the process is dead.
///
/// Notification unread is pulled from [NotificationDataSource.unreadCount] (the
/// backend total) rather than the legacy [NotificationsRepository] in-memory
/// cache, which is never seeded at boot and would leave the launcher badge at
/// zero until something explicitly called `list()`.
///
/// Root-scoped: it outlives the customer<->seller Phoenix rebirth and reads the
/// active mode from [AppModeCubit] (root-scoped too) so chat unread is counted
/// for the correct viewer role. `myChatsStream` is mode-agnostic — it returns
/// the same chat rows in both modes; only the `unreadFor(viewer)` fold differs.
///
/// Guest sessions never hit `/notifications` or `/chats`: [TokenStore] gates
/// the refreshes, and a sign-in flip nudges both sources so the badge catches
/// up without waiting for the next resume.
class BadgeSyncController with WidgetsBindingObserver {
  BadgeSyncController({
    required AppBadgeService badge,
    required NotificationDataSource notifications,
    required ChatRepository chats,
    required AppModeCubit mode,
    WoodyRealtimeService? realtime,
    TokenStore? tokens,
  }) : _badge = badge,
       _notifications = notifications,
       _chats = chats,
       _mode = mode,
       _realtime = realtime,
       _tokens = tokens;

  final AppBadgeService _badge;
  final NotificationDataSource _notifications;
  final ChatRepository _chats;
  final AppModeCubit _mode;
  final WoodyRealtimeService? _realtime;
  final TokenStore? _tokens;

  StreamSubscription<List<Chat>>? _chatsSub;
  StreamSubscription<AppMode>? _modeSub;
  StreamSubscription<RealtimeEvent>? _realtimeSub;
  StreamSubscription<TokenPair?>? _authSub;

  List<Chat> _lastChats = const [];
  int _notifUnread = 0;
  bool _started = false;
  bool? _wasAuthed;

  /// Subscribes to chat unread + lifecycle. Idempotent — calling twice is a
  /// no-op. Seeds notification unread from the backend; chat count arrives on
  /// the first stream emission.
  void start() {
    if (_started) return;
    _started = true;

    _authSub = _tokens?.changes.listen(_onAuthChanged);

    unawaited(_seedAndRefresh());

    _realtimeSub = _realtime?.eventsOfType('notification').listen((_) {
      unawaited(refreshNotificationUnread());
    });

    _chatsSub = _chats.myChatsStream().listen((chats) {
      _lastChats = chats;
      _push();
    }, onError: (_) {});

    // A mode flip changes which `unreadFor` field counts — recompute with the
    // retained chat rows (same rows, different viewer) without re-fetching.
    _modeSub = _mode.stream.listen((_) => _push());

    WidgetsBinding.instance.addObserver(this);
  }

  /// Resolves the cached/hydrated session before the first unread pull so a
  /// cold-start guest never races ahead of [TokenStore.read] into a 401.
  Future<void> _seedAndRefresh() async {
    final tokens = _tokens;
    if (tokens != null) {
      _wasAuthed = (tokens.current ?? await tokens.read()) != null;
    }
    await refreshNotificationUnread();
  }

  void _onAuthChanged(TokenPair? pair) {
    final authed = pair != null;
    if (authed == _wasAuthed) return;
    final wasGuest = _wasAuthed != true;
    _wasAuthed = authed;
    if (!authed) {
      unawaited(clearOnLogout());
      return;
    }
    // Guest → signed-in: re-pull both tallies. The chat stream's first guest
    // pull was empty and won't re-fire on its own.
    if (wasGuest) {
      unawaited(refreshNotificationUnread());
      _chats.nudgeFromPush();
    }
  }

  Future<bool> get _signedIn async {
    final tokens = _tokens;
    if (tokens == null) return true;
    return (tokens.current ?? await tokens.read()) != null;
  }

  /// Re-fetches the server-side unread notification total and updates the OS
  /// badge. Called at boot, on resume, after inbox mutations, and on realtime
  /// `notification` events. When the session is gone (logout / guest), falls
  /// back to zero without a doomed 401 round-trip.
  Future<void> refreshNotificationUnread() async {
    if (!await _signedIn) {
      _notifUnread = 0;
      _push();
      return;
    }
    try {
      _notifUnread = await _notifications.unreadCount();
    } catch (_) {
      _notifUnread = 0;
    }
    _push();
  }

  /// Wipes in-memory unread state and clears the launcher badge. Called from
  /// logout teardown so a later chat-stream emission or a failed refresh can't
  /// repaint the previous account's count.
  Future<void> clearOnLogout() async {
    _notifUnread = 0;
    _lastChats = const [];
    await _badge.clear();
  }

  ChatSenderRole get _viewer => switch (_mode.state) {
    AppMode.seller => ChatSenderRole.seller,
    AppMode.customer => ChatSenderRole.customer,
  };

  int get _chatUnread =>
      _lastChats.fold<int>(0, (sum, c) => sum + c.unreadFor(_viewer));

  void _push() => unawaited(_badge.setCount(_notifUnread + _chatUnread));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On resume, re-assert the authoritative total: while the app sat in the
    // background the FCM isolate may have bumped the OS badge with its naive +1
    // tally, so reconcile from the server + live chat rows.
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshNotificationUnread());
    }
  }

  /// Tears down subscriptions + the lifecycle observer. Root-scoped in
  /// production (so this only runs in tests / a full DI reset), but provided so
  /// the controller leaves no dangling listeners.
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _realtimeSub?.cancel();
    await _chatsSub?.cancel();
    await _modeSub?.cancel();
    await _authSub?.cancel();
    _started = false;
  }
}
