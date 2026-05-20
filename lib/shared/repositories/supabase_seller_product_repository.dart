import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/talker.dart';
import '../models/multilingual_text.dart';
import '../models/paginated.dart';
import '../models/seller_product.dart';
import 'seller_product_repository.dart';

/// Live Supabase-backed seller product repository.
///
/// Reads from `public.products` filtered by `seller_id = auth.uid()`. Variants
/// (for the SKU) and images (for the hero thumbnail) are joined via PostgREST
/// embed so the listing is a single round-trip.
///
/// The seller schema does not track stock (furniture is made-to-order), and a
/// product moves straight to `pending_review` on first submit — there is no
/// draft state in the database.
class SupabaseSellerProductRepository implements SellerProductRepository {
  SupabaseSellerProductRepository({required SupabaseClient supabase})
      : _client = supabase;

  final SupabaseClient _client;
  final _controller = StreamController<List<SellerProduct>>.broadcast();

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Stream<List<SellerProduct>> watch() => _controller.stream;

  @override
  Future<Paginated<SellerProduct>> list({
    SellerProductFilter filter = const SellerProductFilter(),
    int page = 1,
    int perPage = 20,
  }) async {
    final userId = _userId;
    if (userId == null) {
      talker.warning('[seller-products] list aborted — no auth.uid');
      return Paginated(
        items: const [],
        page: page,
        perPage: perPage,
        total: 0,
        hasNext: false,
      );
    }

    talker.info(
      '[seller-products] list start sellerId=$userId '
      'page=$page perPage=$perPage '
      'statuses=${filter.statuses.map((s) => s.code).toList()} '
      'search=${filter.search ?? ""}',
    );

    try {
      // Embed product_images (for hero) and product_variants (for SKU). The
      // grid currently shows one variant per product, so pulling the array
      // and picking the first row is cheap.
      final from = (page - 1) * perPage;
      final to = from + perPage - 1;

      var query = _client
          .from('products')
          .select(
            'id, name, description, category_id, subcategory_id, price, status, '
            'created_at, updated_at, attributes, '
            'colors, width_cm, height_cm, depth_cm, '
            'production_time_days, has_delivery, delivery_price, '
            'has_installation, installation_price, warranty_months, '
            'images, '
            'category:categories(id, name, name_uz), '
            'product_images:product_images(id, image_url, is_main, sort_order), '
            'product_variants:product_variants(sku, color_name, price, discount_price)',
          )
          .eq('seller_id', userId);

      if (filter.statuses.isNotEmpty) {
        query = query.inFilter(
          'status',
          filter.statuses.map((s) => s.code).toList(),
        );
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(from, to);

      final items = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(_fromRow)
          .toList(growable: false);

      _controller.add(items);

      talker.info(
        '[seller-products] list ok sellerId=$userId returned=${items.length}',
      );
      return Paginated(
        items: items,
        page: page,
        perPage: perPage,
        total: items.length,
        hasNext: items.length >= perPage,
      );
    } catch (e, st) {
      talker.handle(e, st, '[seller-products] list failed sellerId=$userId');
      rethrow;
    }
  }

  @override
  Future<SellerProduct> getById(String id) =>
      throw UnimplementedError('Supabase seller products — getById');

  @override
  Future<SellerProduct> create(SellerProductInput input) =>
      throw UnimplementedError('Supabase seller products — create');

  @override
  Future<SellerProduct> update(String id, SellerProductInput input) =>
      throw UnimplementedError('Supabase seller products — update');

  @override
  Future<SellerProduct> archive(String id) =>
      throw UnimplementedError('Supabase seller products — archive');

  @override
  Future<SellerProduct> submitForReview(String id) =>
      throw UnimplementedError('Supabase seller products — submitForReview');

  @override
  Future<SellerProductImage> uploadImage({
    required String productId,
    required File file,
    required String fileExtension,
  }) =>
      throw UnimplementedError('Supabase seller products — uploadImage');

  @override
  Future<void> deleteImage({
    required String productId,
    required String imageId,
  }) =>
      throw UnimplementedError('Supabase seller products — deleteImage');

  @override
  Future<SellerProduct> reorderImages({
    required String productId,
    required List<String> imageIdsInOrder,
  }) =>
      throw UnimplementedError('Supabase seller products — reorderImages');

  @override
  Future<SellerProduct> setPrimaryImage({
    required String productId,
    required String imageId,
  }) =>
      throw UnimplementedError('Supabase seller products — setPrimaryImage');

  /// Builds a [SellerProduct] from a Supabase row. Tolerant of partial joins:
  /// when `product_images` / `product_variants` come back empty, falls back
  /// to the legacy `products.images` text[] column and the row's own price.
  SellerProduct _fromRow(Map<String, dynamic> row) {
    final name = (row['name'] as String?) ?? '';
    final description = (row['description'] as String?) ?? '';
    final status = SellerProductStatus.fromCode(row['status'] as String?);
    final created = DateTime.tryParse(row['created_at'] as String? ?? '') ??
        DateTime.now();
    final updated = DateTime.tryParse(row['updated_at'] as String? ?? '') ??
        created;

    final images = _imagesFromRow(row);
    final variant = _firstVariant(row);
    final categoryName = _categoryName(row);
    final colors = _colorsFromRow(row);

    return SellerProduct(
      id: row['id'] as String,
      name: MultilingualText(uz: name),
      description: MultilingualText(uz: description),
      categorySlug: row['category_id'] as String? ?? '',
      categoryName: categoryName,
      subcategoryId: row['subcategory_id'] as String?,
      colors: colors,
      price: (row['price'] as num?) ?? 0,
      discountPrice: (variant?['discount_price'] as num?),
      sku: (variant?['sku'] as String?) ?? '',
      images: images,
      primaryImageId: images.isEmpty ? null : images.first.id,
      attributes: row['attributes'] is Map<String, dynamic>
          ? row['attributes'] as Map<String, dynamic>
          : const {},
      widthCm: (row['width_cm'] as num?),
      heightCm: (row['height_cm'] as num?),
      lengthCm: (row['depth_cm'] as num?),
      productionTimeDays: row['production_time_days'] as String?,
      hasDelivery: row['has_delivery'] as bool? ?? false,
      deliveryPrice: (row['delivery_price'] as num?) ?? 0,
      hasInstallation: row['has_installation'] as bool? ?? false,
      installationPrice: (row['installation_price'] as num?) ?? 0,
      warrantyMonths: (row['warranty_months'] as num?)?.toInt() ?? 0,
      status: status,
      createdAt: created,
      updatedAt: updated,
    );
  }

  String? _categoryName(Map<String, dynamic> row) {
    final cat = row['category'];
    if (cat is Map<String, dynamic>) {
      final uz = cat['name_uz'] as String?;
      if (uz != null && uz.isNotEmpty) return uz;
      return cat['name'] as String?;
    }
    return null;
  }

  List<String> _colorsFromRow(Map<String, dynamic> row) {
    final raw = row['colors'];
    if (raw is List) {
      return [
        for (final v in raw)
          if (v is String && v.isNotEmpty) v,
      ];
    }
    return const [];
  }

  List<SellerProductImage> _imagesFromRow(Map<String, dynamic> row) {
    final embedded = row['product_images'];
    if (embedded is List && embedded.isNotEmpty) {
      final mapped = embedded
          .whereType<Map<String, dynamic>>()
          .map((m) => SellerProductImage(
                id: m['id'] as String,
                remoteUrl: m['image_url'] as String?,
              ))
          .toList()
        ..sort((a, b) {
          // No sort_order on the model — match insertion order by URL hash so
          // the hero stays stable across refreshes.
          return (a.remoteUrl ?? '').compareTo(b.remoteUrl ?? '');
        });
      return mapped;
    }
    // Fallback to legacy text[] column used before product_images existed.
    final raw = row['images'];
    if (raw is List) {
      return [
        for (var i = 0; i < raw.length; i++)
          SellerProductImage(
            id: 'legacy-$i',
            remoteUrl: raw[i] is String ? raw[i] as String : null,
          ),
      ];
    }
    return const [];
  }

  Map<String, dynamic>? _firstVariant(Map<String, dynamic> row) {
    final variants = row['product_variants'];
    if (variants is List) {
      for (final v in variants) {
        if (v is Map<String, dynamic>) return v;
      }
    }
    return null;
  }
}
