import 'package:flutter/material.dart';

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
      OrderStatus.pending => 'Yangi',
      OrderStatus.confirmed => 'Qabul qilingan',
      OrderStatus.preparing => 'Tayyorlanmoqda',
      OrderStatus.shipped => "Yo'lda",
      OrderStatus.delivered => 'Yetkazilgan',
      OrderStatus.cancelled => 'Bekor qilingan',
    };

/// Background / foreground colours for a status pill.
({Color bg, Color fg}) sellerOrderStatusColors(OrderStatus status) =>
    switch (status) {
      OrderStatus.pending =>
        (bg: const Color(0xFFFFF1D6), fg: const Color(0xFF8C5A12)),
      OrderStatus.confirmed =>
        (bg: const Color(0xFFE3F0FF), fg: const Color(0xFF1F5FA8)),
      OrderStatus.preparing =>
        (bg: const Color(0xFFEDE7FB), fg: const Color(0xFF5B3FB0)),
      OrderStatus.shipped =>
        (bg: const Color(0xFFDDF3F0), fg: const Color(0xFF18756A)),
      OrderStatus.delivered =>
        (bg: const Color(0xFFE0F3E4), fg: const Color(0xFF1E7A38)),
      OrderStatus.cancelled =>
        (bg: const Color(0xFFF3E1E1), fg: const Color(0xFF9A3434)),
    };

/// Uzbek label for the forward action that moves an order *into* [target].
String sellerOrderActionLabel(OrderStatus target) => switch (target) {
      OrderStatus.confirmed => 'Buyurtmani qabul qilish',
      OrderStatus.preparing => 'Tayyorlashni boshlash',
      OrderStatus.shipped => "Yo'lga chiqarish",
      OrderStatus.delivered => 'Yetkazildi deb belgilash',
      OrderStatus.pending || OrderStatus.cancelled => '',
    };
