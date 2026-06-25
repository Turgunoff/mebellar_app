import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../config/app_mode.dart';
import '../../shared/models/chat.dart';
import '../../shared/repositories/chat_repository.dart';
import '../../shared/repositories/notifications_repository.dart';
import '../auth/app_mode_cubit.dart';
import 'app_badge_service.dart';

/// Keeps the OS launcher badge in lock-step with the in-app unread total
/// (notifications + chats) while the app is alive — the authoritative source of
/// truth that supersedes the naive +1 tally the FCM background isolate keeps
/// while the process is dead.
///
/// Why mirror the live count instead of only incrementing in the background: a
/// blind tally drifts — a chat read on another device, a push for an item the
/// user already read, a broadcast that isn't a personal unread. Driving the
/// badge from the same realtime streams the in-app badges use (the home-bell
/// unread + the `Suhbatlar` unread) means it can never diverge from what the
/// user actually sees, and it self-heals the background tally on resume.
///
/// Root-scoped: it outlives the customer<->seller Phoenix rebirth and reads the
/// active mode from [AppModeCubit] (root-scoped too) so chat unread is counted
/// for the correct viewer role. `myChatsStream` is mode-agnostic — it returns
/// the same chat rows in both modes; only the `unreadFor(viewer)` fold differs.
class BadgeSyncController with WidgetsBindingObserver {
  BadgeSyncController({
    required AppBadgeService badge,
    required NotificationsRepository notifications,
    required ChatRepository chats,
    required AppModeCubit mode,
  }) : _badge = badge,
       _notifications = notifications,
       _chats = chats,
       _mode = mode;

  final AppBadgeService _badge;
  final NotificationsRepository _notifications;
  final ChatRepository _chats;
  final AppModeCubit _mode;

  StreamSubscription<int>? _notifSub;
  StreamSubscription<List<Chat>>? _chatsSub;
  StreamSubscription<AppMode>? _modeSub;

  List<Chat> _lastChats = const [];
  int _notifUnread = 0;
  bool _started = false;

  /// Subscribes to the unread streams + lifecycle. Idempotent — calling twice
  /// is a no-op. Seeds the notification count synchronously; the chat count
  /// arrives on the first stream emission (the chat repo pushes the cached list
  /// when the inbox loads or a push nudges it).
  void start() {
    if (_started) return;
    _started = true;

    _notifUnread = _notifications.unreadCount();
    _notifSub = _notifications.watchUnread().listen((count) {
      _notifUnread = count;
      _push();
    }, onError: (_) {});

    _chatsSub = _chats.myChatsStream().listen((chats) {
      _lastChats = chats;
      _push();
    }, onError: (_) {});

    // A mode flip changes which `unreadFor` field counts — recompute with the
    // retained chat rows (same rows, different viewer) without re-fetching.
    _modeSub = _mode.stream.listen((_) => _push());

    WidgetsBinding.instance.addObserver(this);
    _push();
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
    // tally, so reconcile it back to the true unread count the streams hold.
    if (state == AppLifecycleState.resumed) _push();
  }

  /// Tears down subscriptions + the lifecycle observer. Root-scoped in
  /// production (so this only runs in tests / a full DI reset), but provided so
  /// the controller leaves no dangling listeners.
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _notifSub?.cancel();
    await _chatsSub?.cancel();
    await _modeSub?.cancel();
    _started = false;
  }
}
