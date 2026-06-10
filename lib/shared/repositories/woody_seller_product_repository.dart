import 'dart:io';

import '../../core/error/failure.dart';
import '../../core/network/api_error.dart';
import '../../core/network/woody_api_client.dart';
import '../../core/storage/r2_upload_client.dart';
import '../models/multilingual_text.dart';
import '../models/paginated.dart';
import '../models/seller_product.dart';
import '../models/tariff.dart';
import 'seller_product_repository.dart';

/// REST-backed seller product repository — targets `/seller/products` on
/// api.woody.uz.
///
/// Backend mismatches handled here (see [WoodyApiClient] throws on non-2xx):
///
/// * The backend stores images as a flat `list[str]` of public URLs
///   ([SellerProductRow.images]); there is no per-image id or primary flag.
///   The image URL itself is used as the synthetic [SellerProductImage.id], and
///   element order is the gallery order with index 0 treated as primary.
///   delete/reorder/setPrimary all rebuild the URL array and PATCH it back.
///   uploadImage PUTs bytes to the public `product-images` R2 bucket, then
///   PATCHes the appended array.
/// * `name`/`description` are plain strings server-side — the multilingual
///   uz value is sent and read back into [MultilingualText.uz].
/// * The read model has no `updated_at`, so `updatedAt` mirrors `createdAt`.
///   `sku`, `category_name`, `subcategory_name`, `material` and `attributes`
///   ARE returned by the seller list/detail endpoints (the latter two were
///   added so the detail screen can surface every stored field).
///   `rejection_reason` IS returned — populated when an admin rejects.
/// * `category_id` is a UUID server-side; [SellerProductInput.categorySlug]
///   carries the raw id and is forwarded as `category_id` — passing an actual
///   slug here would 422 (see riskNotes).
/// * The backend `update` does not accept a writable `status`; any field PATCH
///   forces `pending_review`. [archive]/[restore] therefore use the dedicated
///   `POST /seller/products/{id}/archive` and `.../restore` endpoints (which
///   set `archived` / `pending_review` server-side and read the row back).
///   [submitForReview] still sends `status` via PATCH — a no-op until the
///   backend grows its own submit endpoint — and reflects it optimistically.
class WoodySellerProductRepository implements SellerProductRepository {
  WoodySellerProductRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Stream<List<SellerProduct>> watch() => const Stream.empty();

  @override
  Future<Paginated<SellerProduct>> list({
    SellerProductFilter filter = const SellerProductFilter(),
    int page = 1,
    int perPage = 20,
  }) async {
    final offset = (page - 1) * perPage;
    final query = <String, dynamic>{
      'limit': perPage,
      'offset': offset,
    };
    // Backend takes a single status filter; the interface allows a set. Pass
    // the first selected status — multi-status filtering then narrows the page
    // client-side via [SellerProductFilter.matches].
    if (filter.statuses.isNotEmpty) {
      query['status'] = filter.statuses.first.code;
    }

    final body = await _api.get<Map<String, dynamic>>(
      '/seller/products',
      query: query,
    );
    final rows = (body['rows'] as List?) ?? const [];
    final total = (body['total'] as num?)?.toInt() ?? rows.length;

    var items = rows
        .whereType<Map<String, dynamic>>()
        .map(_fromRow)
        .toList(growable: false);

    // Honour the search term and any extra selected statuses the single-value
    // backend filter couldn't express.
    if (filter.search != null && filter.search!.isNotEmpty ||
        filter.statuses.length > 1) {
      items = items.where(filter.matches).toList(growable: false);
    }

    return Paginated(
      items: items,
      page: page,
      perPage: perPage,
      total: total,
      hasNext: offset + rows.length < total,
    );
  }

  @override
  Future<SellerProduct> getById(String id) async {
    final body = await _api.get<Map<String, dynamic>>('/seller/products/$id');
    return _fromRow(body);
  }

  @override
  Future<SellerProduct> create(SellerProductInput input) async {
    try {
      final body = await _api.post<Map<String, dynamic>>(
        '/seller/products',
        body: _toBody(input, includeStatus: false),
      );
      return _fromRow(body);
    } on ApiError catch (e) {
      throw _mapTariff(e);
    }
  }

  @override
  Future<SellerProduct> update(String id, SellerProductInput input) async {
    try {
      final body = await _api.patch<Map<String, dynamic>>(
        '/seller/products/$id',
        body: _toBody(input, includeStatus: false),
      );
      return _fromRow(body);
    } on ApiError catch (e) {
      throw _mapTariff(e);
    }
  }

  @override
  Future<SellerProduct> archive(String id) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/seller/products/$id/archive',
    );
    return _fromRow(body);
  }

  @override
  Future<SellerProduct> restore(String id) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/seller/products/$id/restore',
    );
    return _fromRow(body);
  }

  @override
  Future<void> delete(String id) async {
    await _api.delete<dynamic>('/seller/products/$id');
  }

  @override
  Future<SellerProduct> submitForReview(String id) =>
      _patchStatus(id, SellerProductStatus.pendingReview);

  @override
  Future<SellerProductImage> uploadImage({
    required String productId,
    required File file,
    required String fileExtension,
  }) async {
    final ext = fileExtension.toLowerCase();
    final path =
        '$productId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    // R2 client isn't a repo dependency here — the bytes go through the same
    // presigned-PUT plumbing used elsewhere, surfaced via WoodyApiClient.
    final result = await R2UploadClient(api: _api).upload(
      bucket: R2Bucket.productImages,
      path: path,
      bytes: await file.readAsBytes(),
      contentType: _imageContentType(ext),
    );
    final url = result.publicUrl;
    if (url == null || url.isEmpty) {
      throw const ServerFailure(message: 'Rasm manzili olinmadi');
    }

    final current = await getById(productId);
    final urls = [
      for (final img in current.images)
        if (img.remoteUrl != null) img.remoteUrl!,
      url,
    ];
    await _patchImages(productId, urls);
    return SellerProductImage(id: url, remoteUrl: url, localPath: file.path);
  }

  @override
  Future<void> deleteImage({
    required String productId,
    required String imageId,
  }) async {
    final current = await getById(productId);
    final urls = [
      for (final img in current.images)
        if (img.remoteUrl != null && img.id != imageId) img.remoteUrl!,
    ];
    await _patchImages(productId, urls);
  }

  @override
  Future<SellerProduct> reorderImages({
    required String productId,
    required List<String> imageIdsInOrder,
  }) async {
    final current = await getById(productId);
    final byId = {
      for (final img in current.images)
        if (img.remoteUrl != null) img.id: img.remoteUrl!,
    };
    final reordered = [
      for (final id in imageIdsInOrder)
        if (byId.containsKey(id)) byId[id]!,
    ];
    // Keep any images not named in the order list, appended in their existing
    // relative order so nothing is silently dropped.
    for (final img in current.images) {
      if (img.remoteUrl != null && !imageIdsInOrder.contains(img.id)) {
        reordered.add(img.remoteUrl!);
      }
    }
    final body = await _patchImages(productId, reordered);
    return _fromRow(body);
  }

  @override
  Future<SellerProduct> setPrimaryImage({
    required String productId,
    required String imageId,
  }) async {
    final current = await getById(productId);
    final urls = [
      for (final img in current.images)
        if (img.remoteUrl != null && img.id == imageId) img.remoteUrl!,
      for (final img in current.images)
        if (img.remoteUrl != null && img.id != imageId) img.remoteUrl!,
    ];
    final body = await _patchImages(productId, urls);
    return _fromRow(body);
  }

  Future<Map<String, dynamic>> _patchImages(
    String productId,
    List<String> urls,
  ) {
    return _api.patch<Map<String, dynamic>>(
      '/seller/products/$productId',
      body: {'images': urls},
    );
  }

  /// Best-effort status transition. The backend update body drops an unknown
  /// `status` field and forces `pending_review` on any column write, so today
  /// only the [SellerProductStatus.pendingReview] target lands faithfully.
  /// The intended status is reflected optimistically via copyWith so the UI
  /// updates; the next list/detail read is authoritative once the backend
  /// honours the field.
  Future<SellerProduct> _patchStatus(
    String id,
    SellerProductStatus status,
  ) async {
    final body = await _api.patch<Map<String, dynamic>>(
      '/seller/products/$id',
      body: {'status': status.code},
    );
    return _fromRow(body).copyWith(status: status);
  }

  Map<String, dynamic> _toBody(
    SellerProductInput input, {
    required bool includeStatus,
  }) {
    final name = _resolveText(input.name);
    final description = _resolveText(input.description);
    return {
      'category_id': input.categorySlug,
      'name': name,
      if (description.isNotEmpty) 'description': description,
      'price': input.price,
      if (input.oldPrice != null) 'discount_price': input.oldPrice,
      'stock': input.stock,
      'attributes': input.attributes,
      if (input.lengthCm != null) 'depth_cm': input.lengthCm!.round(),
      if (input.widthCm != null) 'width_cm': input.widthCm!.round(),
      if (input.heightCm != null) 'height_cm': input.heightCm!.round(),
      if (includeStatus) 'status': input.status.code,
    };
  }

  /// [SellerProductInput.name]/`description` are `dynamic` — they may already
  /// be a plain String, or a [MultilingualText], or its JSON map. The backend
  /// wants a single string, so resolve to the uz value (the baseline locale).
  String _resolveText(dynamic value) {
    if (value is String) return value;
    if (value is MultilingualText) {
      return value.uz ?? value.ru ?? value.en ?? '';
    }
    if (value is Map) {
      final uz = value['uz'] ?? value['ru'] ?? value['en'];
      return uz is String ? uz : '';
    }
    return value?.toString() ?? '';
  }

  Object _mapTariff(ApiError e) {
    // The backend signals an exhausted active-products quota with 409. Surface
    // it as the typed exception the add-product gate expects. The backend
    // doesn't return the plan, so default the snapshot to the free tier.
    if (e.status == 409) {
      return TariffLimitException(
        const TariffSnapshot(
          plan: TariffPlan.free,
          activeProductsCount: 0,
        ),
      );
    }
    return e;
  }

  SellerProduct _fromRow(Map<String, dynamic> row) {
    final created =
        DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();
    final images = _imagesFromRow(row);
    return SellerProduct(
      id: row['id'] as String,
      name: MultilingualText(uz: (row['name'] as String?) ?? ''),
      description: MultilingualText(uz: (row['description'] as String?) ?? ''),
      categorySlug: row['category_id'] as String? ?? '',
      categoryName: (row['category_name'] as String?)?.trim().isNotEmpty == true
          ? (row['category_name'] as String).trim()
          : null,
      subcategoryId: row['subcategory_id'] as String?,
      subcategoryName:
          (row['subcategory_name'] as String?)?.trim().isNotEmpty == true
          ? (row['subcategory_name'] as String).trim()
          : null,
      material: (row['material'] as String?)?.trim().isNotEmpty == true
          ? (row['material'] as String).trim()
          : null,
      colors: _stringList(row['colors']),
      price: (row['price'] as num?) ?? 0,
      oldPrice: row['discount_price'] as num?,
      discountPrice: row['discount_price'] as num?,
      stock: (row['stock'] as num?)?.toInt() ?? 0,
      sku: (row['sku'] as String?) ?? '',
      images: images,
      primaryImageId: images.isEmpty ? null : images.first.id,
      attributes: row['attributes'] is Map<String, dynamic>
          ? row['attributes'] as Map<String, dynamic>
          : const {},
      lengthCm: row['depth_cm'] as num?,
      widthCm: row['width_cm'] as num?,
      heightCm: row['height_cm'] as num?,
      productionTimeDays: row['production_time_days'] as String?,
      hasDelivery: row['has_delivery'] as bool? ?? false,
      deliveryPrice: (row['delivery_price'] as num?) ?? 0,
      hasInstallation: row['has_installation'] as bool? ?? false,
      installationPrice: (row['installation_price'] as num?) ?? 0,
      warrantyMonths: (row['warranty_months'] as num?)?.toInt() ?? 0,
      status: SellerProductStatus.fromCode(row['status'] as String?),
      rejectionReason: (row['rejection_reason'] as String?)?.trim().isNotEmpty == true
          ? (row['rejection_reason'] as String).trim()
          : null,
      archiveReason: (row['archive_reason'] as String?)?.trim().isNotEmpty == true
          ? (row['archive_reason'] as String).trim()
          : null,
      createdAt: created,
      // Backend SellerProductRow exposes no updated_at — mirror created_at.
      updatedAt: created,
    );
  }

  List<SellerProductImage> _imagesFromRow(Map<String, dynamic> row) {
    final raw = row['images'];
    if (raw is! List) return const [];
    return [
      for (final v in raw)
        if (v is String && v.isNotEmpty)
          // The URL is the synthetic id — the backend has no per-image id.
          SellerProductImage(id: v, remoteUrl: v),
    ];
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return [
        for (final v in raw)
          if (v is String && v.isNotEmpty) v,
      ];
    }
    return const [];
  }

  String _imageContentType(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}
