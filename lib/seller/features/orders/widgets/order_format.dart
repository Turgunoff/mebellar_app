import 'package:flutter/material.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/order_status.dart';

/// Presentation helpers shared by the seller order list and detail screens.
/// Kept in one place so the status vocabulary (label + pill colours) stays
/// consistent across both surfaces.

/// Groups an integer amount with spaces — `12400000` → `12 400 000`.
String formatOrderAmount(num value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Fixed `dd.MM.yyyy HH:mm` stamp — locale-independent so it renders without
/// `intl` locale data being initialised.
String formatOrderDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// Seller-facing Uzbek label for an order status.
String sellerOrderStatusLabel(OrderStatus status) => switch (status) {
      OrderStatus.pending => tr('seller_orders.tab_newTab'),
      OrderStatus.confirmed => tr('seller_orders.status_confirmed'),
      OrderStatus.awaitingPayment =>
        tr('seller_orders.status_awaiting_payment'),
      OrderStatus.preparing => tr('seller_orders.action_preparing'),
      OrderStatus.shipped => tr('seller_orders.order_status_shipped'),
      OrderStatus.delivered => tr('seller_orders.tab_done'),
      OrderStatus.cancelled => tr('seller_orders.tab_cancelled'),
    };

/// Background / foreground colours for a status pill, resolved against the
/// brightness-aware seller palette [c] so each hue flips with the theme. The
/// teal "shipped" pair has no [SellerColors] token, so its dark variant is
/// spelled out inline.
({Color bg, Color fg}) sellerOrderStatusColors(
  OrderStatus status,
  SellerColors c,
) =>
    switch (status) {
      OrderStatus.pending => (bg: c.warningBg, fg: c.warning),
      OrderStatus.awaitingPayment => (bg: c.warningBg, fg: c.warning),
      OrderStatus.confirmed => (bg: c.infoBg, fg: c.info),
      OrderStatus.preparing => (bg: c.progressBg, fg: c.progress),
      OrderStatus.shipped => c.brightness == Brightness.dark
          ? (bg: const Color(0xFF15302C), fg: const Color(0xFF5FC9BC))
          : (bg: const Color(0xFFDDF3F0), fg: const Color(0xFF18756A)),
      OrderStatus.delivered => (bg: c.positiveBg, fg: c.positive),
      OrderStatus.cancelled => (bg: c.negativeBg, fg: c.negative),
    };

/// Uzbek label for the forward action that moves an order *into* [target].
String sellerOrderActionLabel(OrderStatus target) => switch (target) {
      OrderStatus.confirmed => tr('seller_orders.action_label_confirm'),
      OrderStatus.preparing => tr('seller_orders.action_label_preparing'),
      OrderStatus.shipped => tr('seller_orders.action_label_shipped'),
      OrderStatus.delivered => tr('seller_orders.action_label_delivered'),
      OrderStatus.pending ||
      OrderStatus.awaitingPayment ||
      OrderStatus.cancelled => '',
    };
