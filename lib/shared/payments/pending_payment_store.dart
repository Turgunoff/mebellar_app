import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pending_payment.dart';

/// Persists the single in-flight external payment across app restarts.
///
/// Backed by SharedPreferences, NOT Hive, on purpose: a payment hand-off must
/// stay reconcilable even through a logout (which wipes the per-user Hive
/// boxes) and an OS app-kill. Only one marker is kept — a customer finishes (or
/// abandons) one checkout before starting another, so a new mark overwrites the
/// previous one.
class PendingPaymentStore {
  static const _key = 'pending_payment';

  Future<void> save(PendingPayment payment) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(payment.toJson()));
  }

  Future<PendingPayment?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(_key);
        return null;
      }
      final payment = PendingPayment.fromJson(decoded);
      // A record we can't parse would otherwise wedge recovery forever — drop
      // it so the next launch starts clean.
      if (payment == null) await prefs.remove(_key);
      return payment;
    } catch (_) {
      await prefs.remove(_key);
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
