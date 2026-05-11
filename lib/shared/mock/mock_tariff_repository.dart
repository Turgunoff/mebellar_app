import 'dart:async';
import 'dart:io';

import '../models/tariff.dart';
import '../repositories/tariff_repository.dart';
import 'mock_seller_state.dart';

/// Stateful mock that drives the entire upgrade UX. Sprint 9 spec: after
/// submission, an admin "approves" the request via Telegram bot — here we
/// fake that with a 12-second timer so demos can see the status flip live.
class MockTariffRepository implements TariffRepository {
  MockTariffRepository() {
    _seedHistory();
  }

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
  Future<TariffSnapshot> currentSnapshot() async {
    await Future<void>.delayed(_delay);
    return TariffSnapshot(
      plan: _currentPlan,
      activeProductsCount: MockSellerState.instance.profile == null ? 0 : 12,
    );
  }

  @override
  Future<TariffSubscription?> currentPending() async {
    await Future<void>.delayed(_delay);
    return _pending;
  }

  @override
  Future<List<TariffSubscription>> history() async {
    await Future<void>.delayed(_delay);
    return List<TariffSubscription>.unmodifiable(_history);
  }

  @override
  Future<TariffPaymentInstructions> paymentInstructions() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final shopId =
        MockSellerState.instance.shopId ?? 'shop-mh';
    return TariffPaymentInstructions(
      cardNumber: '8600 1234 5678 9012',
      cardHolder: 'KARIMOV AZIZ',
      bankName: 'Uzcard',
      note: 'SHOP-$shopId',
      telegramSupportUrl: 'tg://resolve?domain=MebellarSupportBot',
    );
  }

  @override
  Future<String> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  }) async {
    await Future<void>.delayed(_uploadDelay);
    return 'payments/upgrade-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
  }

  @override
  Future<TariffSubscription> upgrade(TariffUpgradeInput input) async {
    await Future<void>.delayed(_delay);
    if (_pending != null && _pending!.status.isPending) {
      throw StateError(
          'Sizda allaqachon kutayotgan to\'lov bor — uni tekshirib bo\'lguncha kuting');
    }
    _idCounter += 1;
    final subscription = TariffSubscription(
      id: 'sub-mock-$_idCounter',
      plan: input.plan,
      period: input.period,
      amount: input.amount,
      status: TariffUpgradeStatus.pending,
      submittedAt: DateTime.now(),
      paymentScreenshotUrl: input.paymentScreenshotUrl,
    );
    _pending = subscription;
    _history.insert(0, subscription);
    _pendingController.add(subscription);

    // Mock admin behaviour: 12s'dan keyin approve qiladi (90% holat). 10%
    // hollarda rejected — tester ikkala flowni ham ko'ra olsin.
    Future<void>.delayed(const Duration(seconds: 12), () {
      _resolvePending();
    });
    return subscription;
  }

  @override
  Future<void> cancelPending(String subscriptionId) async {
    await Future<void>.delayed(_delay);
    final p = _pending;
    if (p == null || p.id != subscriptionId) return;
    final cancelled = p.copyWith(status: TariffUpgradeStatus.cancelled);
    _pending = null;
    final idx = _history.indexWhere((s) => s.id == subscriptionId);
    if (idx >= 0) _history[idx] = cancelled;
    _pendingController.add(null);
  }

  void _resolvePending() {
    final pending = _pending;
    if (pending == null || !pending.status.isPending) return;
    // Deterministic-ish: every odd-indexed upgrade is rejected so the
    // demo flow always exercises both branches without RNG.
    final shouldApprove = _idCounter % 3 != 0;
    final now = DateTime.now();
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
    // Pretend the seller upgraded once 60 days ago to Basic, which then
    // expired — gives the history screen something to render on first open.
    final approvedAt = DateTime.now().subtract(const Duration(days: 60));
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
