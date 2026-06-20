import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/notifications/active_support_tracker.dart';
import '../models/support_message.dart';
import '../repository/support_chat_repository.dart';

/// Unread support-message count for the badge on the profile "Yordam va
/// Qo'llab-quvvatlash" row. Lives at the customer shell root (alongside
/// `TotalUnreadChatsCubit`) so the badge survives navigation and updates live.
///
/// Three live inputs, mirroring the chat badge but for the single support
/// thread:
///   * seed — [SupportChatRepository.fetchUnreadCount] (read-only `GET
///     /support/unread`, no mark-read side effect) at construction;
///   * increment — each `support_message` WS frame (admin reply) bumps the
///     count by one, UNLESS the user is already viewing the thread (then the
///     thread shows it live + marks it read, so the badge must stay clear);
///   * reset — the repo's local "I read the thread" signal zeroes it.
///
/// On app resume it re-seeds from the server: WS has no backfill, so replies
/// that arrived as a push while backgrounded are only reflected by a re-fetch.
class SupportUnreadCubit extends Cubit<int> with WidgetsBindingObserver {
  SupportUnreadCubit(this._repo) : super(0) {
    WidgetsBinding.instance.addObserver(this);
    _seed();
    _msgSub = _repo.messagesStream().listen(
      (_) {
        if (!ActiveSupportTracker.instance.isViewing) emit(state + 1);
      },
      // Keep the last good count on a transient stream error — a frozen badge
      // beats one that throws or flickers to zero.
      onError: (_) {},
    );
    _readSub = _repo.localReadStream().listen(
      (_) => emit(0),
      onError: (_) {},
    );
  }

  final SupportChatRepository _repo;
  StreamSubscription<SupportMessage>? _msgSub;
  StreamSubscription<void>? _readSub;

  Future<void> _seed() async {
    try {
      emit(await _repo.fetchUnreadCount());
    } catch (_) {
      // Guests (401) or a transient failure — leave the badge at its last value.
    }
  }

  /// Re-pull the authoritative count (e.g. after a cold start or resume).
  Future<void> refresh() => _seed();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_seed());
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    await _msgSub?.cancel();
    await _readSub?.cancel();
    return super.close();
  }
}
