import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/network/woody_api_client.dart';
import '../models/address.dart';
import '../models/dashboard_snapshot.dart';
import '../models/multilingual_text.dart';
import '../models/onboarding_draft.dart';
import '../models/order.dart' as order_models;
import '../models/order_status.dart';
import '../models/region.dart';
import '../models/shop.dart';
import '../models/tariff.dart';
import '../models/verification_status.dart';
import 'seller_dashboard_repository.dart';
import 'seller_onboarding_repository.dart';

/// REST-backed seller repositories that target the `/seller/*` endpoints on
/// api.woody.uz.
///
/// Phase 4b ships a subset: dashboard + onboarding. The remaining seller
/// surfaces (products CRUD, orders, analytics, reviews, services,
/// shop settings, tariff) continue to use their Supabase implementations
/// until Phase 8 completes the migration. The DI module switches each
/// surface independently via the `useWoody` flag.

class WoodySellerDashboardRepository implements SellerDashboardRepository {
  WoodySellerDashboardRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<DashboardSnapshot> snapshot() async {
    final body = await _api.get<Map<String, dynamic>>('/seller/dashboard');
    final kpis = body['kpis'] as Map<String, dynamic>? ?? const {};
    final recent = body['recent_orders'] as List<dynamic>? ?? const [];

    final activeProducts = (kpis['products_active'] as num?)?.toInt() ?? 0;
    return DashboardSnapshot(
      todaysOrders: (kpis['orders_today'] as num?)?.toInt() ?? 0,
      todaysRevenue: 0, // Backend doesn't yet break out today's revenue.
      pendingOrdersCount: (kpis['orders_pending'] as num?)?.toInt() ?? 0,
      activeProductsCount: activeProducts,
      tariff: TariffSnapshot(
        plan: TariffPlan.free,
        activeProductsCount: activeProducts,
      ),
      recentOrders: recent
          .whereType<Map<String, dynamic>>()
          .map(_toOrder)
          .toList(growable: false),
      last30Days: const [],
    );
  }

  @override
  Stream<order_models.Order> newOrders() {
    // Phase 6 wires WebSocket-backed new-order events. Until then emit a
    // closed stream so the seller dashboard renders the existing snapshot
    // without trying to subscribe.
    return const Stream.empty();
  }

  order_models.Order _toOrder(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final createdAt = DateTime.parse(row['created_at'] as String);
    final totalAmount = (row['total_amount'] as num?) ?? 0;
    return order_models.Order(
      id: id,
      orderNumber: 'WD-${id.substring(0, 8).toUpperCase()}',
      shop: const Shop(
        id: '_',
        slug: '_',
        name: MultilingualText(uz: "Do'kon", ru: 'Магазин', en: 'Shop'),
      ),
      items: const [],
      address: Address(
        id: 'addr-${id.substring(0, 8)}',
        label: 'Yetkazish manzili',
        recipientName: row['customer_name'] as String? ?? '',
        phone: row['customer_phone'] as String? ?? '',
        region: const Region(id: '_', code: '_', name: MultilingualText()),
        city: const Region(id: '_', code: '_', name: MultilingualText()),
        streetLine: row['delivery_address'] as String? ?? '',
      ),
      deliveryMethod: order_models.OrderDeliveryMethod.delivery,
      paymentMethod: order_models.OrderPaymentMethod.cashOnDelivery,
      status: OrderStatus.fromCode(row['status'] as String?),
      itemsTotal: totalAmount,
      deliveryFee: 0,
      servicesFee: 0,
      grandTotal: totalAmount,
      createdAt: createdAt,
      timeline: [
        order_models.OrderStatusEvent(
          status: OrderStatus.pending,
          timestamp: createdAt,
        ),
      ],
    );
  }
}

class WoodySellerOnboardingRepository implements SellerOnboardingRepository {
  WoodySellerOnboardingRepository({
    required WoodyApiClient api,
    required Box draftBox,
  })  : _api = api,
        _draftBox = draftBox;

  static const _draftKey = 'current_draft';
  final WoodyApiClient _api;
  final Box _draftBox;

  @override
  OnboardingDraft loadDraft() {
    final raw = _draftBox.get(_draftKey);
    if (raw is Map) {
      try {
        return OnboardingDraft.fromMap(raw);
      } catch (_) {
        // Corrupt draft — start fresh rather than crashing the wizard.
      }
    }
    return const OnboardingDraft();
  }

  @override
  Future<OnboardingDraft?> loadRemoteDraft() async {
    try {
      final body = await _api.get<Map<String, dynamic>>('/seller/me');
      final shopName = body['shop_name'] as String?;
      return const OnboardingDraft().copyWith(
        legalName: body['legal_name'] as String?,
        contactPhone: body['contact_phone'] as String?,
        contactEmail: body['contact_email'] as String?,
        telegramUsername: body['telegram_username'] as String?,
        shopNameUz: shopName,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    await _draftBox.put(_draftKey, draft.toJson());
  }

  @override
  Future<void> clearDraft() async {
    await _draftBox.delete(_draftKey);
  }

  @override
  Future<OnboardingSubmissionResult> submit(
    OnboardingDraft draft, {
    String? passportFrontPath,
    String? passportBackPath,
  }) async {
    final shopName =
        draft.shopNameUz ?? draft.shopNameRu ?? draft.shopNameEn ?? '';
    final shopDescription = draft.shopDescriptionUz ??
        draft.shopDescriptionRu ??
        draft.shopDescriptionEn;
    final body = await _api.post<Map<String, dynamic>>(
      '/seller/onboarding',
      body: {
        'business_type': draft.businessType?.code ?? 'individual',
        'legal_name': draft.legalName ?? '',
        'contact_phone': draft.contactPhone ?? '',
        if (draft.contactEmail != null) 'contact_email': draft.contactEmail,
        if (draft.telegramUsername != null)
          'telegram_username': draft.telegramUsername,
        'shop_name': shopName,
        if (shopDescription != null) 'shop_description': shopDescription,
        if (draft.shopStreetLine != null)
          'shop_address': draft.shopStreetLine,
        if (draft.shopLat != null) 'latitude': draft.shopLat,
        if (draft.shopLng != null) 'longitude': draft.shopLng,
      },
    );
    // Passport uploads ship as a separate step in Phase 7 once the R2
    // presigned PUT plumbing lands; for now they stay queued in the draft.
    return OnboardingSubmissionResult(
      sellerProfileId: body['seller_id'] as String,
      shopId: body['shop_id'] as String? ?? '',
      verificationStatus: VerificationStatus.fromCode(
        body['verification_status'] as String?,
      ),
    );
  }
}
