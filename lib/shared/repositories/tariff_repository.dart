import 'dart:io';

import '../../core/result/result.dart';
import '../models/tariff.dart';
import 'payment_repository.dart';

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

/// Tariff plan catalog + the P2P upgrade write path (receipt upload → request
/// → admin approval).
///
/// ROADMAP B.1 — migrated to the `Result<T, Failure>` contract. The two
/// realtime feeds ([watchPending], [watchCurrentPlan]) stay plain `Stream`s.
abstract class TariffRepository {
  Stream<TariffSubscription?> watchPending();
  Stream<TariffPlan> watchCurrentPlan();

  Future<Result<TariffSnapshot>> currentSnapshot();
  Future<Result<TariffSubscription?>> currentPending();
  Future<Result<List<TariffSubscription>>> history();
  Future<Result<TariffPaymentInstructions>> paymentInstructions();

  /// Server-driven plan catalog backing the tariff cards.
  Future<Result<List<SubscriptionPlan>>> fetchPlans();

  Future<Result<String>> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  });

  Future<Result<TariffSubscription>> upgrade(TariffUpgradeInput input);
  Future<Result<void>> cancelPending(String subscriptionId);

  /// Mint a Payme/Click checkout deep-link for a self-serve tariff payment
  /// (`POST /seller/tariff/buy`) and return the URL the seller opens to pay.
  /// The Merchant webhook activates the plan on confirmation — there is no
  /// screenshot and no admin step. Throws `ApiError` on 404 (unknown plan) /
  /// 400 (free plan) / 503 (provider unconfigured).
  Future<Result<String>> buyPlan({
    required TariffPlan plan,
    required BillingPeriod period,
    required PaymentProvider provider,
  });
}
