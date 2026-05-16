import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/models/order_status.dart';
import 'package:woody_app/shared/models/shop_settings.dart';
import 'package:woody_app/shared/models/tariff.dart';
import 'package:woody_app/shared/models/verification_document.dart';
import 'package:woody_app/shared/models/verification_status.dart';
import 'package:woody_app/shared/mock/mock_seller_order_repository.dart';
import 'package:woody_app/shared/mock/mock_seller_services_repository.dart';
import 'package:woody_app/shared/mock/mock_seller_state.dart';
import 'package:woody_app/shared/mock/mock_seller_verification_repository.dart';
import 'package:woody_app/shared/mock/mock_shop_settings_repository.dart';
import 'package:woody_app/shared/mock/mock_tariff_repository.dart';
import 'package:woody_app/shared/repositories/seller_order_repository.dart';
import 'package:woody_app/shared/repositories/seller_services_repository.dart';
import 'package:woody_app/shared/repositories/seller_verification_repository.dart';
import 'package:woody_app/shared/repositories/shop_settings_repository.dart';
import 'package:woody_app/shared/repositories/tariff_repository.dart';

/// ROADMAP B.5 / REFACTORING §5.4 — repository contract tests.
///
/// Each `*Contract(label, build)` function is a behaviour suite that *every*
/// implementation of the interface must satisfy. It is parameterised over a
/// `build` factory so the same assertions run against the mock today and
/// against `Supabase*Repository(fakeClient)` once a fake-Supabase harness
/// exists — that is what prevents "mock drift" (BUGS_AND_ISSUES.md §5.3).
///
/// Only the mock implementations are wired in `main()`: the Supabase ones
/// need a live/fake Postgres backend, which is out of scope for a pure unit
/// test. The contract functions are written backend-agnostic so adding
/// `…Contract('supabase', () => SupabaseXRepository(fakeClient))` is a
/// one-liner when that harness lands.
///
/// All five repositories return `Result<T, Failure>`; the suites assert on
/// `isOk` / `isErr` / `valueOrNull` rather than catching exceptions. Time-
/// dependent paths are pinned with `package:clock`'s `withClock`.
void main() {
  sellerOrderRepositoryContract('mock', MockSellerOrderRepository.new);
  shopSettingsRepositoryContract('mock', MockShopSettingsRepository.new);
  sellerServicesRepositoryContract('mock', MockSellerServicesRepository.new);
  sellerVerificationRepositoryContract(
    'mock',
    MockSellerVerificationRepository.new,
  );
  tariffRepositoryContract('mock', MockTariffRepository.new);
}

// ─────────────────────────── SellerOrderRepository ──────────────────────────

void sellerOrderRepositoryContract(
  String label,
  SellerOrderRepository Function() build,
) {
  group('SellerOrderRepository contract [$label]', () {
    late SellerOrderRepository repo;
    setUp(() => repo = build());
    tearDown(() => repo.dispose());

    test('list() resolves to Ok with the seeded order book', () async {
      final result = await repo.list();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNotEmpty);
    });

    test('getById() resolves Ok for a known order', () async {
      final known = (await repo.list()).valueOrNull!.first;
      final result = await repo.getById(known.id);
      expect(result.valueOrNull?.id, known.id);
    });

    test('getById() resolves Err for an unknown id', () async {
      final result = await repo.getById('does-not-exist');
      expect(result.isErr, isTrue);
    });

    test('an illegal status transition resolves to Err (not a throw)',
        () async {
      // A terminal order (delivered / cancelled) can never be confirmed.
      final terminal = (await repo.list())
          .valueOrNull!
          .firstWhere((o) => o.status.isTerminal);
      final result = await repo.confirm(terminal.id);
      expect(result.isErr, isTrue);
    });

    test('a legal transition resolves Ok and stamps the timeline with '
        'clock.now()', () async {
      final fixed = DateTime.utc(2026, 5, 16, 12);
      final shipped = (await repo.list())
          .valueOrNull!
          .where((o) => o.status == OrderStatus.shipped)
          .toList();
      // Backend-agnostic guard: only assert when the implementation actually
      // seeds a shipped order.
      if (shipped.isEmpty) return;
      final before = shipped.first;
      final result = await withClock(
        Clock.fixed(fixed),
        () => repo.markDelivered(before.id),
      );
      final updated = result.valueOrNull;
      expect(updated, isNotNull);
      expect(updated!.status, OrderStatus.delivered);
      expect(updated.timeline.length, greaterThan(before.timeline.length));
      expect(updated.timeline.last.timestamp, fixed);
    });

    test('cancel() records the reason and resolves Ok', () async {
      final open = (await repo.list())
          .valueOrNull!
          .where((o) => !o.status.isTerminal)
          .toList();
      if (open.isEmpty) return;
      final result = await repo.cancel(open.first.id, reason: 'contract test');
      expect(result.valueOrNull?.status, OrderStatus.cancelled);
      expect(result.valueOrNull?.cancelReason, 'contract test');
    });
  });
}

// ─────────────────────────── ShopSettingsRepository ─────────────────────────

void shopSettingsRepositoryContract(
  String label,
  ShopSettingsRepository Function() build,
) {
  group('ShopSettingsRepository contract [$label]', () {
    late ShopSettingsRepository repo;
    setUp(() => repo = build());

    test('get() resolves Ok', () async {
      expect((await repo.get()).isOk, isTrue);
    });

    test('save() persists; the change is observable on the next get()',
        () async {
      final current = (await repo.get()).valueOrNull!;
      final saved =
          await repo.save(current.copyWith(contactPhone: '+998900000000'));
      expect(saved.valueOrNull?.contactPhone, '+998900000000');
      expect((await repo.get()).valueOrNull?.contactPhone, '+998900000000');
    });

    test('save() emits the new settings on watch()', () async {
      final current = (await repo.get()).valueOrNull!;
      final emitted = expectLater(
        repo.watch(),
        emits(
          predicate<ShopSettings>((s) => s.contactPhone == '+998911111111'),
        ),
      );
      await repo.save(current.copyWith(contactPhone: '+998911111111'));
      await emitted;
    });

    test('uploadAsset() resolves Ok with a path carrying kind + extension',
        () async {
      final file = _tempFile('contract_logo.png');
      addTearDown(() => _deleteIfExists(file));
      final result = await repo.uploadAsset(
        kind: 'logo',
        file: file,
        fileExtension: 'png',
      );
      expect(result.valueOrNull, contains('logo'));
      expect(result.valueOrNull, endsWith('.png'));
    });
  });
}

// ────────────────────────── SellerServicesRepository ────────────────────────

void sellerServicesRepositoryContract(
  String label,
  SellerServicesRepository Function() build,
) {
  group('SellerServicesRepository contract [$label]', () {
    late SellerServicesRepository repo;
    setUp(() => repo = build());

    test('list() resolves Ok with a non-empty default config', () async {
      final result = await repo.list();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNotEmpty);
    });

    test('save() round-trips the config and the change survives a reload',
        () async {
      final current = (await repo.list()).valueOrNull!;
      final toggled = [
        for (final config in current) config.copyWith(enabled: !config.enabled),
      ];
      expect((await repo.save(toggled)).isOk, isTrue);
      final reloaded = (await repo.list()).valueOrNull!;
      expect(
        reloaded.map((c) => c.enabled).toList(),
        toggled.map((c) => c.enabled).toList(),
      );
    });
  });
}

// ──────────────────────── SellerVerificationRepository ──────────────────────

void sellerVerificationRepositoryContract(
  String label,
  SellerVerificationRepository Function() build,
) {
  group('SellerVerificationRepository contract [$label]', () {
    late SellerVerificationRepository repo;
    setUp(() {
      // The mock is backed by a process-global state singleton — wipe it so
      // tests don't leak documents into each other.
      MockSellerState.instance.resetForTests();
      repo = build();
    });

    test('documents starts empty', () {
      expect(repo.documents, isEmpty);
    });

    test('uploadDocument() resolves Ok and the doc gains a remote path',
        () async {
      final file = _tempFile('contract_passport_front.jpg');
      addTearDown(() => _deleteIfExists(file));
      final result = await repo.uploadDocument(
        type: VerificationDocumentType.passportFront,
        file: file,
        fileExtension: 'jpg',
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.remoteUrl, isNotNull);
      expect(
        repo.documents.any(
          (d) => d.type == VerificationDocumentType.passportFront,
        ),
        isTrue,
      );
    });

    test('removeDocument() resolves Ok and drops the doc', () async {
      final file = _tempFile('contract_passport_back.jpg');
      addTearDown(() => _deleteIfExists(file));
      await repo.uploadDocument(
        type: VerificationDocumentType.passportBack,
        file: file,
        fileExtension: 'jpg',
      );
      final removed =
          await repo.removeDocument(VerificationDocumentType.passportBack);
      expect(removed.isOk, isTrue);
      expect(
        repo.documents.any(
          (d) => d.type == VerificationDocumentType.passportBack,
        ),
        isFalse,
      );
    });

    test('submit() resolves Ok with a pending status', () async {
      final result = await repo.submit();
      expect(result.valueOrNull, VerificationStatus.pending);
    });
  });
}

// ─────────────────────────────── TariffRepository ───────────────────────────

void tariffRepositoryContract(
  String label,
  TariffRepository Function() build,
) {
  group('TariffRepository contract [$label]', () {
    late TariffRepository repo;
    setUp(() {
      MockSellerState.instance.resetForTests();
      repo = build();
    });

    test('currentSnapshot() resolves Ok', () async {
      expect((await repo.currentSnapshot()).isOk, isTrue);
    });

    test('fetchPlans() resolves Ok with a non-empty catalog', () async {
      expect((await repo.fetchPlans()).valueOrNull, isNotEmpty);
    });

    test('currentPending() starts as Ok(null)', () async {
      final result = await repo.currentPending();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('history() resolves Ok', () async {
      expect((await repo.history()).isOk, isTrue);
    });

    test('paymentInstructions() resolves Ok with card details', () async {
      expect((await repo.paymentInstructions()).valueOrNull?.cardNumber,
          isNotEmpty);
    });

    test('upgrade() stamps submittedAt with clock.now() and becomes pending',
        () async {
      final fixed = DateTime.utc(2026, 5, 16, 9, 30);
      final input = TariffUpgradeInput(
        plan: TariffPlan.pro,
        period: BillingPeriod.monthly,
        amount: TariffPlan.pro.monthlyPriceUzs,
        paymentScreenshotUrl: 'payments/contract.jpg',
      );
      final result =
          await withClock(Clock.fixed(fixed), () => repo.upgrade(input));
      final sub = result.valueOrNull;
      expect(sub, isNotNull);
      expect(sub!.status, TariffUpgradeStatus.pending);
      expect(sub.submittedAt, fixed);
      // The pending request is now observable through currentPending().
      expect((await repo.currentPending()).valueOrNull?.id, sub.id);
      // Cancel so the mock's delayed admin-resolution timer becomes a no-op.
      await repo.cancelPending(sub.id);
    });

    test('a second upgrade while one is pending resolves Err', () async {
      final input = TariffUpgradeInput(
        plan: TariffPlan.basic,
        period: BillingPeriod.monthly,
        amount: TariffPlan.basic.monthlyPriceUzs,
        paymentScreenshotUrl: 'payments/contract.jpg',
      );
      final first = await repo.upgrade(input);
      expect(first.isOk, isTrue);
      expect((await repo.upgrade(input)).isErr, isTrue);
      await repo.cancelPending(first.valueOrNull!.id);
    });
  });
}

// ──────────────────────────────── helpers ───────────────────────────────────

File _tempFile(String name) =>
    File('${Directory.systemTemp.path}/$name')..writeAsBytesSync(const [1, 2, 3]);

void _deleteIfExists(File file) {
  if (file.existsSync()) file.deleteSync();
}
