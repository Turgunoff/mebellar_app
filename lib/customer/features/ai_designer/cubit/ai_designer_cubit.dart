import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/services/facebook_analytics_service.dart';
import '../data/ai_chat_store.dart';
import '../data/ai_designer_repository.dart';
import '../models/ai_chat_message.dart';

class AiDesignerState extends Equatable {
  const AiDesignerState({
    this.messages = const [],
    this.products = const {},
    this.localImages = const {},
    this.pending = 0,
    this.error,
  });

  /// Conversation, oldest first.
  final List<AiChatMessage> messages;

  /// Recommended products attached to an AI message, keyed by message id. Kept
  /// in memory only — never persisted (see [AiChatMessage]).
  final Map<String, List<AiRecommendedProduct>> products;

  /// Locally-picked room photos, keyed by the user message id. In memory only:
  /// the photo is sent to the backend but never stored (privacy + Hive bloat),
  /// so it renders in the thread for this session only.
  final Map<String, Uint8List> localImages;

  /// Number of AI replies currently in flight. A COUNTER, not a bool, so the
  /// user can fire consecutive messages without the UI blocking — the typing
  /// indicator stays up until the LAST reply lands.
  final int pending;

  final String? error;

  /// True while any reply is awaited — drives the typing indicator. The
  /// composer NEVER disables on this (consecutive sends are allowed).
  bool get sending => pending > 0;

  AiDesignerState copyWith({
    List<AiChatMessage>? messages,
    Map<String, List<AiRecommendedProduct>>? products,
    Map<String, Uint8List>? localImages,
    int? pending,
    String? error,
    bool clearError = false,
  }) {
    return AiDesignerState(
      messages: messages ?? this.messages,
      products: products ?? this.products,
      localImages: localImages ?? this.localImages,
      pending: pending ?? this.pending,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [messages, products, localImages, pending, error];
}

/// Drives the AI interior-designer chat.
///
/// Registered as a ROOT-scope GetIt singleton (see `catalog_module`) and handed
/// to the screen via `BlocProvider.value` — so popping the chat screen does NOT
/// close the cubit. An in-flight request therefore keeps running in the
/// background, appends its reply, and persists it to Hive (background-execution
/// resilience).
///
/// History is **per-user and server-authoritative**: the cubit watches the auth
/// stream and, on a sign-in, restores that user's conversation from the backend
/// (`GET /ai/chat/history`); on a sign-out it wipes the in-memory thread + the
/// local cache so the next user (or a guest) starts from a clean greeting.
class AiDesignerCubit extends Cubit<AiDesignerState> {
  AiDesignerCubit({
    required AiDesignerRepository repository,
    required AuthCubit authCubit,
    AiChatStore? store,
    AnalyticsService? analytics,
    FacebookAnalyticsService? facebookAnalytics,
  }) : _repo = repository,
       _authCubit = authCubit,
       _store = store ?? AiChatStore(),
       _analytics = analytics,
       _facebookAnalytics = facebookAnalytics,
       super(const AiDesignerState()) {
    _handleAuth(_authCubit.state);
    _authSub = _authCubit.stream.listen(_handleAuth);
  }

  final AiDesignerRepository _repo;
  final AuthCubit _authCubit;
  final AiChatStore _store;
  final AnalyticsService? _analytics;
  final FacebookAnalyticsService? _facebookAnalytics;

  StreamSubscription<AppAuthState>? _authSub;

  /// The user id we last restored for — so a token refresh (authed→authed, same
  /// user) doesn't re-fetch, while a real sign-in/out (or account switch) does.
  /// Null while signed out.
  String? _restoredUserId;

  int _localSeq = 0;

  void _handleAuth(AppAuthState authState) {
    if (authState is AppAuthAuthenticated) {
      if (authState.userId == _restoredUserId) return; // token refresh
      final switchingUser =
          _restoredUserId != null && _restoredUserId != authState.userId;
      _restoredUserId = authState.userId;
      // A direct account switch with no sign-out between (shouldn't happen —
      // logout clears first — but guard anyway): wipe the previous user's
      // thread before the restore so it can't leak into the merge below.
      if (switchingUser) {
        if (!isClosed) emit(const AiDesignerState());
        unawaited(_store.clear());
      }
      unawaited(_restore(authState.userId));
    } else {
      // Signed out: clear the in-memory thread + the local cache. (performLogout
      // also wipes the Hive box, so this holds even if the cubit never existed.)
      _restoredUserId = null;
      if (!isClosed) emit(const AiDesignerState());
      unawaited(_store.clear());
    }
  }

  /// Restores [userId]'s thread from the backend (the source of truth). On a
  /// network failure, falls back to the local cache — which only ever holds the
  /// current user's data, since logout clears it. Any message the user fired
  /// DURING the fetch (signing in from the composer) is kept: logout already
  /// emptied the state, so anything present now is genuinely new.
  Future<void> _restore(String userId) async {
    final List<AiChatMessage> restored;
    try {
      restored = await _repo.fetchHistory();
    } catch (_) {
      // Network/HTTP failure (or a malformed body) — DON'T clobber the cache.
      // Show the local copy, which only ever holds THIS user's data (logout
      // clears it); it re-syncs on the next successful login. Fold in any
      // just-sent message not yet flushed to the box, deduped by id.
      if (isClosed || userId != _restoredUserId) return;
      final cached = _store.load();
      final ids = cached.map((m) => m.id).toSet();
      final extra = state.messages.where((m) => !ids.contains(m.id));
      emit(state.copyWith(messages: [...cached, ...extra]));
      return;
    }
    if (isClosed || userId != _restoredUserId) return;
    // Anything in the state now was fired DURING the fetch (signing in from the
    // composer) — logout already emptied the thread, so it's genuinely new.
    // Persist the SAME list we emit so that in-flight turn isn't lost from the
    // cache by the clear inside replaceAll.
    final merged = [...restored, ...state.messages];
    await _store.replaceAll(merged);
    if (isClosed || userId != _restoredUserId) return;
    emit(state.copyWith(messages: merged));
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }

  Future<void> sendMessage({
    required String text,
    Uint8List? imageBytes,
    String? imageMime,
  }) async {
    final trimmed = text.trim();
    // NO `sending` guard — consecutive sends are allowed; each request is
    // independent and counted by `pending`.
    if (trimmed.isEmpty && imageBytes == null) return;

    // Snapshot the PRIOR turns before adding the current one — the request
    // sends this turn as `message`, so it must NOT also appear in `history`
    // (else the backend sees the question twice).
    final prior = state.messages;

    final userMessage = AiChatMessage(
      id: _nextId(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );
    final localImages = imageBytes == null
        ? state.localImages
        : {...state.localImages, userMessage.id: imageBytes};
    emit(
      state.copyWith(
        messages: [...state.messages, userMessage],
        localImages: localImages,
        pending: state.pending + 1,
        clearError: true,
      ),
    );
    unawaited(_store.append(userMessage));
    unawaited(_analytics?.aiDesignerMessageSent(hasImage: imageBytes != null));
    unawaited(
      _facebookAnalytics?.logCustomEvent('ai_designer_used', {
        'has_image': imageBytes != null,
      }),
    );

    try {
      final reply = await _repo.chat(
        message: trimmed,
        imageBytes: imageBytes,
        imageMime: imageMime,
        history: prior,
      );

      final aiMessage = AiChatMessage(
        id: _nextId(),
        text: reply.reply,
        isUser: false,
        timestamp: DateTime.now(),
        logId: reply.logId,
      );
      // Persist to the local cache before emitting so the reply isn't lost if
      // the cubit is closed mid-flight (app teardown). The backend also logged
      // this turn (the /ai/chat call), so the next login's restore re-fetches
      // it regardless; the cache is the instant-paint + offline mirror.
      await _store.append(aiMessage);
      if (isClosed) return;
      final products = {...state.products};
      if (reply.products.isNotEmpty) products[aiMessage.id] = reply.products;
      emit(
        state.copyWith(
          messages: [...state.messages, aiMessage],
          products: products,
          pending: state.pending - 1,
        ),
      );
    } catch (_) {
      // The repository degrades gracefully (it never throws on an AI failure),
      // so this only guards unexpected errors — never leak the typing counter.
      if (!isClosed) emit(state.copyWith(pending: state.pending - 1));
    }
  }

  /// Records the user's 👍/👎 verdict on the AI message whose [logId] matches.
  /// Optimistic: the local message + Hive update happen first (instant UI), then
  /// the backend PATCH fires best-effort. A failed PATCH keeps the optimistic
  /// state — the rating is a soft signal, not worth a rollback.
  Future<void> rateAiMessage(String logId, String rating) async {
    final index = state.messages.indexWhere((m) => m.logId == logId);
    if (index < 0) return;

    final updated = state.messages[index].copyWith(userRating: rating);
    final messages = [...state.messages];
    messages[index] = updated;
    if (!isClosed) emit(state.copyWith(messages: messages));
    // append() does put(message.id, message), so it overwrites the stored row.
    unawaited(_store.append(updated));

    await _repo.rateMessage(logId, rating);
  }

  Future<void> clearHistory() async {
    await _store.clear();
    emit(const AiDesignerState());
  }

  String _nextId() =>
      'ai-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}';
}
