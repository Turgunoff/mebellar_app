import 'package:equatable/equatable.dart';

import 'order_status.dart';

/// Whose side of the conversation a message (or unread counter) belongs to.
/// Stored as a plain string in Postgres (`sender_role`); converted here
/// at the model boundary so the rest of the app stays type-safe.
enum ChatSenderRole {
  customer('customer'),
  seller('seller');

  const ChatSenderRole(this.value);
  final String value;

  static ChatSenderRole fromValue(String v) {
    for (final r in values) {
      if (r.value == v) return r;
    }
    throw ArgumentError('Unknown sender_role: $v');
  }
}

/// A per-order conversation between exactly two parties: the order's
/// customer and the shop's seller. Lazy-created the first time either
/// side opens it.
class Chat extends Equatable {
  const Chat({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.shopId,
    this.shopName,
    this.shopLogoUrl,
    this.customerName,
    this.customerAvatarUrl,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.customerUnreadCount = 0,
    this.sellerUnreadCount = 0,
    this.orderStatus,
    this.orderCancellationReason,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String customerId;
  final String shopId;

  /// Joined from `orders.status` — drives the status banner shown above
  /// the message list. Null only when the join didn't run (e.g. mock).
  final OrderStatus? orderStatus;

  /// Joined from `orders.cancellation_reason` — surfaced inside the
  /// banner when the order is cancelled so the user immediately knows
  /// what happened without leaving the chat.
  final String? orderCancellationReason;

  /// Joined from `shops` when the chat is fetched. The customer-side UI
  /// shows the shop as the "other party"; nullable so we degrade
  /// gracefully if the join fails or the shop was renamed mid-flight.
  final String? shopName;
  final String? shopLogoUrl;

  /// Joined from `profiles` for the seller-side UI to label the thread.
  final String? customerName;
  final String? customerAvatarUrl;

  final DateTime? lastMessageAt;
  final String? lastMessagePreview;

  final int customerUnreadCount;
  final int sellerUnreadCount;

  final DateTime createdAt;

  /// Pick the right unread counter for the viewer. Centralised so screens
  /// don't have to remember which column belongs to which side.
  int unreadFor(ChatSenderRole viewer) => switch (viewer) {
        ChatSenderRole.customer => customerUnreadCount,
        ChatSenderRole.seller => sellerUnreadCount,
      };

  /// The label to render on the chat list tile for [viewer]. Customer
  /// sees the shop name; seller sees the customer name.
  String displayNameFor(ChatSenderRole viewer) {
    final fallback = viewer == ChatSenderRole.customer ? 'Sotuvchi' : 'Mijoz';
    return switch (viewer) {
      ChatSenderRole.customer => shopName ?? fallback,
      ChatSenderRole.seller => customerName ?? fallback,
    };
  }

  String? avatarFor(ChatSenderRole viewer) => switch (viewer) {
        ChatSenderRole.customer => shopLogoUrl,
        ChatSenderRole.seller => customerAvatarUrl,
      };

  factory Chat.fromJson(Map<String, dynamic> json) {
    // Shop, profile, and order are PostgREST embedded joins, all
    // nullable in case the row was deleted between query and read.
    final shop = json['shop'] as Map<String, dynamic>?;
    final customer = json['customer'] as Map<String, dynamic>?;
    final order = json['order'] as Map<String, dynamic>?;
    return Chat(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      customerId: json['customer_id'] as String,
      shopId: json['shop_id'] as String,
      shopName: shop?['name'] as String?,
      shopLogoUrl: shop?['logo_url'] as String?,
      customerName: customer?['display_name'] as String? ??
          customer?['full_name'] as String?,
      customerAvatarUrl: customer?['avatar_url'] as String?,
      lastMessageAt: _parseDate(json['last_message_at']),
      lastMessagePreview: json['last_message_preview'] as String?,
      customerUnreadCount: (json['customer_unread_count'] as num?)?.toInt() ?? 0,
      sellerUnreadCount: (json['seller_unread_count'] as num?)?.toInt() ?? 0,
      orderStatus: order?['status'] is String
          ? OrderStatus.fromCode(order!['status'] as String)
          : null,
      orderCancellationReason: order?['cancellation_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Chat copyWith({
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    int? customerUnreadCount,
    int? sellerUnreadCount,
    OrderStatus? orderStatus,
    String? orderCancellationReason,
  }) {
    return Chat(
      id: id,
      orderId: orderId,
      customerId: customerId,
      shopId: shopId,
      shopName: shopName,
      shopLogoUrl: shopLogoUrl,
      customerName: customerName,
      customerAvatarUrl: customerAvatarUrl,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      customerUnreadCount: customerUnreadCount ?? this.customerUnreadCount,
      sellerUnreadCount: sellerUnreadCount ?? this.sellerUnreadCount,
      orderStatus: orderStatus ?? this.orderStatus,
      orderCancellationReason:
          orderCancellationReason ?? this.orderCancellationReason,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        orderId,
        customerId,
        shopId,
        lastMessageAt,
        lastMessagePreview,
        customerUnreadCount,
        sellerUnreadCount,
      ];
}

DateTime? _parseDate(Object? raw) {
  if (raw is String) return DateTime.parse(raw);
  return null;
}
