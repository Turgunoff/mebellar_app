import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/network/woody_api_client.dart';
import '../models/ai_chat_message.dart';

/// A product the AI surfaced as a recommendation for the user's room. Mirrors
/// the `products[]` shape in the `POST /ai/chat` response (snake_case →
/// camelCase).
class AiRecommendedProduct {
  const AiRecommendedProduct({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.shopName,
    this.arModelUrl,
  });

  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final String? shopName;

  /// Public URL of the QC-approved 3D model. The backend only sends it for an
  /// approved model, so a non-null value drives the "3D / AR" card badge.
  final String? arModelUrl;

  /// True when this recommendation has a published AR model.
  bool get hasAr => arModelUrl != null && arModelUrl!.isNotEmpty;

  factory AiRecommendedProduct.fromJson(Map<String, dynamic> json) {
    return AiRecommendedProduct(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      imageUrl: json['image_url'] as String?,
      shopName: json['shop_name'] as String?,
      arModelUrl: json['ar_model_url'] as String?,
    );
  }
}

/// The parsed `POST /ai/chat` reply. [available] is false when the backend has
/// the AI disabled / unconfigured or the model failed; the UI then shows
/// [reply] (a friendly fallback) with no products.
class AiDesignerReply {
  const AiDesignerReply({
    required this.available,
    required this.reply,
    required this.products,
    this.logId,
  });

  final bool available;
  final String reply;
  final List<AiRecommendedProduct> products;

  /// Id of the persisted chat-log row, echoed back so the UI can rate this
  /// reply later. Null when the backend's log write failed (the chat still
  /// succeeds) — the rating affordance is then simply absent.
  final String? logId;

  factory AiDesignerReply.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final products = rawProducts is List
        ? rawProducts
              .whereType<Map<String, dynamic>>()
              .map(AiRecommendedProduct.fromJson)
              .toList(growable: false)
        : const <AiRecommendedProduct>[];
    return AiDesignerReply(
      available: json['available'] as bool? ?? false,
      reply: json['reply'] as String? ?? '',
      products: products,
      logId: json['log_id'] as String?,
    );
  }
}

/// AI interior-designer chat over `POST /ai/chat`. Authenticated-only (the
/// client attaches the bearer token); the guest gate lives in the UI so a
/// signed-out tap opens the login flow instead of POSTing.
abstract class AiDesignerRepository {
  Future<AiDesignerReply> chat({
    required String message,
    Uint8List? imageBytes,
    String? imageMime,
    List<AiChatMessage> history = const [],
  });

  /// Records the user's 👍/👎 verdict on an AI reply.
  /// [rating] is "liked" or "disliked". Returns true on success; never throws
  /// — the rating is a soft signal, so a failure is swallowed and the caller
  /// keeps the optimistic local state.
  Future<bool> rateMessage(String logId, String rating);

  /// The authenticated user's persisted chat history (oldest-first),
  /// reconstructed into renderable [AiChatMessage]s so the thread restores
  /// after login. Each backend turn expands into a user message + an AI reply
  /// (carrying its log id so the 👍/👎 affordance keeps working). THROWS on a
  /// network/HTTP failure so the cubit can fall back to its local cache.
  Future<List<AiChatMessage>> fetchHistory();
}

/// REST-backed implementation. Sends the room photo inline as raw base64 (no
/// `data:` prefix, per the contract) and degrades gracefully — a network
/// failure returns an unavailable reply instead of throwing, so the chat UI
/// never crashes on a dropped connection.
class WoodyAiDesignerRepository implements AiDesignerRepository {
  WoodyAiDesignerRepository(this._api);

  final WoodyApiClient _api;

  @override
  Future<AiDesignerReply> chat({
    required String message,
    Uint8List? imageBytes,
    String? imageMime,
    List<AiChatMessage> history = const [],
  }) async {
    try {
      // The backend `AiChatBody` requires `message` (min_length=1), caps
      // `history` at 20 turns, and rejects any history turn with empty text
      // (`AiChatHistoryTurn.text` min_length=1). Locally we store image-only
      // user turns and degraded/empty AI replies with empty text, and the
      // history grows unbounded — so sanitize at this boundary or FastAPI 422s
      // (which the catch below silently turns into the fallback error reply).
      final outMessage = message.trim().isEmpty
          ? tr('ai_designer.image_only_prompt')
          : message;
      final cleanHistory = [
        for (final m in history)
          if (m.text.trim().isNotEmpty)
            {'role': m.isUser ? 'user' : 'assistant', 'text': m.text},
      ];
      // Newest 20 turns only (backend max_length=20; recent turns matter most).
      final recentHistory = cleanHistory.length > 20
          ? cleanHistory.sublist(cleanHistory.length - 20)
          : cleanHistory;
      final body = <String, dynamic>{
        'message': outMessage,
        if (imageBytes != null) 'image_base64': base64Encode(imageBytes),
        if (imageBytes != null && imageMime != null) 'image_mime': imageMime,
        if (recentHistory.isNotEmpty) 'history': recentHistory,
      };
      final response = await _api.post<Map<String, dynamic>>(
        '/ai/chat',
        body: body,
      );
      return AiDesignerReply.fromJson(response);
    } catch (_) {
      return AiDesignerReply(
        available: false,
        reply: tr('ai_designer.error'),
        products: const [],
      );
    }
  }

  @override
  Future<List<AiChatMessage>> fetchHistory() async {
    // No try/catch: a network/HTTP failure propagates so the cubit falls back
    // to its local cache instead of wrongly showing an empty thread.
    final resp = await _api.get<Map<String, dynamic>>('/ai/chat/history');
    final rawTurns = resp['turns'];
    if (rawTurns is! List) {
      // A 200 with no parseable `turns` is a malformed / partial response, not
      // a genuine empty history — throw so the cubit keeps the local cache
      // rather than wiping it. (A real empty history is `turns: []`, a List.)
      throw const FormatException('ai/chat/history: missing "turns" list');
    }
    final out = <AiChatMessage>[];
    for (final raw in rawTurns.whereType<Map<String, dynamic>>()) {
      final logId = raw['log_id'] as String?;
      if (logId == null) continue;
      final ts =
          DateTime.tryParse(raw['created_at'] as String? ?? '') ??
          DateTime.now();
      out.add(
        AiChatMessage(
          id: '$logId-u',
          text: raw['user_message'] as String? ?? '',
          isUser: true,
          timestamp: ts,
        ),
      );
      final aiText = raw['ai_response'] as String?;
      if (aiText != null && aiText.isNotEmpty) {
        out.add(
          AiChatMessage(
            id: '$logId-a',
            text: aiText,
            isUser: false,
            // +1ms so the reply sorts AFTER its paired question when the local
            // store re-sorts equal-`created_at` turns by timestamp.
            timestamp: ts.add(const Duration(milliseconds: 1)),
            logId: logId,
            userRating: raw['user_rating'] as String?,
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<bool> rateMessage(String logId, String rating) async {
    try {
      await _api.patch<dynamic>(
        '/ai/chat/logs/$logId/rate',
        body: {'rating': rating},
      );
      return true;
    } catch (_) {
      // Rating is a soft signal — never surface a failure to the user.
      return false;
    }
  }
}
