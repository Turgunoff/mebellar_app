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

/// Best-effort form prefill returned by `POST /seller/products/ai-suggest`.
/// Every field is optional — the cubit applies only what came back and the
/// seller reviews before saving. [available] is false when the backend has AI
/// disabled or the vision call failed; the UI surfaces a soft message rather
/// than treating it as an error.
class AiProductSuggestion {
  const AiProductSuggestion({
    required this.available,
    this.sameProduct = true,
    this.name,
    this.description,
    this.categoryId,
    this.subcategoryId,
    this.colors = const [],
    this.attributes = const {},
  });

  final bool available;

  /// False when the photos look like different products (divan + stol + …)
  /// rather than one product from several angles. The prefill still describes
  /// the primary image; the UI warns the seller to split them up.
  final bool sameProduct;
  final String? name;
  final String? description;
  final String? categoryId;
  final String? subcategoryId;
  final List<String> colors;
  final Map<String, dynamic> attributes;

  factory AiProductSuggestion.fromJson(Map<String, dynamic> json) {
    final colorsRaw = json['colors'];
    final attrsRaw = json['attributes'];
    return AiProductSuggestion(
      available: json['available'] as bool? ?? false,
      // Absent flag = single product (older backend / no mismatch detected).
      sameProduct: json['same_product'] as bool? ?? true,
      name: (json['name'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['name'] as String).trim(),
      description: (json['description'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['description'] as String).trim(),
      categoryId: json['category_id'] as String?,
      subcategoryId: json['subcategory_id'] as String?,
      colors: colorsRaw is List
          ? colorsRaw.whereType<String>().toList(growable: false)
          : const [],
      attributes: attrsRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(attrsRaw)
          : const {},
    );
  }

  /// True when there's at least one field worth applying to the form.
  bool get hasAnything =>
      available &&
      (name != null ||
          description != null ||
          categoryId != null ||
          colors.isNotEmpty ||
          attributes.isNotEmpty);
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

  /// Uploads [files] to R2, then asks the backend to draft product fields from
  /// the resulting public image URLs (`POST /seller/products/ai-suggest`).
  /// Returns the parsed suggestion plus the uploaded URLs so the caller can
  /// reuse them at save time and avoid re-uploading the same bytes.
  ///
  /// Never throws on an AI failure — a non-2xx or malformed body yields an
  /// `available: false` suggestion so the form degrades softly. An *upload*
  /// failure still throws, since that's the seller's own network/quota problem
  /// and they'll hit it again at save time.
  Future<({AiProductSuggestion suggestion, List<String> imageUrls})>
  suggestFromImages({
    required String sellerId,
    required List<File> files,
  }) async {
    if (files.isEmpty) {
      throw StateError('At least one image is required for AI suggestion');
    }
    final imageUrls = await _uploadImages(sellerId: sellerId, files: files);
    try {
      final body = await _api.post<Map<String, dynamic>>(
        '/seller/products/ai-suggest',
        body: {'image_urls': imageUrls},
      );
      return (
        suggestion: AiProductSuggestion.fromJson(body),
        imageUrls: imageUrls,
      );
    } catch (_) {
      // The images uploaded fine; only the draft failed. Hand the URLs back
      // with an unavailable suggestion so the caller keeps the uploads.
      return (
        suggestion: const AiProductSuggestion(available: false),
        imageUrls: imageUrls,
      );
    }
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
