import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/tariff.dart';
import '../repositories/tariff_repository.dart';
import 'mock_seller_state.dart';

/// Stateful mock that drives the entire upgrade UX. Sprint 9 spec: after
/// submission, an admin "approves" the request via Telegram bot — here we
/// fake that with a 12-second timer so demos can see the status flip live.
///
/// The plan catalog ([fetchPlans]) is the exception: it hits Supabase
/// directly when [_supabase] is provided so the UI is fully server-driven.
/// Falls back to the enum-derived static list when Supabase isn't wired.
class MockTariffRepository implements TariffRepository {
  MockTariffRepository({SupabaseClient? supabase}) : _supabase = supabase {
    _seedHistory();
  }

  final SupabaseClient? _supabase;

  static const _delay = Duration(milliseconds: 280);
  static const _uploadDelay = Duration(milliseconds: 700);

  TariffPlan _currentPlan = TariffPlan.free;
  final List<TariffSubscription> _history = [];
  TariffSubscription? _pending;
  int _idCounter = 1;

  final _pendingController = StreamController<TariffSubscription?>.broadcast();
  final _planController = StreamController<TariffPlan>.broadcast();

  @override
  Stream<TariffSubscription?> watchPending() => _pendingController.stream;

  @override
  Stream<TariffPlan> watchCurrentPlan() => _planController.stream;

  @override
  Future<Result<TariffSnapshot>> currentSnapshot() async {
    await Future<void>.delayed(_delay);
    return Ok(TariffSnapshot(
      plan: _currentPlan,
      activeProductsCount: MockSellerState.instance.profile == null ? 0 : 12,
    ));
  }

  @override
  Future<Result<TariffSubscription?>> currentPending() async {
    await Future<void>.delayed(_delay);
    return Ok(_pending);
  }

  @override
  Future<Result<List<TariffSubscription>>> history() async {
    await Future<void>.delayed(_delay);
    return Ok(List<TariffSubscription>.unmodifiable(_history));
  }

  @override
  Future<Result<List<SubscriptionPlan>>> fetchPlans() async {
    final supabase = _supabase;
    if (supabase != null) {
      try {
        final rows = await supabase
            .from('subscription_plans')
            .select(
              'id, code, name, price_monthly, max_products, '
              'max_images_per_product, commission_rate, is_recommended, '
              'features_uz, features_ru',
            )
            .order('price_monthly', ascending: true);
        return Ok(rows
            .map<SubscriptionPlan>(SubscriptionPlan.fromJson)
            .toList(growable: false));
      } catch (_) {
        // Network/auth blip — drop through to the static fallback so the
        // tariff screen still renders something sensible.
      }
    }
    return Ok(_enumFallbackPlans());
  }

  /// Mirrors the rows the migration seeded so offline / no-Supabase runs
  /// still have a non-empty catalog.
  List<SubscriptionPlan> _enumFallbackPlans() {
    SubscriptionPlan from(
      TariffPlan plan, {
      required bool isRecommended,
      required List<String> uz,
      required List<String> ru,
    }) {
      return SubscriptionPlan(
        id: plan.code,
        code: plan.code,
        name: '${plan.code[0].toUpperCase()}${plan.code.substring(1)} tarif',
        priceMonthly: plan.monthlyPriceUzs,
        maxProducts: plan.maxActiveProducts,
        maxImagesPerProduct: plan.maxImagesPerProduct,
        commissionRate: plan.commissionRate,
        isRecommended: isRecommended,
        featuresUz: uz,
        featuresRu: ru,
      );
    }

    return [
      from(
        TariffPlan.free,
        isRecommended: false,
        uz: const ['Asosiy katalog ko\'rinishi', 'Standart support'],
        ru: const ['Базовый вид каталога', 'Стандартная поддержка'],
      ),
      from(
        TariffPlan.basic,
        isRecommended: false,
        uz: const ['Kengaytirilgan filtr va analitika', 'Email support'],
        ru: const ['Расширенные фильтры и аналитика', 'Email поддержка'],
      ),
      from(
        TariffPlan.pro,
        isRecommended: true,
        uz: const [
          'Detali analitika va eksport',
          'Prioritet Telegram support',
          'Brend ranglari va premium kartochkalar',
        ],
        ru: const [
          'Детальная аналитика и экспорт',
          'Приоритетная поддержка в Telegram',
          'Брендовые цвета и премиум карточки',
        ],
      ),
      from(
        TariffPlan.enterprise,
        isRecommended: false,
        uz: const [
          'Cheksiz mahsulot va xodimlar',
          'API kirishi va integratsiyalar',
          'Shaxsiy account manager',
        ],
        ru: const [
          'Безлимитные товары и сотрудники',
          'Доступ к API и интеграции',
          'Личный аккаунт-менеджер',
        ],
      ),
    ];
  }

  @override
  Future<Result<TariffPaymentInstructions>> paymentInstructions() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final shopId = MockSellerState.instance.shopId ?? 'shop-mh';
    return Ok(TariffPaymentInstructions(
      cardNumber: '8600 1234 5678 9012',
      cardHolder: 'KARIMOV AZIZ',
      bankName: 'Uzcard',
      note: 'SHOP-$shopId',
      telegramSupportUrl: 'tg://resolve?domain=MebellarSupportBot',
    ));
  }

  @override
  Future<Result<String>> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  }) async {
    await Future<void>.delayed(_uploadDelay);
    return Ok(
      'payments/upgrade-'
      '${clock.now().millisecondsSinceEpoch}.$fileExtension',
    );
  }

  @override
  Future<Result<TariffSubscription>> upgrade(TariffUpgradeInput input) async {
    await Future<void>.delayed(_delay);
    if (_pending != null && _pending!.status.isPending) {
      return const Err(ServerFailure(
        message: "Sizda allaqachon kutayotgan to'lov bor — "
            "uni tekshirib bo'lguncha kuting",
      ));
    }
    _idCounter += 1;
    final subscription = TariffSubscription(
      id: 'sub-mock-$_idCounter',
      plan: input.plan,
      period: input.period,
      amount: input.amount,
      status: TariffUpgradeStatus.pending,
      submittedAt: clock.now(),
      paymentScreenshotUrl: input.paymentScreenshotUrl,
    );
    _pending = subscription;
    _history.insert(0, subscription);
    _pendingController.add(subscription);

    // Mock admin behaviour: resolves after 12s.
    Future<void>.delayed(const Duration(seconds: 12), _resolvePending);
    return Ok(subscription);
  }

  @override
  Future<Result<void>> cancelPending(String subscriptionId) async {
    await Future<void>.delayed(_delay);
    final p = _pending;
    if (p == null || p.id != subscriptionId) return const Ok<void>(null);
    final cancelled = p.copyWith(status: TariffUpgradeStatus.cancelled);
    _pending = null;
    final idx = _history.indexWhere((s) => s.id == subscriptionId);
    if (idx >= 0) _history[idx] = cancelled;
    _pendingController.add(null);
    return const Ok<void>(null);
  }

  void _resolvePending() {
    final pending = _pending;
    if (pending == null || !pending.status.isPending) return;
    // Deterministic-ish: every third upgrade is rejected so the demo flow
    // always exercises both branches without RNG.
    final shouldApprove = _idCounter % 3 != 0;
    final now = clock.now();
    final updated = shouldApprove
        ? pending.copyWith(
            status: TariffUpgradeStatus.approved,
            approvedAt: now,
            expiresAt: now.add(
              pending.period == BillingPeriod.yearly
                  ? const Duration(days: 365)
                  : const Duration(days: 30),
            ),
          )
        : pending.copyWith(
            status: TariffUpgradeStatus.rejected,
            rejectedAt: now,
            rejectionReason:
                'To\'lov tasdiqlanmadi — karta raqami yoki summa noto\'g\'ri',
          );
    _pending = null;
    final idx = _history.indexWhere((s) => s.id == pending.id);
    if (idx >= 0) _history[idx] = updated;
    if (shouldApprove) {
      _currentPlan = updated.plan;
      _planController.add(_currentPlan);
    }
    _pendingController.add(null);
  }

  void _seedHistory() {
    final approvedAt = clock.now().subtract(const Duration(days: 60));
    _history.add(
      TariffSubscription(
        id: 'sub-seed-1',
        plan: TariffPlan.basic,
        period: BillingPeriod.monthly,
        amount: TariffPlan.basic.monthlyPriceUzs,
        status: TariffUpgradeStatus.approved,
        submittedAt: approvedAt.subtract(const Duration(hours: 2)),
        approvedAt: approvedAt,
        expiresAt: approvedAt.add(const Duration(days: 30)),
        paymentScreenshotUrl: 'payments/seed-receipt.jpg',
      ),
    );
  }

  Future<void> dispose() async {
    if (!_pendingController.isClosed) await _pendingController.close();
    if (!_planController.isClosed) await _planController.close();
  }
}
