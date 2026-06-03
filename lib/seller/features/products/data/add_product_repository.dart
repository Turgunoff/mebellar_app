import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../../config/remote_config.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/network/woody_api_client.dart';
import '../../../../core/storage/r2_upload_client.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/tariff.dart';

/// Snapshot of the seller's shop + plan that the add-product screen needs
/// before the user can start filling the form. Loaded once via
/// [AddProductRepository.loadShopContext] so the cubit can:
///   * gate access (`canAddMoreProducts` against the current product count),
///   * cap image picking dynamically (`plan.maxImagesPerProduct`),
///   * surface the right tariff snapshot to the upgrade prompt.
class AddProductShopContext {
  const AddProductShopContext({
    required this.shopId,
    required this.sellerId,
    required this.plan,
    required this.activeProductsCount,
    required this.categories,
  });

  final String shopId;
  final String sellerId;
  final SubscriptionPlan plan;
  final int activeProductsCount;
  final List<CategoryModel> categories;

  /// Honours the tariff master switch: when tariff mode is off the gate is
  /// open regardless of the plan's product quota.
  bool get canAddMoreProducts =>
      !RemoteConfig.instance.tariffEnabled ||
      plan.canAddMoreProducts(activeProductsCount);

  /// `-1` means unlimited — which is always the case while tariff mode is off.
  int get maxImages =>
      RemoteConfig.instance.tariffEnabled ? plan.maxImagesPerProduct : -1;

  TariffSnapshot get tariffSnapshot => TariffSnapshot(
    plan: plan.asEnum,
    activeProductsCount: activeProductsCount,
  );
}

/// Inputs the cubit hands to the repository when the user taps
/// "Saqlash va e'lon qilish". Category-specific specs (dimensions, fabric,
/// etc.) ride along inside the [attributes] JSONB payload; only logistics and
/// variant data remain typed.
class AddProductInput {
  const AddProductInput({
    required this.sellerId,
    required this.shopId,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.subcategoryId,
    required this.price,
    required this.discountPercent,
    required this.sku,
    required this.colorSlugs,
    required this.colorNames,
    required this.attributes,
    required this.productionTimeDays,
    required this.hasDelivery,
    required this.deliveryPrice,
    required this.hasInstallation,
    required this.installationPrice,
    required this.warrantyMonths,
    required this.imageFiles,
  });

  final String sellerId;
  final String shopId;
  final String name;
  final String description;
  final String categoryId;
  final String? subcategoryId;
  final num price;
  final int discountPercent;
  final String sku;

  /// Canonical color slugs (e.g. `['white','black']`) — persisted on the
  /// product row as `colors text[]`.
  final List<String> colorSlugs;

  /// Human-readable color labels in the order matching [colorSlugs].
  final List<String> colorNames;

  final Map<String, dynamic> attributes;
  final String? productionTimeDays;
  final bool hasDelivery;
  final num deliveryPrice;
  final bool hasInstallation;
  final num installationPrice;
  final int warrantyMonths;
  final List<File> imageFiles;
}

class AddProductResult {
  const AddProductResult({required this.productId, required this.imageUrls});
  final String productId;
  final List<String> imageUrls;
}

/// Add-product data layer (Woody REST). Images upload to the public
/// `product-images` R2 bucket; the product is created via `POST
/// /seller/products` (which stores `images` + `attributes` inline — no
/// separate variant/image-row inserts). Shop + plan context comes from
/// `GET /seller/shop` + `GET /seller/tariff/current`; the category tree from
/// the public `GET /catalog/categories`.
class AddProductRepository {
  AddProductRepository({
    required WoodyApiClient api,
    required AuthRepository auth,
    required R2UploadClient uploads,
  }) : _api = api,
       _auth = auth,
       _uploads = uploads;

  final WoodyApiClient _api;
  final AuthRepository _auth;
  final R2UploadClient _uploads;

  Future<AddProductShopContext> loadShopContext() async {
    final userId = _auth.currentUserId;
    if (userId == null) {
      throw StateError('Seller is not authenticated');
    }
    final results = await Future.wait<Object?>([
      _api.get<Map<String, dynamic>>('/seller/shop'),
      _api.get<Map<String, dynamic>>('/seller/tariff/current'),
      _fetchCategories(),
    ]);
    final shop = results[0] as Map<String, dynamic>;
    final snap = results[1] as Map<String, dynamic>;
    final categories = results[2] as List<CategoryModel>;

    final code = snap['plan_code'] as String? ?? TariffPlan.free.code;
    final plan = SubscriptionPlan(
      id: '',
      code: code,
      name: code,
      priceMonthly: 0,
      maxProducts:
          (snap['max_products'] as num?)?.toInt() ??
          TariffPlan.free.maxActiveProducts,
      maxImagesPerProduct:
          (snap['max_images_per_product'] as num?)?.toInt() ??
          TariffPlan.free.maxImagesPerProduct,
      commissionRate: (snap['commission_rate'] as num?) ?? 0,
    );

    return AddProductShopContext(
      shopId: shop['id'] as String,
      sellerId: userId,
      plan: plan,
      activeProductsCount:
          (snap['active_products_count'] as num?)?.toInt() ?? 0,
      categories: categories,
    );
  }

  Future<List<CategoryModel>> _fetchCategories() async {
    final rows = await _api.get<List<dynamic>>('/catalog/categories');
    return rows
        .whereType<Map<String, dynamic>>()
        .map((r) {
          final subRaw = r['subcategories'];
          final subs = subRaw is List
              ? subRaw
                    .whereType<Map<String, dynamic>>()
                    .map(SubcategoryModel.fromJson)
                    .toList(growable: false)
              : const <SubcategoryModel>[];
          return CategoryModel(
            id: r['id'] as String,
            name: (r['name_uz'] as String?) ?? (r['name'] as String? ?? ''),
            subtitle: r['subtitle'] as String?,
            imageUrl: r['image_url'] as String?,
            sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
            subcategories: subs,
          );
        })
        .toList(growable: false);
  }

  /// Uploads images to R2 first (so a network failure aborts before the
  /// product row exists), then creates the product via `POST /seller/products`.
  Future<AddProductResult> createProduct(AddProductInput input) async {
    if (input.imageFiles.isEmpty) {
      throw StateError('At least one product image is required');
    }
    final imageUrls = await _uploadImages(
      sellerId: input.sellerId,
      files: input.imageFiles,
    );

    final discountPrice = input.discountPercent > 0
        ? (input.price * (100 - input.discountPercent) / 100).roundToDouble()
        : null;

    final body = await _api.post<Map<String, dynamic>>(
      '/seller/products',
      body: {
        'category_id': input.categoryId,
        if (input.subcategoryId != null) 'subcategory_id': input.subcategoryId,
        'name': input.name,
        if (input.description.isNotEmpty) 'description': input.description,
        if (input.sku.isNotEmpty) 'sku': input.sku,
        'price': input.price,
        if (discountPrice != null) 'discount_price': discountPrice,
        'images': imageUrls,
        if (input.attributes.isNotEmpty) 'attributes': input.attributes,
        'colors': input.colorSlugs,
        'has_delivery': input.hasDelivery,
        'delivery_price': input.hasDelivery ? input.deliveryPrice : 0,
        'has_installation': input.hasInstallation,
        'installation_price': input.hasInstallation
            ? input.installationPrice
            : 0,
        'warranty_months': input.warrantyMonths,
        if (input.productionTimeDays != null)
          'production_time_days': input.productionTimeDays,
      },
    );

    return AddProductResult(
      productId: body['id'] as String,
      imageUrls: imageUrls,
    );
  }

  Future<List<String>> _uploadImages({
    required String sellerId,
    required List<File> files,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        format: CompressFormat.webp,
        quality: 82,
        keepExif: false,
        minWidth: 1024,
        minHeight: 1024,
      );
      final bytes = compressed ?? await file.readAsBytes();
      final objectPath = '$sellerId/${_randomObjectName()}.webp';
      final result = await _uploads.upload(
        bucket: R2Bucket.productImages,
        path: objectPath,
        bytes: Uint8List.fromList(bytes),
        contentType: 'image/webp',
      );
      // The backend only returns a public URL when the product-images bucket's
      // R2_PRODUCT_IMAGES_PUBLIC_BASE_URL is set. Falling back to the bare
      // object key here would persist an unrenderable image reference (no
      // scheme/host) that shows as broken in the admin and as a placeholder in
      // the app — fail loudly instead, like SellerProductRepository.addImage.
      final publicUrl = result.publicUrl;
      if (publicUrl == null || publicUrl.isEmpty) {
        throw StateError(
          'Image upload returned no public URL — the backend is missing '
          'R2_PRODUCT_IMAGES_PUBLIC_BASE_URL',
        );
      }
      urls.add(publicUrl);
    }
    return urls;
  }

  String _randomObjectName() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = identityHashCode(Object()).toRadixString(36);
    return '${ts}_$rand';
  }
}
