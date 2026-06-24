import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/services/facebook_analytics_service.dart';
import '../../../../core/storage/r2_upload_client.dart';
import '../data/ai_chat_store.dart';
import '../data/ai_designer_repository.dart';
import '../data/ai_image_quota.dart';
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
    R2UploadClient? uploads,
    AiImageQuota? imageQuota,
  }) : _repo = repository,
       _authCubit = authCubit,
       _store = store ?? AiChatStore(),
       _analytics = analytics,
       _facebookAnalytics = facebookAnalytics,
       _uploads = uploads,
       _imageQuota = imageQuota,
       super(const AiDesignerState()) {
    _handleAuth(_authCubit.state);
    _authSub = _authCubit.stream.listen(_handleAuth);
  }

  final AiDesignerRepository _repo;
  final AuthCubit _authCubit;
  final AiChatStore _store;
  final AnalyticsService? _analytics;
  final FacebookAnalyticsService? _facebookAnalytics;

  /// Uploads a room photo to R2 before the chat call. Null in tests / when
  /// storage isn't wired → the turn proceeds text-only (still rendered this
  /// session from [AiDesignerState.localImages], just not persisted).
  final R2UploadClient? _uploads;

  /// Per-day client-side image cap. Lazily defaulted so callers (and the DI
  /// module) need not construct it; tests inject a fake box.
  final AiImageQuota? _imageQuota;
  AiImageQuota get _quota => _imageQuota ?? (_quotaCache ??= AiImageQuota());
  AiImageQuota? _quotaCache;

  /// State error code the UI maps to a localized snackbar when the daily image
  /// limit is hit (the turn is still sent, text-only).
  static const imageLimitError = 'ai_designer.image_limit_reached';

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

    var userMessage = AiChatMessage(
      id: _nextId(),
      text: trimmed,
      isUser: true,
      hasImage: imageBytes != null,
      timestamp: DateTime.now(),
    );
    // Render the picked photo instantly from memory while it uploads; the
    // durable imageUrl is patched on once the upload resolves (below).
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

    // Upload the room photo to R2 so it persists past this session. The daily
    // quota, an upload failure, or unwired storage all degrade to a text-only
    // turn — the chat must never block on the image. (The bytes still render
    // this session via localImages; only persistence is lost on degrade.)
    String? imageUrl;
    String? imagePath;
    if (imageBytes != null && _uploads != null) {
      if (!_quota.canUpload) {
        if (!isClosed) emit(state.copyWith(error: imageLimitError));
      } else {
        final uploaded = await _uploadRoomPhoto(imageBytes, imageMime);
        imageUrl = uploaded?.publicUrl;
        imagePath = uploaded?.path;
        if (imageUrl != null) {
          unawaited(_quota.increment());
          userMessage = userMessage.copyWith(imageUrl: imageUrl);
          if (!isClosed) {
            final msgs = [...state.messages];
            final i = msgs.indexWhere((m) => m.id == userMessage.id);
            if (i >= 0) {
              msgs[i] = userMessage;
              emit(state.copyWith(messages: msgs));
            }
          }
          // Overwrite the cached row so the durable URL survives a relaunch.
          await _store.append(userMessage);
        }
      }
    }

    try {
      final reply = await _repo.chat(
        message: trimmed,
        imageUrl: imageUrl,
        imagePath: imagePath,
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

  /// Uploads the room photo to the `ai-chat-images` R2 bucket and returns the
  /// result (public URL + key). Null on any failure / when storage or the user
  /// id isn't available — the caller then sends the turn text-only.
  Future<R2UploadResult?> _uploadRoomPhoto(
    Uint8List bytes,
    String? mime,
  ) async {
    final uploads = _uploads;
    final userId = _currentUserId();
    if (uploads == null || userId == null) return null;
    try {
      final ext = mime == 'image/webp' ? 'webp' : 'jpg';
      return await uploads.upload(
        bucket: R2Bucket.aiChatImages,
        // The folder MUST be the caller's own id (the backend binds ownership to
        // it and server-issues the object name, overriding this basename).
        path: '$userId/room.$ext',
        bytes: bytes,
        contentType: mime ?? 'image/jpeg',
      );
    } catch (_) {
      return null; // never block the chat on an upload hiccup
    }
  }

  String? _currentUserId() {
    final s = _authCubit.state;
    return s is AppAuthAuthenticated ? s.userId : null;
  }

  String _nextId() =>
      'ai-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}';
}
