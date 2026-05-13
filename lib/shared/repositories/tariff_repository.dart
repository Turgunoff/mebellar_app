import 'dart:io';

import 'package:dio/dio.dart';

import '../models/tariff.dart';

class TariffPaymentInstructions {
  const TariffPaymentInstructions({
    required this.cardNumber,
    required this.cardHolder,
    required this.bankName,
    required this.note,
    required this.telegramSupportUrl,
  });

  final String cardNumber;
  final String cardHolder;
  final String bankName;

  /// `Izoh` foydalanuvchiga ko'rsatiladigan format — backend SHOP-{shop_id}'ni
  /// avto-yaratadi. Mock holatda biz hardcoded shop_id ishlatamiz.
  final String note;
  final String telegramSupportUrl;
}

class TariffUpgradeInput {
  const TariffUpgradeInput({
    required this.plan,
    required this.period,
    required this.amount,
    required this.paymentScreenshotUrl,
  });

  final TariffPlan plan;
  final BillingPeriod period;
  final int amount;
  final String paymentScreenshotUrl;
}

abstract class TariffRepository {
  Stream<TariffSubscription?> watchPending();
  Stream<TariffPlan> watchCurrentPlan();

  Future<TariffSnapshot> currentSnapshot();
  Future<TariffSubscription?> currentPending();
  Future<List<TariffSubscription>> history();
  Future<TariffPaymentInstructions> paymentInstructions();

  /// Server-driven plan catalog backing the tariff cards (prices, limits,
  /// feature bullets, recommended ribbon). Hits `public.subscription_plans`
  /// when Supabase is wired; the mock implementation can fall back to
  /// static enum-derived defaults until then.
  Future<List<SubscriptionPlan>> fetchPlans();

  Future<String> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  });

  Future<TariffSubscription> upgrade(TariffUpgradeInput input);
  Future<void> cancelPending(String subscriptionId);
}

class RemoteTariffRepository implements TariffRepository {
  RemoteTariffRepository(this._dio);
  // ignore: unused_field — Sprint 9 backend wires real endpoints.
  final Dio _dio;

  @override
  Stream<TariffSubscription?> watchPending() => const Stream.empty();

  @override
  Stream<TariffPlan> watchCurrentPlan() => const Stream.empty();

  @override
  Future<TariffSnapshot> currentSnapshot() =>
      throw UnimplementedError('Remote tariff — Sprint 9 backend');

  @override
  Future<TariffSubscription?> currentPending() =>
      throw UnimplementedError('Remote tariff — Sprint 9 backend');

  @override
  Future<List<TariffSubscription>> history() =>
      throw UnimplementedError('Remote tariff — Sprint 9 backend');

  @override
  Future<TariffPaymentInstructions> paymentInstructions() =>
      throw UnimplementedError('Remote tariff — Sprint 9 backend');

  @override
  Future<List<SubscriptionPlan>> fetchPlans() =>
      throw UnimplementedError('Remote tariff — Sprint 9 backend');

  @override
  Future<String> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  }) =>
      throw UnimplementedError('Remote tariff — Sprint 9 backend');

  @override
  Future<TariffSubscription> upgrade(TariffUpgradeInput input) =>
      throw UnimplementedError('Remote tariff — Sprint 9 backend');

  @override
  Future<void> cancelPending(String subscriptionId) =>
      throw UnimplementedError('Remote tariff — Sprint 9 backend');
}
