import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/multilingual_text.dart';
import '../models/paginated.dart';
import '../models/seller_product.dart';
import 'seller_product_repository.dart';

/// Live Supabase-backed seller product repository.
///
/// Reads from `public.products` filtered by `seller_id = auth.uid()`. Variants
/// and images live in their own tables (`public.product_variants`,
/// `public.product_images`) but the seller list UI doesn't yet need either —
/// we project minimal fields and leave the richer hydration for the detail
/// flow.
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
      return Paginated(
        items: const [],
        page: page,
        perPage: perPage,
        total: 0,
        hasNext: false,
      );
    }

    // Empty-list stub for now — backend wiring lands when the product form
    // starts persisting to `public.products`. Surfacing an empty result here
    // is what drives the seller "Katalogingiz bo'sh" zero-state.
    final items = <SellerProduct>[];
    _controller.add(items);
    return Paginated(
      items: items,
      page: page,
      perPage: perPage,
      total: items.length,
      hasNext: false,
    );
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

  // Reserved for future hydration of `public.products` rows.
  // ignore: unused_element
  SellerProduct _fromRow(Map<String, dynamic> row) {
    final name = (row['name'] as String?) ?? '';
    final description = (row['description'] as String?) ?? '';
    final status = SellerProductStatus.fromCode(row['status'] as String?);
    final created = DateTime.tryParse(row['created_at'] as String? ?? '') ??
        DateTime.now();
    final updated = DateTime.tryParse(row['updated_at'] as String? ?? '') ??
        created;
    return SellerProduct(
      id: row['id'] as String,
      name: MultilingualText(uz: name),
      description: MultilingualText(uz: description),
      categorySlug: row['category_id'] as String? ?? '',
      price: (row['price'] as num?) ?? 0,
      stock: 0,
      sku: row['sku'] as String? ?? '',
      images: const [],
      status: status,
      createdAt: created,
      updatedAt: updated,
    );
  }
}
