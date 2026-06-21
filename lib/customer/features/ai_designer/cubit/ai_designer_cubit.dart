import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
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
/// background, appends its reply, and persists it to Hive; reopening the chat
/// shows the reply (background-execution resilience).
class AiDesignerCubit extends Cubit<AiDesignerState> {
  AiDesignerCubit({
    required AiDesignerRepository repository,
    AiChatStore? store,
    AnalyticsService? analytics,
    FacebookAnalyticsService? facebookAnalytics,
  }) : _repo = repository,
       _store = store ?? AiChatStore(),
       _analytics = analytics,
       _facebookAnalytics = facebookAnalytics,
       super(const AiDesignerState()) {
    _loadHistory();
  }

  final AiDesignerRepository _repo;
  final AiChatStore _store;
  final AnalyticsService? _analytics;
  final FacebookAnalyticsService? _facebookAnalytics;

  int _localSeq = 0;

  void _loadHistory() {
    final history = _store.load();
    if (history.isNotEmpty) emit(state.copyWith(messages: history));
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
      );
      // Persist FIRST so the reply survives even if the cubit was closed while
      // the request was in flight (e.g. app teardown) — on the next open
      // `_loadHistory` reads it back from Hive.
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

  Future<void> clearHistory() async {
    await _store.clear();
    emit(const AiDesignerState());
  }

  String _nextId() =>
      'ai-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}';
}
