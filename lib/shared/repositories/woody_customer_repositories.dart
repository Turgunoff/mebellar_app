import 'dart:async';

import '../../core/error/failure.dart';
import '../../core/network/api_error.dart';
import '../../core/network/woody_api_client.dart';
import '../../core/result/result.dart';
import '../models/address.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/cart_item_model.dart';
import '../models/multilingual_text.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/product.dart';
import '../models/region.dart';
import '../models/review.dart';
import '../models/shop.dart';
import '../models/supabase_product_model.dart';
import 'cart_repository.dart';
import 'customer_reviews_repository.dart';
import 'favorites_repository.dart';
import 'order_repository.dart';

/// Bundled REST replacements for the Supabase customer-side repositories.
/// Each one implements its existing abstract contract; only the transport
/// flips. Kept in a single file so the migration commit is easy to scan.

// ─── Cart ──────────────────────────────────────────────────────────────────

class WoodyCartRepository implements CartRepository {
  WoodyCartRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;
  List<CartItemModel> _items = const [];
  Cart _legacyCart = const Cart();
  final _itemsController = StreamController<List<CartItemModel>>.broadcast();
  final _cartController = StreamController<Cart>.broadcast();

  void _setItems(List<CartItemModel> next) {
    _items = next;
    _legacyCart = Cart(items: next.map(_toCartItem).toList(growable: false));
    _itemsController.add(List<CartItemModel>.unmodifiable(_items));
    _cartController.add(_legacyCart);
  }

  CartItem _toCartItem(CartItemModel m) {
    return CartItem(
      id: m.id,
      product: Product(
        id: m.productId,
        slug: m.productId,
        name: MultilingualText(uz: m.productName),
        price: m.productPrice,
        primaryImage: m.productImage.isEmpty ? null : m.productImage,
        images: m.productImage.isEmpty ? const [] : [m.productImage],
      ),
      quantity: m.quantity,
    );
  }

  void clearCache() => _setItems(const []);

  @override
  Stream<List<CartItemModel>> watchItems() => _itemsController.stream;

  @override
  List<CartItemModel> get currentItems =>
      List<CartItemModel>.unmodifiable(_items);

  @override
  Future<List<CartItemModel>> fetchItems() async {
    try {
      final rows = await _api.get<List<dynamic>>('/cart/items');
      _setItems(
        rows
            .whereType<Map<String, dynamic>>()
            .map(CartItemModel.fromJson)
            .toList(growable: false),
      );
      return currentItems;
    } on ApiError catch (e) {
      if (e.isUnauthorized) {
        _setItems(const []);
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<void> addProduct(
    SupabaseProductModel product, {
    int quantity = 1,
    String? selectedColor,
  }) async {
    await _api.post<dynamic>(
      '/cart/items',
      body: {
        'product_id': product.id,
        'quantity': quantity.clamp(1, 99),
        if (selectedColor != null) 'selected_color': selectedColor,
      },
    );
    await fetchItems();
  }

  @override
  Future<void> updateProductQuantity(String productId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeProduct(productId);
      return;
    }
    await _api.patch<dynamic>(
      '/cart/items/$productId',
      body: {'quantity': newQuantity.clamp(1, 99)},
    );
    await fetchItems();
  }

  @override
  Future<void> removeProduct(String productId) async {
    await _api.delete<dynamic>('/cart/items/$productId');
    await fetchItems();
  }

  // ── Legacy [Cart] API ─────────────────────────────────────────────────────

  @override
  Stream<Cart> watch() => _cartController.stream;

  @override
  Cart get current => _legacyCart;

  @override
  Future<Cart> fetch() async {
    await fetchItems();
    return _legacyCart;
  }

  @override
  Future<Cart> addItem(String productId, {int quantity = 1}) async {
    await _api.post<dynamic>(
      '/cart/items',
      body: {'product_id': productId, 'quantity': quantity},
    );
    await fetchItems();
    return _legacyCart;
  }

  @override
  Future<Cart> updateQuantity(String itemId, int quantity) async {
    final match = _items.firstWhere(
      (it) => it.id == itemId,
      orElse: () => CartItemModel(
        id: itemId,
        productId: itemId,
        productName: '',
        productImage: '',
        productPrice: 0,
        quantity: 0,
      ),
    );
    await updateProductQuantity(match.productId, quantity);
    return _legacyCart;
  }

  @override
  Future<Cart> removeItem(String itemId) async {
    final match = _items.firstWhere(
      (it) => it.id == itemId,
      orElse: () => CartItemModel(
        id: itemId,
        productId: itemId,
        productName: '',
        productImage: '',
        productPrice: 0,
        quantity: 0,
      ),
    );
    await removeProduct(match.productId);
    return _legacyCart;
  }

  @override
  Future<Cart> clear() async {
    await _api.delete<dynamic>('/cart');
    _setItems(const []);
    return _legacyCart;
  }

  Future<void> dispose() async {
    await _itemsController.close();
    await _cartController.close();
  }
}

// ─── Favorites ─────────────────────────────────────────────────────────────

class WoodyFavoritesRepository implements FavoritesRepository {
  WoodyFavoritesRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;
  Set<String> _ids = {};
  final _controller = StreamController<Set<String>>.broadcast();

  void clearCache() {
    _ids = {};
    _controller.add(const <String>{});
  }

  @override
  Set<String> get currentIds => Set.unmodifiable(_ids);

  @override
  bool isFavorite(String productId) => _ids.contains(productId);

  @override
  Stream<Set<String>> watchIds() => _controller.stream;

  Map<String, dynamic> _snapshot(Product p) => {
        'id': p.id,
        'slug': p.slug,
        'name': p.name.toJson(),
        'price': p.price,
        'old_price': p.oldPrice,
        'images': p.images,
        'primary_image': p.primaryImage,
        'category_slug': p.categorySlug,
        'stock': p.stock,
        'is_favorite': true,
      };

  @override
  Future<List<Product>> list() async {
    try {
      final rows = await _api.get<List<dynamic>>('/favorites');
      final products = <Product>[];
      final ids = <String>{};
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = row['product_id'] as String?;
        if (id == null) continue;
        ids.add(id);
        final snap = row['product_snapshot'];
        if (snap is! Map<String, dynamic>) continue;
        try {
          products.add(Product.fromJson({...snap, 'is_favorite': true}));
        } catch (_) {
          // Corrupt snapshot — skip silently rather than blowing up the list.
        }
      }
      _ids = ids;
      _controller.add(Set.unmodifiable(_ids));
      return products;
    } on ApiError catch (e) {
      if (e.isUnauthorized) {
        clearCache();
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<void> toggle(Product product) async {
    if (_ids.contains(product.id)) {
      await remove(product.id);
    } else {
      await _api.post<dynamic>(
        '/favorites',
        body: {
          'product_id': product.id,
          'product_snapshot': _snapshot(product),
        },
      );
      _ids = {..._ids, product.id};
      _controller.add(Set.unmodifiable(_ids));
    }
  }

  @override
  Future<void> remove(String productId) async {
    await _api.delete<dynamic>('/favorites/$productId');
    _ids = Set.from(_ids)..remove(productId);
    _controller.add(Set.unmodifiable(_ids));
  }
}

// ─── Orders ────────────────────────────────────────────────────────────────

class WoodyOrderRepository implements OrderRepository {
  WoodyOrderRepository(this._api);

  final WoodyApiClient _api;

  @override
  Future<List<Order>> list() async {
    final body = await _api.get<Map<String, dynamic>>('/orders');
    final rows = body['rows'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_rowToOrder)
        .toList(growable: false);
  }

  @override
  Future<Order> getById(String id) async {
    final row = await _api.get<Map<String, dynamic>>('/orders/$id');
    return _rowToOrder(row);
  }

  @override
  Future<Order> create(CreateOrderInput input) async {
    final itemsTotal = input.items.fold<num>(
      0,
      (s, it) => s + it.product.price * it.quantity,
    );
    final deliveryFee = _deliveryFee(input.deliveryMethod);
    final body = await _api.post<Map<String, dynamic>>(
      '/orders',
      body: {
        'items': [
          for (final it in input.items)
            {
              'product_id': it.product.id,
              'quantity': it.quantity,
              'price': it.product.price,
            }
        ],
        'delivery_address': input.address.formatted('uz'),
      },
    );
    final created = _rowToOrder(body);
    // Replace the synthesised totals with the inputs the user actually
    // committed, since the backend doesn't yet round-trip delivery fees.
    return Order(
      id: created.id,
      orderNumber: created.orderNumber,
      shop: input.shop,
      items: input.items
          .map((it) => OrderItem(
                productId: it.product.id,
                productSlug: it.product.slug,
                productName: it.product.name,
                thumbnail: it.product.heroImage,
                unitPrice: it.product.price,
                quantity: it.quantity,
              ))
          .toList(),
      address: input.address,
      deliveryMethod: input.deliveryMethod,
      paymentMethod: input.paymentMethod,
      status: created.status,
      itemsTotal: itemsTotal,
      deliveryFee: deliveryFee,
      servicesFee: 0,
      grandTotal: itemsTotal + deliveryFee,
      createdAt: created.createdAt,
      expectedDeliveryAt: input.deliveryMethod == OrderDeliveryMethod.pickup
          ? null
          : created.createdAt.add(const Duration(days: 3)),
      timeline: [
        OrderStatusEvent(
          status: OrderStatus.pending,
          timestamp: created.createdAt,
        ),
      ],
    );
  }

  @override
  Future<Order> cancel(String id, {required String reason}) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/orders/$id/cancel',
      body: {'reason': reason},
    );
    return _rowToOrder(body);
  }

  @override
  Future<Order> approveFeeAdjustment(String id) async {
    // Backend doesn't expose fee adjustment yet — return the latest order
    // unchanged so the UI stops spinning. Phase 4 wires the real endpoint.
    return getById(id);
  }

  @override
  Future<Order> rejectFeeAdjustment(String id) async {
    return getById(id);
  }

  @override
  Stream<Order> watch(String orderId) {
    // Realtime arrives in Phase 6. Until then poll once when subscribed
    // and emit that snapshot — the cubit treats a single event as still
    // "connected" and renders the order normally.
    return Stream<Order>.fromFuture(getById(orderId));
  }

  // ─── Mapping helpers ───────────────────────────────────────────────────────

  Order _rowToOrder(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final status = OrderStatus.fromCode(row['status'] as String?);
    final createdAt = DateTime.parse(row['created_at'] as String);
    final totalAmount = (row['total_amount'] as num?) ?? 0;

    final itemRows = (row['items'] as List<dynamic>?) ?? const [];
    final items = itemRows.map<OrderItem>(_rowToOrderItem).toList();
    final itemsTotal = items.fold<num>(0, (s, it) => s + it.lineTotal);
    final deliveryFee =
        totalAmount > itemsTotal ? totalAmount - itemsTotal : 0;

    return Order(
      id: id,
      orderNumber: _orderNumber(id),
      shop: _unknownShop,
      items: items,
      address: _addressFromText(row['delivery_address'] as String?, id),
      deliveryMethod: OrderDeliveryMethod.delivery,
      paymentMethod: OrderPaymentMethod.cashOnDelivery,
      status: status,
      itemsTotal: itemsTotal,
      deliveryFee: deliveryFee,
      servicesFee: 0,
      grandTotal: totalAmount,
      createdAt: createdAt,
      timeline: _syntheticTimeline(status, createdAt),
      cancelReason: row['cancellation_reason'] as String?,
      proposedDeliveryFee: row['proposed_delivery_fee'] as num?,
      feeAdjustmentStatus: FeeAdjustmentStatus.fromCode(
        row['fee_adjustment_status'] as String?,
      ),
    );
  }

  static OrderItem _rowToOrderItem(dynamic raw) {
    final row = raw as Map<String, dynamic>;
    final product = row['product'] as Map<String, dynamic>?;
    final rawName = product?['name'];
    final name = rawName is String ? rawName : '';
    final images = product?['images'] as List<dynamic>? ?? const [];
    return OrderItem(
      id: row['id'] as String?,
      productId: row['product_id'] as String,
      productSlug: row['product_id'] as String,
      productName: MultilingualText(uz: name, ru: name, en: name),
      thumbnail: images.isNotEmpty ? images.first as String : '',
      unitPrice: (row['price'] as num?) ?? 0,
      quantity: (row['quantity'] as int?) ?? 1,
      colorSlug: row['color_slug'] as String? ?? '',
    );
  }

  static String _orderNumber(String id) =>
      'WD-${id.substring(0, 8).toUpperCase()}';

  static num _deliveryFee(OrderDeliveryMethod method) => switch (method) {
        OrderDeliveryMethod.pickup => 0,
        OrderDeliveryMethod.expressDelivery => 80000,
        OrderDeliveryMethod.delivery => 50000,
      };

  static Address _addressFromText(String? text, String orderId) => Address(
        id: 'addr-${orderId.substring(0, 8)}',
        label: 'Yetkazish manzili',
        recipientName: '',
        phone: '',
        region: _blankRegion,
        city: _blankRegion,
        streetLine: text ?? '',
      );

  static List<OrderStatusEvent> _syntheticTimeline(
    OrderStatus status,
    DateTime createdAt,
  ) {
    final events = [
      OrderStatusEvent(status: OrderStatus.pending, timestamp: createdAt),
    ];
    if (status == OrderStatus.pending) return events;
    if (status == OrderStatus.cancelled) {
      return [
        ...events,
        OrderStatusEvent(
          status: OrderStatus.cancelled,
          timestamp: createdAt.add(const Duration(hours: 1)),
        ),
      ];
    }
    const progression = [
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.shipped,
      OrderStatus.delivered,
    ];
    var t = createdAt;
    for (final s in progression) {
      t = t.add(const Duration(hours: 2));
      events.add(OrderStatusEvent(status: s, timestamp: t));
      if (s == status) break;
    }
    return events;
  }
}

const _blankRegion = Region(id: '_', code: '_', name: MultilingualText());

const _unknownShop = Shop(
  id: '_',
  slug: '_',
  name: MultilingualText(uz: "Do'kon", ru: 'Магазин', en: 'Shop'),
);

// ─── Reviews ───────────────────────────────────────────────────────────────

class WoodyCustomerReviewsRepository implements CustomerReviewsRepository {
  WoodyCustomerReviewsRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<Result<Map<String, Review>>> reviewsForOrder(String orderId) =>
      runCatching(() async {
        // Backend doesn't yet expose a "my reviews for order X" view. We rebuild
        // it client-side by listing reviews for each product in the order and
        // filtering by the caller; for now return empty — the order detail
        // screen will show the "leave a review" CTA on every line, and an
        // already-reviewed product will 409 on submit.
        return <String, Review>{};
      });

  @override
  Future<Result<Review>> submitReview({
    required String orderItemId,
    required String orderId,
    required String productId,
    required int rating,
    String? comment,
  }) =>
      runCatching(() async {
        final body = await _api.post<Map<String, dynamic>>(
          '/reviews',
          body: {
            'order_item_id': orderItemId,
            'rating': rating,
            if (comment != null && comment.trim().isNotEmpty)
              'comment': comment.trim(),
          },
        );
        return Review.fromRow(body);
      });

  @override
  Future<Result<Review>> updateReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) =>
      runCatching(() async {
        // Backend doesn't expose review edits yet — surface a clear failure
        // so the UI can show "feature unavailable" rather than silently
        // hanging.
        throw const ServerFailure(
          message: 'Sharhlarni tahrirlash hozircha qo\'llab-quvvatlanmaydi',
        );
      });

  @override
  Future<Result<ProductReviewSummary>> reviewsForProduct(String productId) =>
      runCatching(() async {
        final rows = await _api.get<List<dynamic>>(
          '/reviews',
          query: {'product_id': productId, 'limit': 50},
        );
        final reviews = rows
            .whereType<Map<String, dynamic>>()
            .map(Review.fromRow)
            .toList(growable: false);
        if (reviews.isEmpty) return ProductReviewSummary.empty;
        final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
        return ProductReviewSummary(
          average: total / reviews.length,
          count: reviews.length,
          reviews: reviews,
        );
      });
}
