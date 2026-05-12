import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Closed set of notification kinds the inbox knows how to render. New
/// values added on the backend default to [NotificationKind.general] so the
/// UI never breaks when an unknown type arrives — see [fromString].
enum NotificationKind {
  order,
  news,
  promo,
  review,
  general;

  static NotificationKind fromString(String? raw) {
    return switch (raw) {
      'order' => NotificationKind.order,
      'news' => NotificationKind.news,
      'promo' => NotificationKind.promo,
      'review' => NotificationKind.review,
      _ => NotificationKind.general,
    };
  }

  /// Icon shown in the inbox tile. Kept in this layer (not in the widget)
  /// because the same mapping is reused by the simulator screen and tests.
  IconData get icon {
    return switch (this) {
      NotificationKind.order => Iconsax.box_1,
      NotificationKind.news => Iconsax.global,
      NotificationKind.promo => Iconsax.discount_shape,
      NotificationKind.review => Iconsax.star_1,
      NotificationKind.general => Iconsax.notification,
    };
  }

  /// Tinted accent for the icon background. Pulled from the Premium
  /// terracotta palette where possible so the inbox stays on-brand. The
  /// `general` fallback is grey-ish so it visually de-emphasises legacy
  /// rows without an explicit type.
  Color get accent {
    return switch (this) {
      NotificationKind.order => const Color(0xFFC27A5F), // terracotta
      NotificationKind.news => const Color(0xFF4A6CF7), // cool blue
      NotificationKind.promo => const Color(0xFFE5A23B), // honey
      NotificationKind.review => const Color(0xFFB388EB), // soft violet
      NotificationKind.general => const Color(0xFF8A8A8A), // neutral grey
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
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      kind: NotificationKind.fromString(json['type'] as String?),
      referenceId: json['reference_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': kind.name,
      'reference_id': referenceId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props =>
      [id, isRead, title, body, kind, referenceId, createdAt];
}
