import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../config/app_mode.dart';

/// Closed set of notification kinds the inbox knows how to render. New
/// values added on the backend default to [NotificationKind.general] so the
/// UI never breaks when an unknown type arrives — see [fromString].
///
/// Wire format: every value owns a [code] string that mirrors the
/// snake_case column stored in `public.notifications.type`. `code` is the
/// only string the DB sees — `enum.name` is camelCase and is intentionally
/// not used on the wire so renaming an enum value here is a refactor-only
/// change.
enum NotificationKind {
  // ---- Customer-facing ---------------------------------------------------
  order('order'),
  orderCreated('order_created'),
  orderShipped('order_shipped'),
  orderDelivered('order_delivered'),
  priceDrop('price_drop'),
  supportReply('support_reply'),
  news('news'),
  promo('promo'),
  review('review'),
  systemAlert('system_alert'),

  // ---- Seller-facing -----------------------------------------------------
  sellerApproved('seller_approved'),
  sellerRejected('seller_rejected'),
  sellerNewOrder('seller_new_order'),
  sellerOrderCancelled('seller_order_cancelled'),
  sellerProductApproved('seller_product_approved'),
  sellerProductRejected('seller_product_rejected'),
  sellerLowStock('seller_low_stock'),

  // ---- Fallback ----------------------------------------------------------
  general('general');

  const NotificationKind(this.code);

  /// Canonical snake_case identifier — the value stored in the database
  /// and emitted in push payloads. Don't infer this from [name].
  final String code;

  static NotificationKind fromString(String? raw) {
    if (raw == null) return NotificationKind.general;
    for (final kind in NotificationKind.values) {
      if (kind.code == raw) return kind;
    }
    return NotificationKind.general;
  }

  /// Icon shown in the inbox tile. Kept in this layer (not in the widget)
  /// because the same mapping is reused by the simulator screen and tests.
  IconData get icon {
    return switch (this) {
      NotificationKind.order ||
      NotificationKind.orderCreated => Iconsax.box_1,
      NotificationKind.orderShipped => Iconsax.truck_fast,
      NotificationKind.orderDelivered => Iconsax.tick_circle,
      NotificationKind.priceDrop => Iconsax.discount_circle,
      NotificationKind.supportReply => Iconsax.message_text,
      NotificationKind.news => Iconsax.global,
      NotificationKind.promo => Iconsax.discount_shape,
      NotificationKind.review => Iconsax.star_1,
      NotificationKind.sellerApproved => Icons.storefront,
      NotificationKind.sellerRejected => Icons.error_outline,
      NotificationKind.sellerNewOrder => Iconsax.shopping_bag,
      NotificationKind.sellerOrderCancelled => Iconsax.close_circle,
      NotificationKind.sellerProductApproved => Iconsax.box_tick,
      NotificationKind.sellerProductRejected => Iconsax.box_remove,
      NotificationKind.sellerLowStock => Iconsax.warning_2,
      NotificationKind.systemAlert => Iconsax.danger,
      NotificationKind.general => Iconsax.notification,
    };
  }

  /// Tinted accent for the icon background. Pulled from the Premium
  /// terracotta palette where possible so the inbox stays on-brand. The
  /// `general` fallback is grey-ish so it visually de-emphasises legacy
  /// rows without an explicit type.
  Color get accent {
    return switch (this) {
      NotificationKind.order ||
      NotificationKind.orderCreated => const Color(0xFFC27A5F), // terracotta
      NotificationKind.orderShipped => const Color(0xFF4A6CF7), // cool blue
      NotificationKind.orderDelivered => const Color(0xFF2F9E6E), // emerald
      NotificationKind.priceDrop => const Color(0xFFE5A23B), // honey
      NotificationKind.supportReply => const Color(0xFF6B7280), // slate
      NotificationKind.news => const Color(0xFF4A6CF7), // cool blue
      NotificationKind.promo => const Color(0xFFE5A23B), // honey
      NotificationKind.review => const Color(0xFFB388EB), // soft violet
      NotificationKind.sellerApproved => const Color(0xFF2F9E6E), // emerald
      NotificationKind.sellerRejected => const Color(0xFFE05A4A), // alert red
      NotificationKind.sellerNewOrder => const Color(0xFF3949AB), // indigo
      NotificationKind.sellerOrderCancelled => const Color(0xFFE05A4A),
      NotificationKind.sellerProductApproved => const Color(0xFF2F9E6E),
      NotificationKind.sellerProductRejected => const Color(0xFFE05A4A),
      NotificationKind.sellerLowStock => const Color(0xFFE5A23B), // honey
      NotificationKind.systemAlert => const Color(0xFFE05A4A), // alert red
      NotificationKind.general => const Color(0xFF8A8A8A), // neutral grey
    };
  }
}

/// Maps every [NotificationKind] to the [AppMode] whose router knows how to
/// render its destination. The notifications screen reads this to decide
/// whether a tap can navigate inline (`current == target`) or has to stash a
/// pending route and trigger a Phoenix-rebirth mode swap.
///
/// Conventions:
///   * Every `sellerX` kind targets [AppMode.seller].
///   * Global broadcasts — `promo`, `news`, `systemAlert` — explicitly
///     target [AppMode.customer], even when the user is currently in seller
///     mode. The reasoning: a discount push or a platform-news ping is a
///     shopping/reading prompt, and the destination screens (storefront,
///     news feed) live on the customer surface. Tapping a promo while in
///     "Backoffice" should bounce the user out to shop, not silently
///     dismiss.
///   * Everything else (customer-side order/support kinds, the fallback)
///     stays customer.
///
/// Don't read `code.startsWith('seller_')` at the call site; always go
/// through this getter so the mapping has one source of truth.
extension NotificationKindRouting on NotificationKind {
  AppMode get targetMode {
    return switch (this) {
      NotificationKind.sellerApproved ||
      NotificationKind.sellerRejected ||
      NotificationKind.sellerNewOrder ||
      NotificationKind.sellerOrderCancelled ||
      NotificationKind.sellerProductApproved ||
      NotificationKind.sellerProductRejected ||
      NotificationKind.sellerLowStock => AppMode.seller,

      // Global / marketing broadcasts — listed explicitly so a future
      // refactor can't silently demote them to "default = customer". Their
      // target is load-bearing: a seller tapping a promo MUST get bounced
      // to customer mode (Phoenix.rebirth) so the storefront is reachable.
      NotificationKind.promo ||
      NotificationKind.news ||
      NotificationKind.systemAlert => AppMode.customer,

      _ => AppMode.customer,
    };
  }
}

class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.kind,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
    this.payload,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationKind kind;

  /// Foreign id (order_id, product_id, ...) the notification refers to.
  /// `null` when the type doesn't need deep linking (e.g. `news`).
  final String? referenceId;

  final bool isRead;
  final DateTime createdAt;

  /// Free-form deep-link metadata sent alongside the row (e.g.
  /// `{'order_id': '...', 'product_slug': '...', 'shop_id': '...'}`).
  /// The routing helper in `notifications_screen.dart` consults this when
  /// the destination needs more than [referenceId] — e.g. a price drop that
  /// carries `{'product_slug': 'oak-shelf'}` to land on the product page.
  ///
  /// Persisted in the `public.notifications.data` jsonb column — the Dart
  /// field is named `payload` for readability, but the wire/JSON key is
  /// always `data` (see [fromJson] / [toJson]). The column defaults to
  /// `'{}'::jsonb` on the DB so this is `{}` for older rows, never `null`
  /// in practice — but the field stays nullable so the model can be built
  /// in tests / from push payloads that don't include the key.
  final Map<String, dynamic>? payload;

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      body: body,
      kind: kind,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      payload: payload,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // The DB column is `data` (jsonb). Also accept `payload` as a fallback
    // so push handlers and test fixtures that emit the friendlier name
    // continue to round-trip. The first non-null wins.
    final rawPayload = json['data'] ?? json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : null;
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      kind: NotificationKind.fromString(json['type'] as String?),
      referenceId: json['reference_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': kind.code,
      'reference_id': referenceId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      // DB column is `data` (NOT NULL with default `'{}'::jsonb`) — always
      // emit an object so an update/insert never violates the NOT NULL.
      'data': payload ?? const <String, dynamic>{},
    };
  }

  @override
  List<Object?> get props =>
      [id, isRead, title, body, kind, referenceId, createdAt, payload];
}
