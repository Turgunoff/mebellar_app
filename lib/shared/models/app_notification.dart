import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Categorisation drives icon, accent colour and which app mode the
/// deep-link expects. Backend sends the same `kind` string in the OneSignal
/// payload's `additionalData`.
enum NotificationKind {
  orderPlaced('order_placed', mode: 'seller', icon: Icons.shopping_bag_outlined),
  orderUpdated('order_updated', mode: 'customer', icon: Icons.local_shipping_outlined),
  orderCancelled('order_cancelled', mode: 'customer', icon: Icons.cancel_outlined),
  productApproved('product_approved', mode: 'seller', icon: Icons.check_circle_outline),
  productRejected('product_rejected', mode: 'seller', icon: Icons.error_outline),
  verificationApproved('verification_approved', mode: 'seller', icon: Icons.verified_user_outlined),
  verificationRejected('verification_rejected', mode: 'seller', icon: Icons.report_outlined),
  tariffApproved('tariff_approved', mode: 'seller', icon: Icons.workspace_premium_outlined),
  tariffRejected('tariff_rejected', mode: 'seller', icon: Icons.payments_outlined),
  promo('promo', mode: 'customer', icon: Icons.campaign_outlined);

  const NotificationKind(this.code, {required this.mode, required this.icon});

  final String code;

  /// `customer` or `seller`. Determines whether the handler routes directly
  /// or stashes the link as a pending route + flips app mode.
  final String mode;
  final IconData icon;

  static NotificationKind fromCode(String? code) {
    return values.firstWhere(
      (k) => k.code == code,
      orElse: () => NotificationKind.promo,
    );
  }
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.route,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;

  /// Deep link target route — relative to the target mode's router (e.g.
  /// `/orders/ord-123`, `/seller/onboarding`). The handler resolves this
  /// against `kind.mode` to know which app to switch into.
  final String route;
  final DateTime createdAt;
  final bool read;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      route: route,
      createdAt: createdAt,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toPayload() => {
        'id': id,
        'kind': kind.code,
        'mode': kind.mode,
        'route': route,
        'title': title,
        'body': body,
        'ts': createdAt.toIso8601String(),
      };

  factory AppNotification.fromPayload(Map<String, dynamic> payload) {
    final kind = NotificationKind.fromCode(payload['kind'] as String?);
    return AppNotification(
      id: payload['id'] as String? ??
          'notif-${DateTime.now().millisecondsSinceEpoch}',
      kind: kind,
      title: payload['title'] as String? ?? '',
      body: payload['body'] as String? ?? '',
      route: payload['route'] as String? ?? '/',
      createdAt: DateTime.tryParse(payload['ts'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, read, kind];
}
