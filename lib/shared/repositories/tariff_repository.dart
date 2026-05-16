import 'dart:io';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
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
}

/// Legacy Dio stub — superseded by `SupabaseTariffRepository`. Kept so the
/// `RepositoryResolver` remote branch still resolves on non-Supabase builds;
/// every call returns an [Err].
class RemoteTariffRepository implements TariffRepository {
  RemoteTariffRepository(this._dio);

  // ignore: unused_field — superseded by the Supabase implementation.
  final Object? _dio;

  static const Failure _unavailable = UnknownFailure(
    message: 'Remote tariff — use the Supabase repository',
  );

  @override
  Stream<TariffSubscription?> watchPending() => const Stream.empty();

  @override
  Stream<TariffPlan> watchCurrentPlan() => const Stream.empty();

  @override
  Future<Result<TariffSnapshot>> currentSnapshot() async =>
      const Err(_unavailable);

  @override
  Future<Result<TariffSubscription?>> currentPending() async =>
      const Err(_unavailable);

  @override
  Future<Result<List<TariffSubscription>>> history() async =>
      const Err(_unavailable);

  @override
  Future<Result<TariffPaymentInstructions>> paymentInstructions() async =>
      const Err(_unavailable);

  @override
  Future<Result<List<SubscriptionPlan>>> fetchPlans() async =>
      const Err(_unavailable);

  @override
  Future<Result<String>> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  }) async =>
      const Err(_unavailable);

  @override
  Future<Result<TariffSubscription>> upgrade(TariffUpgradeInput input) async =>
      const Err(_unavailable);

  @override
  Future<Result<void>> cancelPending(String subscriptionId) async =>
      const Err(_unavailable);
}
