import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/tariff.dart';
import 'tariff_repository.dart';

/// Live Supabase implementation of [TariffRepository] (ROADMAP B.1) — the
/// P2P upgrade write path.
///
/// Schema — see `docs/supabase_rls_policies.sql.md`:
/// ```
///   subscription_receipts  one row per upgrade request + payment receipt
///   subscriptions          the seller's active plan
///   subscription_plans     the read-only plan catalog
/// ```
/// Payment-receipt screenshots go to the **private** `payment-receipts`
/// bucket under `<seller_uid>/...`; the DB stores the object path, never a
/// public URL — matching the applied RLS storage policy.
class SupabaseTariffRepository implements TariffRepository {
  SupabaseTariffRepository({required SupabaseClient supabase})
      : _client = supabase;

  final SupabaseClient _client;

  static const String _receiptsTable = 'subscription_receipts';
  static const String _subscriptionsTable = 'subscriptions';
  static const String _plansTable = 'subscription_plans';
  static const String _receiptBucket = 'payment-receipts';

  // Emits on seller write actions (upgrade / cancel). App-lifetime singleton.
  final StreamController<TariffSubscription?> _pendingController =
      StreamController<TariffSubscription?>.broadcast();

  @override
  Stream<TariffSubscription?> watchPending() => _pendingController.stream;

  /// Plan transitions are admin-driven (approval flips `subscriptions`); the
  /// seller picks the change up via [currentSnapshot] on the next load, so a
  /// live feed isn't wired here.
  @override
  Stream<TariffPlan> watchCurrentPlan() => const Stream.empty();

  @override
  Future<Result<TariffSnapshot>> currentSnapshot() => runCatching(() async {
        final shopId = await _requireShopId();
        final planCode = await _currentPlanCode();
        final count = await _activeProductCount(shopId);
        return TariffSnapshot(
          plan: TariffPlan.fromCode(planCode),
          activeProductsCount: count,
        );
      });

  @override
  Future<Result<TariffSubscription?>> currentPending() =>
      runCatching(() async {
        final userId = _requireUserId();
        final row = await _client
            .from(_receiptsTable)
            .select()
            .eq('seller_id', userId)
            .eq('status', TariffUpgradeStatus.pending.code)
            .order('submitted_at', ascending: false)
            .limit(1)
            .maybeSingle();
        return row == null ? null : TariffSubscription.fromJson(row);
      });

  @override
  Future<Result<List<TariffSubscription>>> history() => runCatching(() async {
        final userId = _requireUserId();
        final rows = await _client
            .from(_receiptsTable)
            .select()
            .eq('seller_id', userId)
            .order('submitted_at', ascending: false);
        return rows
            .map(TariffSubscription.fromJson)
            .toList(growable: false);
      });

  @override
  Future<Result<TariffPaymentInstructions>> paymentInstructions() =>
      runCatching(() async {
        final shopId = await _requireShopId();
        // Business config — the admin's P2P card. Hardcoded until a
        // `payment_settings` table exists; the seller-facing note carries
        // the shop id so the admin can reconcile the transfer.
        return TariffPaymentInstructions(
          cardNumber: '8600 1234 5678 9012',
          cardHolder: 'KARIMOV AZIZ',
          bankName: 'Uzcard',
          note: 'SHOP-$shopId',
          telegramSupportUrl: 'tg://resolve?domain=MebellarSupportBot',
        );
      });

  @override
  Future<Result<List<SubscriptionPlan>>> fetchPlans() => runCatching(() async {
        final rows = await _client
            .from(_plansTable)
            .select(
              'id, code, name, price_monthly, max_products, '
              'max_images_per_product, commission_rate, is_recommended, '
              'features_uz, features_ru',
            )
            .order('price_monthly', ascending: true);
        return rows
            .map(SubscriptionPlan.fromJson)
            .toList(growable: false);
      });

  @override
  Future<Result<String>> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  }) =>
      runCatching(() async {
        final userId = _requireUserId();
        final path =
            '$userId/receipt-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        await _client.storage.from(_receiptBucket).upload(
              path,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
        // Returns the private object path — the UI fetches signed URLs.
        return path;
      });

  @override
  Future<Result<TariffSubscription>> upgrade(TariffUpgradeInput input) =>
      runCatching(() async {
        final userId = _requireUserId();
        // RLS requires a freshly-inserted receipt to start `pending`.
        final row = await _client.from(_receiptsTable).insert({
          'seller_id': userId,
          'plan_code': input.plan.code,
          'billing_period': input.period.code,
          'amount': input.amount,
          'status': TariffUpgradeStatus.pending.code,
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
          'payment_screenshot_path': input.paymentScreenshotUrl,
        }).select().single();
        final subscription = TariffSubscription.fromJson(row);
        if (!_pendingController.isClosed) {
          _pendingController.add(subscription);
        }
        return subscription;
      });

  @override
  Future<Result<void>> cancelPending(String subscriptionId) =>
      runCatching(() async {
        // Seller-initiated cancel of a still-pending receipt. NOTE: this
        // needs an RLS UPDATE policy on `subscription_receipts` letting the
        // owner flip status pending → cancelled — see the Phase 11 report.
        await _client
            .from(_receiptsTable)
            .update({'status': TariffUpgradeStatus.cancelled.code})
            .eq('id', subscriptionId)
            .eq('status', TariffUpgradeStatus.pending.code);
        if (!_pendingController.isClosed) _pendingController.add(null);
      });

  // ─── Internals ──────────────────────────────────────────────────────────

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
    }
    return userId;
  }

  Future<String> _requireShopId() async {
    final userId = _requireUserId();
    final row = await _client
        .from('shops')
        .select('id')
        .eq('seller_id', userId)
        .maybeSingle();
    final shopId = row?['id'] as String?;
    if (shopId == null) {
      throw const ServerFailure(message: "Do'kon topilmadi");
    }
    return shopId;
  }

  /// Plan code of the seller's active (approved) subscription; `null` falls
  /// back to the free tier via [TariffPlan.fromCode].
  Future<String?> _currentPlanCode() async {
    final userId = _requireUserId();
    final row = await _client
        .from(_subscriptionsTable)
        .select('plan_code')
        .eq('seller_id', userId)
        .eq('status', TariffUpgradeStatus.approved.code)
        .order('expires_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['plan_code'] as String?;
  }

  Future<int> _activeProductCount(String shopId) async {
    final rows =
        await _client.from('products').select('id').eq('shop_id', shopId);
    return rows.length;
  }
}
