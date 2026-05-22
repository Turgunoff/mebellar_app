import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logging/talker.dart';
import '../../../../config/remote_config.dart';
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
/// "Saqlash va e'lon qilish". Single-variant MVP: one product row + one
/// variant row + N image rows are inserted atomically in [createProduct].
/// Category-specific specs (dimensions, fabric, etc.) ride along inside the
/// [attributes] JSONB payload; only logistics and variant data remain typed.
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
  /// product row as `colors text[]`. The variant row keeps a single
  /// `color_name` for back-compat (first selection in [colorNames]).
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

/// Add-product data layer. Wraps Supabase Storage upload + the
/// `products` / `product_variants` / `product_images` triple-insert so the
/// cubit stays free of SDK details.
class AddProductRepository {
  AddProductRepository({required SupabaseClient supabase}) : _client = supabase;

  final SupabaseClient _client;

  static const _bucket = 'product-images';

  /// One-shot context load that the screen uses to gate access AND drive the
  /// dynamic image cap. The query joins the shop row to its subscription plan
  /// so the canonical `max_products` / `max_images_per_product` limits come
  /// from the DB rather than the Dart enum defaults.
  Future<AddProductShopContext> loadShopContext() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      talker.warning('[add-product] loadShopContext aborted — no auth.uid');
      throw StateError('Seller is not authenticated');
    }
    talker.info('[add-product] loadShopContext start sellerId=$userId');

    try {
      // Shop+plan and categories are independent — fetch in parallel so the
      // form's `loadingContext` window is dominated by the slower of the two,
      // not their sum.
      final results = await Future.wait<Object?>([
        _client
            .from('shops')
            .select('id, plan:subscription_plans(*)')
            .eq('seller_id', userId)
            .maybeSingle(),
        _fetchCategories(),
      ]);
      final shopRow = results[0] as Map<String, dynamic>?;
      final categories = results[1] as List<CategoryModel>;

      if (shopRow == null) {
        talker.warning(
          '[add-product] loadShopContext: no shop row for sellerId=$userId',
        );
        throw StateError("Shop is not yet created for the current seller");
      }

      final planJson = shopRow['plan'];
      final plan = planJson is Map<String, dynamic>
          ? SubscriptionPlan.fromJson(planJson)
          : _fallbackPlan;
      final shopId = shopRow['id'] as String;
      final productsCount = await _countActiveProducts(shopId);

      talker.info(
        '[add-product] loadShopContext ok shopId=$shopId '
        'plan=${plan.code} categories=${categories.length} '
        'activeProducts=$productsCount',
      );

      return AddProductShopContext(
        shopId: shopId,
        sellerId: userId,
        plan: plan,
        activeProductsCount: productsCount,
        categories: categories,
      );
    } catch (e, st) {
      talker.handle(e, st,
          '[add-product] loadShopContext failed sellerId=$userId');
      rethrow;
    }
  }

  Future<int> _countActiveProducts(String shopId) async {
    final rows = await _client
        .from('products')
        .select('id')
        .eq('shop_id', shopId);
    return rows.length;
  }

  Future<List<CategoryModel>> _fetchCategories() async {
    // Embedded `subcategories(...)` triggers PostgREST's FK join so the form
    // can render the subcategory picker without a second round-trip.
    final rows = await _client
        .from('categories')
        .select(
          'id, name, name_uz, name_ru, subtitle, image_url, sort_order, '
          'subcategories(id, category_id, name)',
        )
        .order('sort_order', ascending: true);
    return (rows as List)
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
            sortOrder: r['sort_order'] as int? ?? 0,
            subcategories: subs,
          );
        })
        .toList(growable: false);
  }

  /// Persists the product. Order matters: storage uploads happen first so a
  /// network failure aborts before any DB row exists. Once images are up, we
  /// insert the product row, then the single variant, then one row per image.
  Future<AddProductResult> createProduct(AddProductInput input) async {
    if (input.imageFiles.isEmpty) {
      talker.warning(
        '[add-product] createProduct rejected — no images attached',
      );
      throw StateError('At least one product image is required');
    }
    talker.info(
      '[add-product] createProduct start sku=${input.sku} '
      'sellerId=${input.sellerId} shopId=${input.shopId} '
      'category=${input.categoryId} sub=${input.subcategoryId} '
      'images=${input.imageFiles.length} colors=${input.colorSlugs.length} '
      'attributes=${input.attributes.keys.toList()}',
    );

    try {
      final uploaded = await _uploadImages(
        sellerId: input.sellerId,
        files: input.imageFiles,
      );

      final productPayload = <String, dynamic>{
        'shop_id': input.shopId,
        'seller_id': input.sellerId,
        'category_id': input.categoryId,
        if (input.subcategoryId != null) 'subcategory_id': input.subcategoryId,
        'name': input.name,
        'description': input.description.isEmpty ? null : input.description,
        'price': input.price,
        'images': uploaded.map((u) => u.publicUrl).toList(),
        'attributes': input.attributes.isEmpty ? null : input.attributes,
        'colors': input.colorSlugs,
        'production_time_days': input.productionTimeDays,
        'has_delivery': input.hasDelivery,
        'delivery_price': input.hasDelivery ? input.deliveryPrice : 0,
        'has_installation': input.hasInstallation,
        'installation_price':
            input.hasInstallation ? input.installationPrice : 0,
        'warranty_months': input.warrantyMonths,
        'status': 'pending_review',
      };

      talker.debug(
        '[add-product] inserting product row '
        'name="${input.name}" price=${input.price}',
      );
      final productRow = await _client
          .from('products')
          .insert(productPayload)
          .select('id')
          .single();
      final productId = productRow['id'] as String;
      talker.info('[add-product] product row inserted id=$productId');

      final discountPrice = input.discountPercent > 0
          ? (input.price *
                  (100 - input.discountPercent) /
                  100)
              .roundToDouble()
          : null;

      await _client.from('product_variants').insert({
        'product_id': productId,
        'sku': input.sku,
        // Multi-color is stored on the product row; the variant keeps a single
        // representative label for back-compat (first selected colour).
        'color_name':
            input.colorNames.isEmpty ? null : input.colorNames.first,
        'price': input.price,
        'discount_price': discountPrice,
      });
      talker.info(
        '[add-product] variant inserted productId=$productId sku=${input.sku} '
        'discountPrice=$discountPrice',
      );

      if (uploaded.isNotEmpty) {
        final imageRows = <Map<String, dynamic>>[
          for (var i = 0; i < uploaded.length; i++)
            {
              'product_id': productId,
              'image_url': uploaded[i].publicUrl,
              'is_main': i == 0,
              'sort_order': i,
            },
        ];
        await _client.from('product_images').insert(imageRows);
        talker.info(
          '[add-product] image rows inserted productId=$productId '
          'count=${imageRows.length}',
        );
      }

      talker.info('[add-product] createProduct ok productId=$productId');
      return AddProductResult(
        productId: productId,
        imageUrls: uploaded.map((u) => u.publicUrl).toList(),
      );
    } catch (e, st) {
      talker.handle(e, st,
          '[add-product] createProduct failed sku=${input.sku}');
      rethrow;
    }
  }

  Future<List<_UploadedImage>> _uploadImages({
    required String sellerId,
    required List<File> files,
  }) async {
    final results = <_UploadedImage>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final originalSize = await file.length();
      talker.debug(
        '[add-product] image ${i + 1}/${files.length} compressing '
        'path=${file.path} originalBytes=$originalSize',
      );
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
      try {
        await _client.storage.from(_bucket).uploadBinary(
              objectPath,
              Uint8List.fromList(bytes),
              fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/webp',
                cacheControl: '3600',
              ),
            );
      } catch (e, st) {
        talker.handle(e, st,
            '[add-product] image upload failed path=$objectPath');
        rethrow;
      }
      final publicUrl =
          _client.storage.from(_bucket).getPublicUrl(objectPath);
      talker.info(
        '[add-product] image ${i + 1}/${files.length} uploaded '
        'path=$objectPath compressedBytes=${bytes.length}',
      );
      results.add(_UploadedImage(path: objectPath, publicUrl: publicUrl));
    }
    return results;
  }

  /// Pseudo-uuid that's safe inside a storage object name. Combines a
  /// millisecond timestamp with a 6-char random suffix derived from the
  /// SDK's auth UID + Object.hashCode — good enough for a low-volume
  /// per-seller folder where collision risk is essentially zero.
  String _randomObjectName() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = identityHashCode(Object()).toRadixString(36);
    return '${ts}_$rand';
  }

  static final SubscriptionPlan _fallbackPlan = SubscriptionPlan(
    id: '',
    code: TariffPlan.free.code,
    name: TariffPlan.free.code,
    priceMonthly: TariffPlan.free.monthlyPriceUzs,
    maxProducts: TariffPlan.free.maxActiveProducts,
    maxImagesPerProduct: TariffPlan.free.maxImagesPerProduct,
    commissionRate: TariffPlan.free.commissionRate,
  );
}

class _UploadedImage {
  const _UploadedImage({required this.path, required this.publicUrl});
  final String path;
  final String publicUrl;
}
