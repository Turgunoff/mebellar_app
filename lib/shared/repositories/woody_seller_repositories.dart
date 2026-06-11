import 'dart:async';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/error/failure.dart';
import '../../core/logging/talker.dart';
import '../../core/network/woody_api_client.dart';
import '../../core/result/result.dart';
import '../../core/storage/r2_upload_client.dart';
import '../models/address.dart';
import '../models/analytics.dart';
import '../models/dashboard_snapshot.dart';
import '../models/multilingual_text.dart';
import '../models/onboarding_draft.dart';
import '../models/order.dart' as order_models;
import '../models/order_status.dart';
import '../models/region.dart';
import '../models/review.dart';
import '../models/seller_wallet.dart';
import '../models/shop.dart';
import '../models/shop_settings.dart';
import '../models/tariff.dart';
import '../models/verification_document.dart';
import '../models/verification_status.dart';
import 'seller_analytics_repository.dart';
import 'seller_dashboard_repository.dart';
import 'seller_onboarding_repository.dart';
import 'seller_reviews_repository.dart';
import 'seller_verification_repository.dart';
import 'shop_settings_repository.dart';

/// REST-backed seller repositories that target the `/seller/*` endpoints on
/// api.woody.uz.
///
/// Phase 4b ships a subset: dashboard + onboarding. The remaining seller
/// surfaces (products CRUD, orders, analytics, reviews, services,
/// shop settings, tariff) are also Woody-backed
/// until Phase 8 completes the migration. The DI module switches each
/// surface independently via the `useWoody` flag.

class WoodySellerDashboardRepository implements SellerDashboardRepository {
  WoodySellerDashboardRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<DashboardSnapshot> snapshot() async {
    // One optimised call: KPIs (incl. today's revenue), the seller's plan, the
    // 7-day sparkline + deltas, top products, achievements and the leaderboard
    // all ride in the single /seller/dashboard payload.
    final body = await _api.get<Map<String, dynamic>>(
      '/seller/dashboard',
      retries: 2,
    );
    final kpis = body['kpis'] as Map<String, dynamic>? ?? const {};
    final recent = body['recent_orders'] as List<dynamic>? ?? const [];
    final tariffBody = body['tariff'] as Map<String, dynamic>?;

    final activeProducts = (kpis['products_active'] as num?)?.toInt() ?? 0;
    return DashboardSnapshot(
      todaysOrders: (kpis['orders_today'] as num?)?.toInt() ?? 0,
      todaysRevenue: (kpis['revenue_today'] as num?) ?? 0,
      pendingOrdersCount: (kpis['orders_pending'] as num?)?.toInt() ?? 0,
      activeProductsCount: activeProducts,
      tariff: TariffSnapshot(
        plan: TariffPlan.fromCode(tariffBody?['plan_code'] as String?),
        activeProductsCount:
            (tariffBody?['active_products_count'] as num?)?.toInt() ??
            activeProducts,
        startedAt: _parseDate(tariffBody?['started_at']),
        expiresAt: _parseDate(tariffBody?['expires_at']),
      ),
      recentOrders: recent
          .whereType<Map<String, dynamic>>()
          .map(_toOrder)
          .toList(growable: false),
      last30Days: const [],
      weekly: WeeklySales.fromJson(
        body['weekly_sales'] as Map<String, dynamic>? ?? const {},
      ),
      kpiDeltas: KpiDeltas.fromJson(
        body['kpi_deltas'] as Map<String, dynamic>? ?? const {},
      ),
      achievements: ((body['achievements'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AchievementProgress.fromJson)
          .toList(growable: false),
      leaderboard: ((body['leaderboard'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LeaderboardStanding.fromJson)
          .toList(growable: false),
      topProducts: ((body['top_products'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TopProductStat.fromJson)
          .toList(growable: false),
      wallet: body['wallet'] is Map<String, dynamic>
          ? SellerWallet.fromJson(body['wallet'] as Map<String, dynamic>)
          : null,
    );
  }

  static DateTime? _parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  @override
  Future<({String? sellerName, String? shopName})> identity() async {
    final body = await _api.get<Map<String, dynamic>>('/seller/me');
    String? clean(Object? v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return (
      sellerName: clean(body['legal_name']),
      shopName: clean(body['shop_name']),
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
    required R2UploadClient uploads,
  }) : _api = api,
       _draftBox = draftBox,
       _uploads = uploads;

  static const _draftKey = 'current_draft';
  final WoodyApiClient _api;
  final Box _draftBox;
  final R2UploadClient _uploads;

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
    final shopDescription =
        draft.shopDescriptionUz ??
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
        if (draft.shopStreetLine != null) 'shop_address': draft.shopStreetLine,
        if (draft.shopLat != null) 'latitude': draft.shopLat,
        if (draft.shopLng != null) 'longitude': draft.shopLng,
      },
    );
    final sellerId = body['seller_id'] as String;
    // The onboarding POST creates the seller + shop; bucket-access gating on
    // /storage/upload-url requires that shop to exist, so passports upload
    // only after it returns. Docs go to the private `verification-docs` bucket
    // and are registered via POST /seller/verification/documents — the same
    // pair the standalone verification screen uses.
    //
    // Each submit gets its own folder (`attempt`) so a resubmit-after-rejection
    // doesn't overwrite the prior attempt's images — the backend keeps a
    // per-attempt history and the admin can review what was sent each time.
    final attempt = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    await _uploadPassport(
      sellerId,
      attempt,
      'passport_front',
      passportFrontPath,
    );
    await _uploadPassport(sellerId, attempt, 'passport_back', passportBackPath);
    return OnboardingSubmissionResult(
      sellerProfileId: sellerId,
      shopId: body['shop_id'] as String? ?? '',
      verificationStatus: VerificationStatus.fromCode(
        body['verification_status'] as String?,
      ),
    );
  }

  Future<void> _uploadPassport(
    String sellerId,
    String attempt,
    String documentType,
    String? localPath,
  ) async {
    if (localPath == null) return;
    // Compress to WebP (~88% quality) before upload — keeps passport text
    // legible while cutting the payload, and the admin renders WebP natively.
    final compressed = await FlutterImageCompress.compressWithFile(
      File(localPath).absolute.path,
      format: CompressFormat.webp,
      quality: 88,
      keepExif: false,
      minWidth: 1600,
      minHeight: 1600,
    );
    final bytes = compressed ?? await File(localPath).readAsBytes();
    final path = '$sellerId/$attempt/$documentType.webp';
    await _uploads.upload(
      bucket: R2Bucket.verificationDocs,
      path: path,
      bytes: bytes,
      contentType: 'image/webp',
    );
    await _api.post<dynamic>(
      '/seller/verification/documents',
      body: {'document_type': documentType, 'storage_path': path},
    );
  }
}

/// REST-backed seller reviews — `GET /seller/reviews` + `POST
/// /seller/reviews/{id}/reply`. The backend returns flat rows (no PostgREST
/// embeds), so we map them directly rather than via [Review.fromRow].
class WoodySellerReviewsRepository implements SellerReviewsRepository {
  WoodySellerReviewsRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<Result<List<Review>>> fetchReviews() => runCatching(() async {
    final rows = await _api.get<List<dynamic>>('/seller/reviews');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_toReview)
        .toList(growable: false);
  });

  @override
  Future<Result<Review>> postReply({
    required String reviewId,
    required String reply,
  }) => runCatching(() async {
    final trimmed = reply.trim();
    if (trimmed.isEmpty) {
      throw const ServerFailure(
        message: "Javob matni bo'sh bo'lishi mumkin emas",
      );
    }
    await _api.post<dynamic>(
      '/seller/reviews/$reviewId/reply',
      body: {'reply': trimmed},
    );
    // The reply endpoint returns 204, so re-read the list and surface the
    // updated row. A shop's review list is small, so this is cheap.
    final rows = await _api.get<List<dynamic>>('/seller/reviews');
    final updated = rows.whereType<Map<String, dynamic>>().firstWhere(
      (r) => r['id'] == reviewId,
      orElse: () => const <String, dynamic>{},
    );
    if (updated.isEmpty) {
      throw const ServerFailure(message: 'Sharh topilmadi');
    }
    return _toReview(updated);
  });

  Review _toReview(Map<String, dynamic> r) {
    final repliedAt = r['seller_replied_at'] as String?;
    final customer = (r['customer_name'] as String?)?.trim();
    return Review(
      id: r['id'] as String,
      productId: r['product_id'] as String,
      productName: (r['product_name'] as String?) ?? '',
      productImage: '',
      customerName: (customer != null && customer.isNotEmpty)
          ? customer
          : 'Mijoz',
      rating: (r['rating'] as num).toInt(),
      comment: (r['comment'] as String?) ?? '',
      createdAt: DateTime.parse(r['created_at'] as String),
      sellerReply: r['seller_reply'] as String?,
      sellerRepliedAt: repliedAt != null ? DateTime.parse(repliedAt) : null,
    );
  }
}

/// REST-backed seller KYC. Documents upload to the private `verification-docs`
/// R2 bucket (presigned PUT), then their path is registered via `POST
/// /seller/verification/documents`. The authoritative status is read from
/// `GET /seller/me`. The backend has no per-doc GET/DELETE yet, so the document
/// set is tracked in-memory for the current session.
class WoodySellerVerificationRepository
    implements SellerVerificationRepository {
  WoodySellerVerificationRepository({
    required WoodyApiClient api,
    required AuthRepository auth,
    required R2UploadClient uploads,
  }) : _api = api,
       _auth = auth,
       _uploads = uploads {
    unawaited(_loadStatus());
  }

  final WoodyApiClient _api;
  final AuthRepository _auth;
  final R2UploadClient _uploads;

  List<VerificationDocument> _cache = const [];
  final _docsController =
      StreamController<List<VerificationDocument>>.broadcast();
  final _statusController = StreamController<VerificationStatus>.broadcast();

  @override
  List<VerificationDocument> get documents => _cache;

  @override
  Stream<List<VerificationDocument>> watchDocuments() => _docsController.stream;

  @override
  Stream<VerificationStatus> watchStatus() => _statusController.stream;

  @override
  Future<Result<VerificationDocument>> uploadDocument({
    required VerificationDocumentType type,
    required File file,
    required String fileExtension,
  }) => runCatching(() async {
    final userId = _auth.currentUserId;
    if (userId == null) {
      throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
    }
    // Scope the key under the seller's id, matching the bucket's
    // per-user storage policy.
    final path = '$userId/${type.code}.$fileExtension';
    final bytes = await file.readAsBytes();
    await _uploads.upload(
      bucket: R2Bucket.verificationDocs,
      path: path,
      bytes: bytes,
      contentType: _contentType(fileExtension),
    );
    await _api.post<dynamic>(
      '/seller/verification/documents',
      body: {'document_type': type.code, 'storage_path': path},
    );
    final doc = VerificationDocument(
      type: type,
      localPath: file.path,
      remoteUrl: path,
    );
    _upsertCacheDoc(doc);
    return doc;
  });

  @override
  Future<Result<void>> removeDocument(VerificationDocumentType type) =>
      runCatching(() async {
        // No per-document delete endpoint yet — drop it from the local set so
        // the UI updates. Re-uploading the same type overwrites server-side.
        _cache = [
          for (final d in _cache)
            if (d.type != type) d,
        ];
        _emitDocs();
      });

  @override
  Future<Result<VerificationStatus>> submit() => runCatching(() async {
    // Documents are recorded as they upload; submitting just reflects the
    // pending state locally. /seller/me stays the source of truth.
    if (!_statusController.isClosed) {
      _statusController.add(VerificationStatus.pending);
    }
    return VerificationStatus.pending;
  });

  Future<void> _loadStatus() async {
    try {
      final body = await _api.get<Map<String, dynamic>>('/seller/me');
      if (!_statusController.isClosed) {
        _statusController.add(
          VerificationStatus.fromCode(body['verification_status'] as String?),
        );
      }
    } catch (_) {
      // No seller profile yet (pre-onboarding) — leave the stream idle.
    }
  }

  void _upsertCacheDoc(VerificationDocument doc) {
    _cache = [
      for (final d in _cache)
        if (d.type != doc.type) d,
      doc,
    ];
    _emitDocs();
  }

  void _emitDocs() {
    if (!_docsController.isClosed) _docsController.add(_cache);
  }

  String _contentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }
}

/// REST-backed shop settings — shop columns via `GET/PATCH /seller/shop`,
/// contact channels read from `GET /seller/me`. Logo/cover assets upload to the
/// public `shop-assets` R2 bucket. Editing seller contact channels isn't wired
/// to a settings endpoint yet (they're captured during onboarding).
class WoodyShopSettingsRepository implements ShopSettingsRepository {
  WoodyShopSettingsRepository({
    required WoodyApiClient api,
    required R2UploadClient uploads,
  }) : _api = api,
       _uploads = uploads;

  final WoodyApiClient _api;
  final R2UploadClient _uploads;

  @override
  Stream<ShopSettings> watch() => const Stream.empty();

  @override
  Future<Result<ShopSettings>> get() => runCatching(() async {
    final shop = await _api.get<Map<String, dynamic>>('/seller/shop');
    return ShopSettings.fromRow(
      shopRow: shop,
      sellerRow: await _contactSlice(),
    );
  });

  @override
  Future<Result<ShopSettings>> save(ShopSettings settings) =>
      runCatching(() async {
        // PATCH accepts shop columns only (ShopUpdateBody); contact channels
        // live on the seller row and aren't editable through this endpoint yet.
        final payload = settings.toShopJson();
        talker.info('[shop-settings] PATCH /seller/shop → request: $payload');
        final shop = await _api.patch<Map<String, dynamic>>(
          '/seller/shop',
          body: payload,
        );
        talker.info('[shop-settings] PATCH /seller/shop ← response: $shop');
        return ShopSettings.fromRow(
          shopRow: shop,
          sellerRow: await _contactSlice(),
        );
      });

  @override
  Future<Result<String>> uploadAsset({
    required String kind,
    required File file,
    required String fileExtension,
  }) => runCatching(() async {
    final shop = await _api.get<Map<String, dynamic>>('/seller/shop');
    final shopId = shop['id'] as String?;
    if (shopId == null) {
      throw const ServerFailure(message: "Do'kon topilmadi");
    }
    final ext = fileExtension.toLowerCase();
    final path = '$shopId/$kind-${DateTime.now().millisecondsSinceEpoch}.$ext';
    final result = await _uploads.upload(
      bucket: R2Bucket.shopAssets,
      path: path,
      bytes: await file.readAsBytes(),
      contentType: _shopAssetContentType(ext),
    );
    final url = result.publicUrl;
    if (url == null || url.isEmpty) {
      throw const ServerFailure(message: 'Rasm manzili olinmadi');
    }
    return url;
  });

  Future<Map<String, dynamic>> _contactSlice() async {
    final me = await _api.get<Map<String, dynamic>>('/seller/me');
    return {
      'contact_phone': me['contact_phone'],
      'contact_email': me['contact_email'],
      'telegram_username': me['telegram_username'],
    };
  }

  String _shopAssetContentType(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}

/// REST-backed seller analytics — `GET /seller/analytics?granularity&days`.
/// The backend returns a single revenue/orders time series (no per-product,
/// per-category, customer or review breakdowns yet), so this maps the series +
/// derived totals and leaves the richer breakdowns empty. Enriching the
/// backend response is a follow-up; the screen degrades to the trend + totals.
class WoodySellerAnalyticsRepository implements SellerAnalyticsRepository {
  WoodySellerAnalyticsRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<Result<AnalyticsSnapshot>> snapshot(
    AnalyticsFilter filter, {
    DateTime? now,
  }) => runCatching(() async {
    final clock = now ?? DateTime.now();
    final days = filter.range.days ?? 30;
    final granularity = filter.granularityFor(clock) == BucketGranularity.month
        ? 'month'
        : 'day';
    final body = await _api.get<Map<String, dynamic>>(
      '/seller/analytics',
      query: {'granularity': granularity, 'days': days},
    );
    final points = (body['points'] as List?) ?? const [];
    if (points.isEmpty) return AnalyticsSnapshot.empty(filter);

    final revenueSeries = <RevenuePoint>[];
    final ordersSeries = <OrdersPoint>[];
    num totalRevenue = 0;
    var ordersCount = 0;
    for (final raw in points) {
      if (raw is! Map<String, dynamic>) continue;
      final bucket = DateTime.parse(raw['bucket'] as String).toUtc();
      final revenue = (raw['revenue'] as num?) ?? 0;
      final orders = ((raw['orders'] as num?) ?? 0).toInt();
      revenueSeries.add(RevenuePoint(bucketStart: bucket, revenue: revenue));
      ordersSeries.add(OrdersPoint(bucketStart: bucket, count: orders));
      totalRevenue += revenue;
      ordersCount += orders;
    }

    return AnalyticsSnapshot(
      filter: filter,
      totalRevenue: totalRevenue,
      previousRevenue: 0,
      ordersCount: ordersCount,
      unitsSold: 0,
      avgOrderValue: ordersCount == 0 ? 0 : totalRevenue / ordersCount,
      series: revenueSeries,
      topProducts: const [],
      categoryBreakdown: const [],
      orders: OrdersBreakdown(
        total: ordersCount,
        previousTotal: 0,
        byStatus: const [],
        series: ordersSeries,
        deliveredCount: 0,
        cancelledCount: 0,
        activeCount: ordersCount,
      ),
      reviews: ReviewsBreakdown.empty(),
      customers: CustomersBreakdown.empty(),
    );
  });
}
