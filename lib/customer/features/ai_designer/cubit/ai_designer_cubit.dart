import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../data/ai_chat_store.dart';
import '../data/ai_designer_repository.dart';
import '../models/ai_chat_message.dart';

class AiDesignerState extends Equatable {
  const AiDesignerState({
    this.messages = const [],
    this.products = const {},
    this.localImages = const {},
    this.sending = false,
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

  /// True while a reply is in flight; the composer disables itself and the
  /// loading indicator shows.
  final bool sending;

  final String? error;

  AiDesignerState copyWith({
    List<AiChatMessage>? messages,
    Map<String, List<AiRecommendedProduct>>? products,
    Map<String, Uint8List>? localImages,
    bool? sending,
    String? error,
    bool clearError = false,
  }) {
    return AiDesignerState(
      messages: messages ?? this.messages,
      products: products ?? this.products,
      localImages: localImages ?? this.localImages,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [messages, products, localImages, sending, error];
}

/// Drives the AI interior-designer chat. Loads persisted history instantly on
/// construction (no loading state), then appends the user turn + the AI reply
/// per send, persisting both.
class AiDesignerCubit extends Cubit<AiDesignerState> {
  AiDesignerCubit({
    required AiDesignerRepository repository,
    AiChatStore? store,
    AnalyticsService? analytics,
  }) : _repo = repository,
       _store = store ?? AiChatStore(),
       _analytics = analytics,
       super(const AiDesignerState()) {
    _loadHistory();
  }

  final AiDesignerRepository _repo;
  final AiChatStore _store;
  final AnalyticsService? _analytics;

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
    if ((trimmed.isEmpty && imageBytes == null) || state.sending) return;

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
        messages: [...prior, userMessage],
        localImages: localImages,
        sending: true,
        clearError: true,
      ),
    );
    unawaited(_store.append(userMessage));
    unawaited(_analytics?.aiDesignerMessageSent(hasImage: imageBytes != null));

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
    final products = {...state.products};
    if (reply.products.isNotEmpty) products[aiMessage.id] = reply.products;
    emit(
      state.copyWith(
        messages: [...state.messages, aiMessage],
        products: products,
        sending: false,
      ),
    );
    unawaited(_store.append(aiMessage));
  }

  Future<void> clearHistory() async {
    await _store.clear();
    emit(const AiDesignerState());
  }

  String _nextId() =>
      'ai-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}';
}
